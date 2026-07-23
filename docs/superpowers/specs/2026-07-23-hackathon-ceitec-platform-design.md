# Design da Plataforma Hackathon CEITEC

**Data:** 23 de julho de 2026  
**Status:** aprovado para planejamento  
**Escopo:** landing page pública e sistema multi-evento para equipes, Canvas, avaliações e resultados

## 1. Objetivo

Criar uma plataforma web para administrar o Hackathon CEITEC de ponta a ponta. O sistema deve divulgar o evento, autenticar participantes, formar e validar equipes, receber atividades Canvas, apoiar apresentações e avaliações, calcular rankings separados por categoria e publicar os resultados.

A arquitetura já deve aceitar novos hackathons no futuro, embora a primeira implantação tenha somente o evento atual.

## 2. Arquitetura

A solução será um monólito modular composto por:

- **Nuxt 4 e Vue 3** para a landing page e todas as áreas autenticadas;
- **Vercel** para publicação do frontend e das rotas server-side;
- **Supabase Auth** para autenticação;
- **Supabase PostgreSQL** para dados relacionais e regras transacionais;
- **Row Level Security (RLS)** para isolamento de perfis, equipes e eventos;
- **Supabase Realtime** para prazos, convites, filas, avaliações e resultados;
- **Dark mode nativo**, com experiência mobile-first para avaliadores.

As regras críticas serão executadas no servidor ou no banco. O cliente não poderá promover usuários, alterar registros de terceiros, ultrapassar limites de equipe, manipular pesos, consolidar rankings ou publicar resultados diretamente.

Os módulos funcionais serão: identidade, eventos, equipes, atividades Canvas, apresentações, avaliações, resultados, auditoria e conteúdo público.

## 3. Eventos e isolamento

Todos os dados operacionais terão um `event_id`: perfis concedidos no evento, equipes, membros, atividades, entregas, critérios, pesos, avaliadores, sorteios, avaliações, rankings e desempates.

Cada evento terá exatamente um Professor responsável. O Administrador Geral poderá criar o evento e atribuir ou substituir esse Professor. Um Professor administrará somente seu evento atribuído. A possibilidade de vários professores no mesmo evento fica fora do primeiro escopo.

Estados do evento:

- `rascunho`;
- `inscricoes_abertas`;
- `em_andamento`;
- `avaliacao`;
- `resultados_publicados`;
- `arquivado`.

Eventos arquivados serão somente leitura e continuarão disponíveis para consulta e auditoria.

## 4. Autenticação e perfis

### 4.1 Formas de acesso

O sistema aceitará:

- cadastro e login por e-mail e senha;
- verificação de e-mail;
- recuperação e redefinição de senha;
- login com Google OAuth.

Contas que usam os dois métodos serão associadas pela identidade confirmada no Supabase, sem criar perfis duplicados.

### 4.2 Perfis

Os perfis são:

1. **Administrador Geral:** administra a plataforma, cria eventos, aprova Professores e executa o arquivamento seguro.
2. **Professor/Administrador do evento:** administra um evento, aprova equipes, Monitores e Avaliadores, configura Canvas, critérios, apresentações e resultados.
3. **Monitor:** revisa entregas Canvas, altera seu status e pode enviar feedback.
4. **Avaliador:** avalia equipes nas categorias para as quais foi designado.
5. **Aluno:** participa de uma equipe e colabora nas atividades.

Todo usuário começa como Aluno. No cadastro ou posteriormente, poderá solicitar o perfil de Monitor, Avaliador ou Professor:

- o Administrador Geral aprova ou rejeita solicitações de Professor;
- o Professor aprova ou rejeita solicitações de Monitor e Avaliador para seu evento;
- a solicitação não concede permissões enquanto estiver pendente;
- aprovações, rejeições e revogações ficam no histórico de auditoria.

Um usuário poderá manter o acesso de Aluno e acumular uma função operacional em um evento quando isso não gerar conflito. Para preservar a exigência de que todos os Avaliadores pontuem todas as equipes da categoria, um integrante de equipe não poderá ser designado como Avaliador daquela mesma categoria no mesmo evento.

## 5. Equipes e colaboração

Uma equipe pertence a um único evento e a uma única categoria:

- **Júnior:** 6º ao 9º ano do Ensino Fundamental II;
- **Sênior:** 1ª e 2ª série do Ensino Médio.

O líder define nome e categoria e cadastra de um a seis integrantes com nome, e-mail e matrícula. Convites pendentes já ocupam uma das seis vagas.

O fluxo de associação é:

1. O líder cadastra o e-mail do integrante.
2. O integrante autentica com o mesmo e-mail.
3. O sistema encontra o convite e cria a solicitação de associação.
4. O líder aprova ou rejeita a entrada.
5. Após a aprovação, o integrante pode colaborar nos Canvas.

E-mail e matrícula não podem estar ativos ou reservados em equipes diferentes no mesmo evento. A validação deve ser transacional para impedir conflitos simultâneos.

O Professor valida a equipe. Enquanto aguarda, os membros podem editar rascunhos, mas não podem enviar atividades. Monitores não podem aprovar equipes.

## 6. Atividades Canvas e entregas

O Professor poderá criar várias atividades Canvas em um evento. Cada atividade terá:

- título e instruções;
- categorias participantes;
- data de abertura e prazo;
- blocos e campos configuráveis;
- status de publicação;
- indicação opcional de atividade principal;
- política de reenvio.

Modelos poderão ser duplicados dentro do evento ou copiados para um novo evento. Os blocos iniciais sugeridos são:

- **Explorar:** causas raiz, consequências e soluções atuais;
- **Cliente:** dores, desejos e comportamento;
- **Solução:** resumo em uma frase, proposta de valor, concorrentes e vantagem competitiva;
- **Avaliar:** MVP com até três funcionalidades essenciais;
- **Lançar:** TAM e posicionamento;
- **Acelerar:** modelo de receita e precificação.

O resumo da atividade principal será exibido no cabeçalho da avaliação.

### 6.1 Colaboração e autosave

Todos os membros aprovados colaboram no rascunho. O autosave mostrará `salvando`, `salvo` ou `erro ao salvar`. Edições em blocos diferentes coexistem. Em conflito no mesmo bloco, prevalece a versão mais recente e os usuários recebem um aviso.

### 6.2 Revisão

Estados da entrega:

- `rascunho`;
- `enviado`;
- `em_analise`;
- `devolvido`;
- `reenviado`;
- `aprovado`.

Fluxo:

1. A equipe aprovada envia a atividade antes do prazo.
2. A entrega entra na fila do Professor e dos Monitores.
3. Um revisor assume a análise; o bloqueio impede dois revisores simultâneos.
4. O revisor aprova ou devolve para ajustes.
5. O feedback é opcional em qualquer decisão.
6. A equipe vê imediatamente o status e o eventual feedback.
7. Uma entrega devolvida pode ser corrigida e reenviada conforme a política da atividade.

O Professor poderá reabrir uma entrega excepcionalmente, com justificativa registrada. Todas as versões, mudanças de estado, revisores, datas e feedbacks serão preservados.

## 7. Apresentações e avaliações

O Professor poderá sortear a ordem de apresentações separadamente por categoria. O Realtime atualizará a fila dos Avaliadores.

Os critérios iniciais, com notas inteiras de 1 a 5, serão:

1. Time;
2. Solução;
3. Pensamento Computacional e Viabilidade;
4. Apresentação;
5. Mercado.

Todos os pesos começam em `1`. O Professor poderá alterá-los separadamente para Júnior e Sênior antes do início das avaliações.

O Professor designará cada Avaliador para Júnior, Sênior ou ambas. Todos os Avaliadores designados para uma categoria serão obrigatórios para todas as equipes dessa categoria. Uma equipe só terá pontuação consolidada quando todos eles enviarem suas avaliações.

A tela mobile-first do Avaliador mostrará:

- nome e categoria da equipe;
- posição na ordem de apresentação;
- frase-resumo da solução;
- nota de 1 a 5 por critério;
- comentário textual;
- estado do salvamento e confirmação do envio.

Cada Avaliador poderá manter uma única avaliação por equipe e atualizá-la até o encerramento definido pelo Professor. O sistema impedirá autoavaliação e acesso fora das categorias designadas.

## 8. Ranking e desempate

Para cada avaliação, a pontuação será:

`soma(nota × peso) / soma(pesos)`

A pontuação final da equipe será a média aritmética das pontuações de todos os Avaliadores obrigatórios da categoria. O ranking exibirá duas casas decimais. Equipes com pontuação exibida igual serão consideradas empatadas.

Os rankings Júnior e Sênior serão independentes. Antes da publicação, somente os perfis administrativos autorizados verão o ranking ao vivo.

Quando houver empate:

1. O sistema cria uma pendência para a categoria.
2. A publicação dessa categoria fica bloqueada.
3. O Professor consulta equipes, notas e comentários e delibera com os Avaliadores.
4. O Professor ordena manualmente as equipes empatadas.
5. O Professor registra uma justificativa obrigatória.
6. O sistema salva a ordem, a justificativa, o responsável e a data.

O desempate não altera as notas originais; ele define somente a ordem final entre equipes empatadas. Empates com três ou mais equipes seguem o mesmo fluxo de ordenação completa.

## 9. Publicação e landing page

O Professor poderá publicar o resultado de cada categoria apenas quando:

- todas as equipes elegíveis tiverem todas as avaliações obrigatórias;
- não houver empate pendente;
- o evento estiver na fase correta.

A landing page pública terá:

- hero “Hackathon CEITEC — Criando soluções, conectando o futuro”;
- chamada para inscrição;
- apresentação e objetivos;
- público-alvo e categorias;
- data e local;
- programação dos dois dias;
- acesso ao sistema;
- resultados Júnior e Sênior após a publicação.

## 10. Administração e telas

### Administrador Geral

- eventos ativos e arquivados;
- criação de eventos;
- aprovação de Professores;
- atribuição de Professor responsável;
- auditoria global;
- preparação de novo hackathon.

### Professor

- visão geral do evento;
- solicitações de Monitor e Avaliador;
- equipes e aprovação;
- atividades, modelos e entregas Canvas;
- critérios e pesos por categoria;
- designação de Avaliadores;
- sorteio e fila de apresentações;
- progresso das avaliações;
- rankings, desempates e publicação.

### Monitor

- fila de entregas;
- detalhe e histórico da entrega;
- aprovação ou devolução;
- feedback opcional.

### Avaliador

- fila por categoria;
- avaliação mobile-first;
- histórico das próprias avaliações.

### Aluno

- equipe, convites e solicitações;
- atividades disponíveis;
- Canvas colaborativo;
- estados, histórico e feedback das entregas;
- contagem regressiva.

## 11. Preparação de um novo hackathon

A ação “Preparar novo hackathon” será exclusiva do Administrador Geral e exigirá:

- sessão autenticada e reautenticação recente;
- senha secreta adicional validada somente no servidor;
- digitação do nome do evento como confirmação;
- registro de autor, data e evento afetado.

A senha secreta não será armazenada em texto puro no banco ou enviada ao cliente; sua verificação usará configuração segura do ambiente server-side.

A operação arquivará o evento atual sem apagar seus dados e criará um novo evento vazio. O Administrador Geral poderá copiar critérios, pesos, programação e modelos de Canvas. Equipes, membros, convites, entregas, notas, avaliações, desempates e resultados nunca serão copiados.

## 12. Atualizações em tempo real

O Realtime atualizará:

- contagem regressiva e prazos;
- status de convites, membros e equipes;
- ordem de apresentação;
- estados das entregas e fila de revisão;
- progresso das avaliações;
- rankings administrativos;
- resultados públicos após publicação.

Falhas de conexão não apagarão dados digitados. A interface mostrará o estado offline e tentará sincronizar rascunhos novamente.

## 13. Tratamento de erros e auditoria

O sistema deve:

- impedir a sétima vaga contando convites pendentes;
- impedir e-mail ou matrícula em equipes concorrentes;
- bloquear envio de equipe ainda não aprovada;
- rejeitar notas fora da escala;
- impedir avaliação fora da categoria designada;
- impedir dois revisores na mesma entrega;
- não consolidar ranking incompleto;
- não publicar empate pendente;
- impedir alterações em evento arquivado;
- preservar rascunhos diante de falhas recuperáveis.

Haverá auditoria para mudanças de perfil, atribuição de Professor, aprovação de equipe, revisão de entrega, configuração de pesos, avaliações, desempates, publicação e arquivamento.

## 14. Estratégia de testes

### Testes unitários

- cálculo ponderado e arredondamento;
- consolidação com todos os Avaliadores;
- identificação e ordenação de empates;
- limite de equipe;
- transições de estado;
- validações de nota e prazo.

### Testes de integração

- Google OAuth;
- e-mail/senha, verificação e recuperação;
- convite e aprovação pelo líder;
- solicitações e aprovações de perfil;
- aprovação de equipe;
- autosave e versionamento;
- envio, revisão, devolução e reenvio;
- sorteio, avaliação, ranking e publicação;
- desempate auditável;
- arquivamento e criação de novo evento.

### Testes de segurança

- isolamento entre eventos;
- RLS por perfil e equipe;
- Professor limitado ao evento atribuído;
- Monitor limitado às entregas autorizadas;
- Avaliador limitado às categorias designadas;
- bloqueio de autoavaliação;
- segredo de arquivamento indisponível no cliente;
- evento arquivado imutável.

### Testes ponta a ponta

- jornada pública até cadastro e formação da equipe;
- jornada completa do Canvas até aprovação;
- jornada de apresentação e avaliação;
- publicação com e sem empate;
- preparação segura do próximo hackathon.

## 15. Critérios de conclusão

O produto estará pronto quando:

- as jornadas principais funcionarem em celular e desktop;
- a landing page apresentar todo o conteúdo do evento;
- os cinco perfis respeitarem suas permissões;
- equipes e entregas seguirem os fluxos definidos;
- rankings puderem ser reproduzidos a partir das avaliações;
- empates impedirem publicação até decisão auditável;
- eventos não vazarem dados entre si;
- o arquivamento preservar integralmente o histórico;
- os testes críticos de regra, integração, segurança e ponta a ponta passarem.

## 16. Fora do primeiro escopo

- vários Professores responsáveis pelo mesmo evento;
- aplicativo móvel nativo;
- pagamentos;
- chat em tempo real;
- exclusão definitiva de eventos;
- importação automática de equipes por planilha;
- integrações com sistemas acadêmicos externos.
