# Ligalab: marca da plataforma e catálogo de eventos

## Objetivo

Transformar a identidade institucional da aplicação em **ligalab**, sem alterar
o nome, a programação, os resultados ou o histórico do **Hackathon CEITEC**.
O site público deixa de presumir que existe um único evento e passa a apresentar
o Hackathon CEITEC como o primeiro evento do catálogo.

## Escopo e critérios de sucesso

- A raiz (`/`) apresenta o ligalab, sua proposta e uma chamada para explorar
  eventos; ela não apresenta inscrições de um evento específico como se fossem
  da plataforma inteira.
- `/eventos` lista somente eventos publicáveis e oferece uma navegação
  semântica e responsiva para cada um deles.
- `/eventos/:eventSlug` mostra a página pública detalhada de um evento. Para
  `hackathon-ceitec`, o conteúdo existente (apresentação, categorias,
  programação, inscrições e resultados) é preservado.
- Cabeçalhos, telas de autenticação, painel, página de erro, metadados,
  rodapé e textos institucionais usam **ligalab**. Textos cujo sujeito é o
  evento continuam usando **Hackathon CEITEC**.
- As duas imagens entregues são convertidas/otimizadas como ativos locais:
  versão colorida para fundos claros e versão branca horizontal para fundos
  escuros. Cada imagem tem texto alternativo adequado ou é decorativa quando
  acompanhada de uma marca textual acessível.
- Temas claro e escuro, navegação por teclado, foco visível, skip link,
  contraste e comportamento de indisponibilidade permanecem acessíveis.

## Informação e rotas

| Rota | Responsabilidade |
| --- | --- |
| `/` | Landing institucional ligalab, com marca, explicação concisa e CTA para `/eventos`. |
| `/eventos` | Catálogo público de eventos publicáveis; cada card leva ao seu detalhe. |
| `/eventos/:eventSlug` | Página pública de um evento, substituindo a antiga landing única. |
| `/resultados/:eventSlug` | Mantida para resultado compartilhável; passa a ter navegação visual ligalab. |
| `/app/**` | Área autenticada; marca institucional ligalab, sem renomear títulos dos eventos. |

A rota raiz não redireciona automaticamente para o evento em destaque. O
catálogo tem prioridade como ponto de entrada da plataforma. Caso não haja
eventos publicáveis, ele mostra um estado vazio seguro, sem ação de inscrição.

## Arquitetura de dados públicos

O navegador nunca consulta tabelas de eventos diretamente. Serão criadas duas
interfaces públicas, de dados mínimos e sem informações de participantes:

1. `get_public_event_catalog()` retorna slug, nome, chamada, local/período,
   estado de inscrição e imagem/campo permitido para cards. Só retorna eventos
   que a política de publicação permite mostrar.
2. `get_public_event_content(event_slug)` retorna o conteúdo público de um
   único evento, programação e resultados já publicados. A chamada para
   resultados mantém a regra existente de somente expor categorias publicadas.

Endpoints Nitro finos consomem essas RPCs com a chave publicável apenas no
campo `apikey`, normalizam falhas para uma resposta pública segura e não fazem
fallback de produção para dados estáticos que anunciem inscrições. O fallback
local continua disponível somente em desenvolvimento/teste.

O editor de conteúdo público continua pertencendo ao Professor do evento. Ele
edita o conteúdo daquele evento, não a apresentação institucional do ligalab.

## Componentes e identidade visual

- `PlatformHeader` concentra logo, links `Eventos`, `Entrar` e `Cadastrar-se`,
  além do seletor de tema existente.
- `LigalabHome` contém hero institucional e uma prévia do catálogo; não duplica
  o conteúdo de um evento.
- `EventCatalog` e `EventCard` exibem cards com nome, período/local, status de
  inscrição e CTA acessível.
- `EventPublicPage` reaproveita as seções existentes (`HeroSection`,
  apresentação, categorias, cronograma e resultados), recebendo conteúdo pelo
  slug em vez de assumir CEITEC.
- Um pequeno componente `BrandLogo` escolhe a variante adequada a cada fundo,
  fixa dimensões para evitar deslocamento de layout e torna o nome da marca
  acessível.

O design preserva a paleta azul/ciano e os tokens CSS atuais. A marca colorida
é usada em superfícies claras; em superfícies escuras, é usada a marca branca
horizontal. Não serão introduzidas bibliotecas visuais ou fontes remotas novas.

## Rebranding de texto e configuração

São atualizados: `useHead` global e por página, título do Nuxt, marca no painel,
auth/onboarding/erro, rodapés, README, smoke/release tests e o identificador de
serviço de saúde quando ele for somente institucional. O identificador técnico
do projeto Vercel, o repositório, slugs já publicados e contas/fixtures E2E não
são renomeados, pois não aparecem como marca ao usuário e alterá-los quebraria
URLs ou automações.

## Segurança e falhas

- RPCs públicas são `SECURITY DEFINER`, com `search_path` fixo, privilégios
  mínimos e somente colunas necessárias.
- Eventos arquivados, não publicados ou sem conteúdo público não entram no
  catálogo.
- Um slug desconhecido resulta em 404/estado de evento indisponível sem expor
  detalhes internos.
- Falhas de API são sanitizadas. Em produção, a página não exibe conteúdo
  estático enganoso nem CTAs de inscrição quando a origem não está disponível.

## Testes e verificação

- Testes unitários para o mapeamento de marca e estados do catálogo.
- Testes Nuxt/SSR para `/`, `/eventos` e `/eventos/:slug`, incluindo estado
  vazio, slug inexistente e metadados ligalab.
- pgTAP para catálogo/conteúdo público: filtragem por estado, isolamento de
  campos privados e resultados apenas publicados.
- Testes de componentes para logo, links, tema, foco e cards.
- Build de produção, suíte Vitest completa, pgTAP completo e checagem de diff.
