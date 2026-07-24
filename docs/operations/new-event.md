# Runbook — Preparar novo Hackathon CEITEC

> **Quem executa:** Apenas o Administrador Global da plataforma.  
> **Pré-condição:** O evento atual está com status `results_published` e os resultados já foram divulgados publicamente.

---

## 1. Confirmar que o evento atual está encerrado

Antes de arquivar, verifique:

- [ ] Os resultados de **ambas as categorias** (Júnior e Sênior) foram publicados na plataforma (`/resultados/<slug-do-evento>`).
- [ ] Os dados de auditoria foram exportados se necessário (acesse `/app/admin/auditoria`).
- [ ] O Professor responsável está ciente de que o evento será arquivado e não poderá ser alterado.

---

## 2. Fazer login recente (reautenticação obrigatória)

O endpoint de arquivamento exige que o token JWT tenha sido emitido há **menos de 10 minutos**.

1. Acesse a plataforma e faça logout.
2. Faça login novamente com sua conta de Admin Global.
3. Navegue imediatamente para `/app/admin/eventos` — **não aguarde**.

---

## 3. Abrir o diálogo de arquivamento

1. Em **Eventos ativos**, localize o evento principal (marcado como "Evento principal").
2. Clique em **"Arquivar"** — o botão vermelho ao lado do evento.
3. Um diálogo de confirmação será exibido.

---

## 4. Preencher o diálogo de confirmação

| Campo | Instrução |
|---|---|
| **Nome exato do evento** | Digite o nome exatamente como aparece na tela, incluindo maiúsculas e acentos. |
| **Segredo de arquivamento** | Insira o segredo configurado na variável `NUXT_EVENT_ARCHIVE_SECRET` (obtido com quem administra a infraestrutura). |
| **Copiar programação, critérios e modelos de Canvas** | ✅ **Marque esta opção** se o novo hackathon usará a mesma programação, critérios de avaliação e templates de Canvas. Deixe desmarcada para começar do zero. |

> ⚠️ **Atenção:** O segredo é validado com comparação em tempo constante. Nunca compartilhe o segredo por canais inseguros.

---

## 5. Confirmar o arquivamento

Clique em **"Confirmar arquivamento"**.

O que acontece automaticamente em uma única transação:

1. O evento atual é marcado como `archived` (somente leitura permanente).
2. Um **novo evento em rascunho** é criado como evento principal, com o nome `<nome original> — novo`.
3. Se a opção de copiar foi marcada, são copiados:
   - Conteúdo público (tagline, apresentação, objetivos, local) — com inscrições fechadas.
   - Programação dos dois dias.
   - Critérios de avaliação e pesos por categoria.
   - Templates de Canvas e seus blocos.
4. A ação é registrada no log de auditoria.

---

## 6. Verificar que o evento antigo está somente leitura

1. Tente acessar `/app/evento/<id-do-evento-antigo>/admin/resultados`.
2. Confirme que a página não permite nenhuma alteração.
3. Os resultados públicos continuam acessíveis em `/resultados/<slug-do-evento-antigo>`.

---

## 7. Configurar o novo evento

Após o arquivamento, o novo rascunho aparece em **Eventos ativos**. Siga os passos:

1. **Renomear o evento:** Acesse o banco de dados (Supabase Dashboard → Table Editor → `events`) e atualize o campo `name` e `slug` para o nome correto da nova edição.
2. **Atribuir o Professor:** No painel de administração, aprove a solicitação de acesso do Professor responsável pela nova edição.
3. **Atualizar o conteúdo público:** O Professor deverá acessar `/app/evento/<novo-id>/admin/conteudo-publico` e revisar/atualizar:
   - Tagline e texto de apresentação.
   - Objetivos da edição.
   - Local e datas.
   - Programação dos dois dias.
   - Abrir as inscrições quando estiver pronto.
4. **Revisar critérios de avaliação:** O Professor deve confirmar ou ajustar os critérios e pesos copiados da edição anterior.
5. **Revisar templates de Canvas:** O Professor deve confirmar ou atualizar os templates de Canvas para a nova edição.

---

## 8. Verificar o novo evento em produção

```bash
# Smoke test confirmando que a landing page reflete o novo evento
PLAYWRIGHT_BASE_URL="https://hackathon-ceitec.vercel.app" npx playwright test tests/e2e/release.spec.ts
```

---

## Recuperação em caso de falha

| Sintoma | Causa provável | Ação |
|---|---|---|
| "Autenticação recente necessária" | Token com mais de 10 minutos | Faça logout e login novamente |
| "O nome do evento não confere" | Nome digitado incorretamente | Copie e cole o nome da tela |
| "Acesso negado" no segredo | Segredo incorreto ou variável de ambiente desatualizada | Verifique `NUXT_EVENT_ARCHIVE_SECRET` com a equipe de infra |
| "Somente o evento principal pode ser arquivado" | O evento selecionado não é o evento principal | Verifique qual evento está marcado como `is_featured = true` |
| "Evento já arquivado" | A operação foi executada duas vezes | O evento já foi arquivado com sucesso — verifique o novo rascunho |
