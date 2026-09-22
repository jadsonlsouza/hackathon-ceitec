# Ligalab — Plataforma de desafios e eventos

O Ligalab é uma plataforma web para organizar eventos, equipes, avaliações e resultados. O **Hackathon CEITEC** é o primeiro evento disponível no catálogo. A aplicação é construída com **Nuxt 4**, **Vue 3**, **TypeScript** e **Supabase**.

---

## Pré-requisitos

| Ferramenta | Versão mínima |
|---|---|
| Node.js | 22 |
| npm | 10 |
| Docker Desktop | 4.x (necessário para o Supabase local) |
| Supabase CLI | última estável (`npm install -g supabase` ou via `npx`) |
| Playwright | instalado automaticamente via `npm ci` |

---

## Configuração do ambiente local

### 1. Instalar dependências

```bash
npm ci
```

### 2. Variáveis de ambiente

Copie o exemplo e preencha com as credenciais do seu projeto Supabase:

```bash
cp .env.example .env
```

| Variável | Descrição |
|---|---|
| `NUXT_PUBLIC_SUPABASE_URL` | URL da API do seu projeto Supabase |
| `NUXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Chave anônima (`anon`) |
| `NUXT_SUPABASE_SECRET_KEY` | Chave de serviço (`service_role`) — **nunca exposta no cliente** |
| `NUXT_EVENT_ARCHIVE_SECRET` | Segredo de arquivamento de eventos (mín. 12 caracteres) |

### 3. Iniciar o Supabase local

```bash
npx supabase start --exclude edge-runtime,imgproxy,logflare,mailpit,postgres-meta,storage-api,studio,supavisor,vector
```

> As credenciais locais são exibidas automaticamente. Copie `API URL` e `anon key` para o `.env` ao rodar localmente — ou deixe em branco para usar o projeto remoto.

### 4. Aplicar migrações e dados de seed

```bash
npx supabase db reset
```

Isso aplica todas as migrações de `supabase/migrations/` e executa `supabase/seed.sql`.

### 5. Configurar Google OAuth (para login social)

No painel do Supabase → **Authentication → Providers → Google**:

1. Ative o provedor Google.
2. Adicione os Client ID e Client Secret do seu projeto no [Google Cloud Console](https://console.cloud.google.com/).
3. Adicione a URL de callback autorizada:
   - Local: `http://127.0.0.1:54321/auth/v1/callback`
   - Produção: `https://<seu-projeto>.supabase.co/auth/v1/callback`

No painel do Supabase → **Authentication → URL Configuration**:
- **Site URL**: URL pública do app (ex.: `https://seu-dominio.vercel.app`)
- **Redirect URLs**: adicione `http://127.0.0.1:3000/**` (local) e a URL de produção.

### 6. Rodar em modo desenvolvimento

```bash
npm run dev
```

O app estará disponível em `http://127.0.0.1:3000`.

---

## Testes

### Testes unitários e de integração (Vitest)

```bash
# Modo watch
npm test

# Execução única (todos)
npx vitest run

# Apenas testes de unidade
npm run test:unit

# Apenas testes de integração Nuxt
npm run test:e2e
```

### Testes de banco de dados (pgTAP)

```bash
npx supabase test db
```

### Testes de acessibilidade (Playwright + axe-core)

```bash
npm run test:a11y
```

### Testes de autorização e segurança (Playwright)

```bash
npm run test:security
```

### Todos os testes Playwright

```bash
npx playwright test
```

> **Obs.:** Os testes E2E requerem o Supabase local rodando (`supabase start`) e o banco resetado (`supabase db reset`). O global setup faz o db reset automaticamente antes dos testes.

---

## Build de produção

```bash
npm run build
```

A saída fica em `.output/`. Para testar o bundle localmente:

```bash
node .output/server/index.mjs
```

---

## Deploy no Vercel

### 1. Criar projeto no Vercel

```bash
npx vercel --prod
```

Ou importe o repositório pelo painel em [vercel.com](https://vercel.com).

### 2. Configurar variáveis de ambiente

No painel do Vercel → **Settings → Environment Variables**, adicione:

| Variável | Valor |
|---|---|
| `NUXT_PUBLIC_SUPABASE_URL` | URL pública do seu projeto Supabase |
| `NUXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Chave `anon` |
| `NUXT_SUPABASE_SECRET_KEY` | Chave `service_role` |
| `NUXT_EVENT_ARCHIVE_SECRET` | Segredo de arquivamento (mín. 12 caracteres) |

### 3. Configurar o Supabase para produção

- **Site URL**: URL de produção do Vercel (ex.: `https://seu-dominio.vercel.app`)
- **Redirect URLs**: adicione `https://seu-dominio.vercel.app/**`
- **Callback Google OAuth**: `https://<seu-projeto>.supabase.co/auth/v1/callback`

### 4. Smoke test de produção

```bash
PLAYWRIGHT_BASE_URL="https://seu-dominio.vercel.app" npx playwright test tests/e2e/release.spec.ts
```

---

## Contas seedadas localmente (apenas ambiente local)

Após `npx supabase db reset`, as seguintes contas de teste E2E são criadas pelo global setup do Playwright:

| Perfil | E-mail | Papel |
|---|---|---|
| Admin Global | `admin.e2e@ceitec.test` | `global_admin` |
| Professor A | `professor.a.e2e@ceitec.test` | Professor do Evento A |
| Professor B | `professor.b.e2e@ceitec.test` | Professor do Evento B |
| Monitor | `monitor.e2e@ceitec.test` | Monitor do Evento A |
| Avaliador Júnior | `avaliador.junior.e2e@ceitec.test` | Avaliador Júnior do Evento A |
| Avaliador Sênior | `avaliador.senior.e2e@ceitec.test` | Avaliador Sênior do Evento A |
| Aluno A | `aluno.a.e2e@ceitec.test` | Aluno (Equipe Aurora — Júnior) |
| Aluno B | `aluno.b.e2e@ceitec.test` | Aluno (Equipe Boreal — Evento B) |

Senha de todas as contas E2E: `Ceitec-E2E-2026!`

> ⚠️ Essas credenciais são exclusivas do Supabase local e **jamais devem ser usadas em produção**.

---

## Operações

Consulte [`docs/operations/new-event.md`](docs/operations/new-event.md) para o passo a passo de criação de um novo hackathon.

### Visualizações e tarefas pendentes

O painel mostra tarefas conforme a **visualização ativa**. Pessoas com mais de
um papel alternam entre Administração, Professor, Monitor, Avaliador e Aluno;
ao mudar a visualização, os atalhos e as notificações são filtrados para o
papel e, quando aplicável, para o evento atual. A tentativa de abrir uma rota
de outra visualização retorna ao painel sem ampliar permissões.

Solicitações de papel não são atalhos primários da barra lateral. Elas chegam
na campainha de notificações e levam à página **Revisar solicitações**:

- solicitações de Professor chegam à Administração;
- solicitações de Monitor e Avaliador chegam aos Professores do evento;
- a página continua protegida pelo papel correspondente, inclusive quando a
  URL é aberta diretamente.

Notificações automáticas representam tarefas pendentes e são filtradas pelo
destinatário, pelo evento e pelo papel ativo. Avisos manuais podem ser enviados
pela Administração ou pelo Professor responsável para participantes aprovados,
papéis do evento, equipes ou pessoas específicas. Se uma notificação não
aparecer, confirme a visualização selecionada, atualize o painel e verifique se
o evento não foi arquivado.

Ao preparar um novo hackathon, a Administração pode iniciar um rascunho vazio
ou copiar a configuração de outro evento. A cópia leva estrutura e conteúdo
configurável, mas nunca equipes, membros, envios, revisões, avaliações,
rankings, resultados, auditoria, presença ou notificações. Se a cópia falhar,
o rascunho de origem permanece intacto: corrija os dados informados e tente
novamente; um rascunho incompleto pode ser ajustado pela tela de eventos.

---

## Estrutura do projeto

```
app/           Páginas, componentes, layouts e composables Nuxt
server/        Endpoints de servidor (API)
shared/        Código compartilhado cliente/servidor (domínio puro)
supabase/      Migrações, seed e testes de banco (pgTAP)
tests/         Testes unitários, de integração e E2E
public/        Assets estáticos (logo, etc.)
.github/       Workflows de CI
docs/          Planos e documentação de operações
```
