-- ============================================================================
-- Agenda da Liderança — NEC — Schema Supabase
-- ============================================================================
-- Como aplicar: Supabase Dashboard → SQL Editor → colar e rodar,
-- OU via Supabase MCP (execute_sql) quando o projeto for criado.
--
-- MODELO DE ACESSO:
--   - Qualquer e-mail consegue entrar (login por link mágico), sem precisar
--     de convite prévio.
--   - Quem NÃO foi convidado nasce com o papel "viewer" (só visualiza).
--   - Quem FOI convidado por um admin (tabela `invites`) recebe o papel
--     combinado (editor ou admin) automaticamente no primeiro login.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Convites pendentes (admin cadastra o e-mail + papel ANTES da pessoa
--    entrar pela primeira vez; some da tabela assim que ela faz login).
-- ---------------------------------------------------------------------------
create table public.invites (
  email text primary key,
  role text not null check (role in ('admin', 'editor')), -- convite nunca é pra "viewer": isso já é o padrão de quem não foi convidado
  invited_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2. Membros (todo mundo que já logou pelo menos uma vez cai aqui)
-- ---------------------------------------------------------------------------
create table public.members (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  role text not null default 'viewer' check (role in ('admin', 'editor', 'viewer')),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 3. Gatilho: ao criar a conta no Supabase Auth (primeiro login por e-mail),
--    verifica se existe um convite pendente pra aquele e-mail.
--    Se existir → assume o papel do convite (editor/admin) e apaga o convite.
--    Se não existir → vira "viewer" automaticamente.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  matched_role text;
begin
  select role into matched_role from public.invites where email = new.email;

  insert into public.members (id, email, role)
  values (new.id, new.email, coalesce(matched_role, 'viewer'));

  if matched_role is not null then
    delete from public.invites where email = new.email;
  end if;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 4. Tipos/categorias de evento (Serviço, Comunhão, Adoração, etc.)
-- ---------------------------------------------------------------------------
create table public.event_types (
  id text primary key,
  name text not null,
  color text not null,
  default_roles text[] not null default '{}',
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 5. Eventos (cultos, reuniões, eventos de vários dias)
-- ---------------------------------------------------------------------------
create table public.events (
  id text primary key,
  title text not null,
  date date not null,
  end_date date, -- null = evento de um dia só
  time text,     -- 'HH:MM', opcional
  type_id text references public.event_types(id) on delete set null,
  roles jsonb not null default '[]', -- [{ id, role, person }]
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index events_date_idx on public.events (date);

-- ---------------------------------------------------------------------------
-- 6. Banco de nomes (autocomplete de pessoas já escaladas antes)
-- ---------------------------------------------------------------------------
create table public.people (
  name text primary key,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 7. Log de auditoria — histórico de mudanças (quem, o quê, quando)
-- ---------------------------------------------------------------------------
create table public.events_audit (
  id bigint generated always as identity primary key,
  event_id text not null,
  action text not null check (action in ('insert', 'update', 'delete')),
  changed_by uuid references auth.users(id),
  changed_by_email text,
  old_data jsonb,
  new_data jsonb,
  changed_at timestamptz not null default now()
);

create or replace function public.log_event_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.events_audit (event_id, action, changed_by, changed_by_email, old_data, new_data)
  values (
    coalesce(new.id, old.id),
    lower(tg_op),
    auth.uid(),
    (select email from public.members where id = auth.uid()),
    case when tg_op in ('update', 'delete') then to_jsonb(old) else null end,
    case when tg_op in ('insert', 'update') then to_jsonb(new) else null end
  );
  return coalesce(new, old);
end;
$$;

create trigger events_audit_trigger
  after insert or update or delete on public.events
  for each row execute function public.log_event_change();

-- ============================================================================
-- ROW LEVEL SECURITY — o próprio banco recusa acesso indevido,
-- mesmo que alguém tente burlar o app.
-- ============================================================================
alter table public.invites enable row level security;
alter table public.members enable row level security;
alter table public.event_types enable row level security;
alter table public.events enable row level security;
alter table public.people enable row level security;
alter table public.events_audit enable row level security;

-- Helper: papel do usuário autenticado atual
create or replace function public.my_role()
returns text
language sql
security definer
stable
set search_path = public
as $$
  select role from public.members where id = auth.uid();
$$;

-- ---- members: qualquer membro lê a lista; só admin edita papéis ----------
create policy "members read" on public.members for select
  using (public.my_role() is not null);
create policy "admin updates roles" on public.members for update
  using (public.my_role() = 'admin');

-- ---- invites: só admin gerencia convites ----------------------------------
create policy "admin manages invites" on public.invites for all
  using (public.my_role() = 'admin')
  with check (public.my_role() = 'admin');

-- ---- event_types: qualquer membro lê; editor/admin cria e edita ----------
create policy "members read types" on public.event_types for select
  using (public.my_role() is not null);
create policy "editors write types" on public.event_types for insert
  with check (public.my_role() in ('editor', 'admin'));
create policy "editors update types" on public.event_types for update
  using (public.my_role() in ('editor', 'admin'));
create policy "editors delete types" on public.event_types for delete
  using (public.my_role() in ('editor', 'admin'));

-- ---- events: qualquer membro lê; editor/admin cria, edita e apaga --------
create policy "members read events" on public.events for select
  using (public.my_role() is not null);
create policy "editors insert events" on public.events for insert
  with check (public.my_role() in ('editor', 'admin'));
create policy "editors update events" on public.events for update
  using (public.my_role() in ('editor', 'admin'));
create policy "editors delete events" on public.events for delete
  using (public.my_role() in ('editor', 'admin'));

-- ---- people (banco de nomes): igual a events -------------------------------
create policy "members read people" on public.people for select
  using (public.my_role() is not null);
create policy "editors write people" on public.people for insert
  with check (public.my_role() in ('editor', 'admin'));

-- ---- events_audit: leitura só pra admin (histórico é informação sensível) --
create policy "admin reads audit log" on public.events_audit for select
  using (public.my_role() = 'admin');

-- ============================================================================
-- Seed inicial: coloque aqui os e-mails que já sabemos que vão liderar,
-- ANTES de mandar o link pra eles. Troque pelos e-mails reais.
-- ============================================================================
-- insert into public.invites (email, role) values
--   ('pastor@novaestacao.church', 'admin'),
--   ('lider1@novaestacao.church', 'editor');
