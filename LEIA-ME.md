# Agenda da Liderança — PWA com banco de dados real (Supabase)

Essa pasta é um site pronto pra publicar. Diferente da primeira versão, agora
os dados **não ficam mais só no aparelho** — tudo é salvo num banco de dados
real (Supabase), então **todo mundo vê e edita a mesma agenda**, em tempo
real, de qualquer dispositivo.

## Como o acesso funciona

- Qualquer pessoa pode criar uma conta (e-mail + senha) direto na tela de
  login — não precisa de convite pra *entrar*.
- Quem **não foi convidado** entra automaticamente como **visualizador**
  (só vê a agenda, não pode criar nem editar nada).
- Quem **foi convidado antes** por um admin (com papel de editor ou admin)
  recebe esse papel automaticamente ao criar a conta com o e-mail convidado.
- **Editor**: cria, edita, arrasta e apaga eventos.
- **Admin**: tudo isso + convida gente nova, muda o papel de qualquer
  pessoa, e pode remover o acesso de alguém (ícone de escudo no topo do
  app).

O e-mail `igor.alexandre.cavallaro@gmail.com` já está cadastrado como
convite de **admin** — é só criar a conta com esse e-mail que o acesso de
administrador vem automaticamente.

## Histórico de mudanças (auditoria)

Toda criação, edição ou exclusão de evento fica registrada no banco (quem,
o quê mudou, quando) — isso acontece automaticamente no servidor, então
ninguém consegue apagar o rastro pelo app. Hoje essa consulta é feita
direto no painel do Supabase (tabela `events_audit`); se quiser, depois dá
pra eu adicionar uma tela dentro do próprio app pra ver esse histórico.

## Como publicar (3 minutos, de graça)

Tudo aqui é HTML/JS estático — qualquer uma dessas opções funciona:

### Opção A — Netlify (mais simples)
1. Acesse https://app.netlify.com/drop
2. Arraste esta pasta inteira pro navegador.
3. Pronto — você recebe um link `https://algumnome.netlify.app`.

### Opção B — GitHub Pages (já que é pra onde você quer subir)
1. Suba esta pasta pra um repositório no GitHub.
2. Em *Settings → Pages*, aponte pra pasta raiz do repositório (ou `/docs`,
   se preferir mover os arquivos pra lá).
3. O link fica `https://seu-usuario.github.io/nome-do-repo`.

### Opção C — Vercel
1. `npm i -g vercel` (uma vez só)
2. Dentro desta pasta: `vercel --prod`

**Atenção de segurança**: o arquivo `index.html` tem embutida a chave
pública ("publishable key") do Supabase — isso é normal e seguro, ela é
feita pra ficar no navegador de quem usa o site. Quem protege os dados de
verdade são as regras de segurança do banco (RLS), não essa chave.

## Como instalar no celular/computador depois de publicado

- **Android (Chrome):** abra o link → menu (⋮) → "Instalar app".
- **iPhone (Safari):** abra o link → compartilhar → "Adicionar à Tela de
  Início".
- **Computador (Chrome/Edge):** ícone de instalação na barra de endereço.

## Backup

O plano gratuito do Supabase **não inclui backup automático** pela
interface (isso é recurso pago, do plano Pro). Enquanto vocês estiverem no
gratuito, a forma sem custo de ter backup é agendar um `pg_dump` — por
exemplo com um GitHub Action rodando todo dia, gravando num repositório
privado. Posso montar esse workflow pra você quando quiser.

## Painel do projeto no Supabase

https://supabase.com/dashboard/project/qfhizemyolcrgjwcbbwj

De lá dá pra ver as tabelas, os logs, os usuários cadastrados, e (se
decidir fazer upgrade) configurar o backup automático.

## Arquivos desta pasta

- `index.html` — página principal, autocontida (JS embutido, um arquivo só,
  fácil de você continuar editando)
- `app.js` — a mesma aplicação em arquivo separado (usado pela versão
  multi-arquivo, referenciada pelo `index.html` do build padrão)
- `manifest.webmanifest` — nome, ícone e cores do app instalado
- `service-worker.js` — cache do "esqueleto" do app para abrir mais rápido
  (os dados em si sempre vêm do Supabase, exigem internet)
- `icon-*.png` — ícones do app
- `supabase-schema.sql` — o script completo do banco (tabelas, papéis,
  segurança, auditoria) — guarde este arquivo, é ele que documenta a
  estrutura toda caso precise recriar ou revisar
