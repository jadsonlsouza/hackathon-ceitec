<script setup lang="ts">
const features = [
  {
    icon: '⚡',
    tag: 'Ideação Ativa',
    title: 'Canvas de Projetos Dinâmico',
    description: 'Guie as equipes passo a passo em blocos de ideação estruturados (5W2H, Lean Startup, Proposta de Valor). Salvamento automático contínuo para evitar perda de dados e suporte a feedback direto dos mentores.',
    highlight: 'Autosave em tempo real',
  },
  {
    icon: '⚖️',
    tag: 'Avaliação & Rigor',
    title: 'Bancas Julgadoras & Algoritmo de Desempate',
    description: 'Defina critérios com notas e pesos personalizados. Coleta de avaliações em fluxo congelado, cálculo de médias ponderadas sem erros manuais e resolução transparente de empates com auditoria completa.',
    highlight: 'Zero planilhas manuais',
  },
  {
    icon: '🤝',
    tag: 'Facilitação Ágil',
    title: 'Fila Inteligente de Mentoria',
    description: 'Elimine os gargalos durante a maratona. As equipes abrem chamados com descrição da dúvida e os mentores disponíveis atendem em ordem de prioridade, com histórico de checkpoints registrado.',
    highlight: 'Helpdesk sem filas',
  },
  {
    icon: '👥',
    tag: 'Organização de Times',
    title: 'Gestão de Equipes & Categorias',
    description: 'Formação flexível de equipes com link de convite rápido, atribuição de líderes, distribuição por categorias acadêmicas e validação de integrantes com limites pré-configurados.',
    highlight: 'Convite em 1 clique',
  },
  {
    icon: '⏱️',
    tag: 'Ritmo do Evento',
    title: 'Presença & Trilhas Simultâneas',
    description: 'Controle de frequência integrado por oficinas e palestras simultâneas (IA, prototipagem, negócios). Acompanhamento de progresso de cada participante ao longo de todos os dias da maratona.',
    highlight: 'Check-in dinâmico',
  },
  {
    icon: '🏆',
    tag: 'Transparência & Visibilidade',
    title: 'Placar em Tempo Real & Vitrine Pública',
    description: 'Publique o ranking oficial com um único clique quando as bancas encerrarem as notas. Página pública indexável com soluções geradas, notas por categoria e arquivo perpétuo do evento.',
    highlight: 'Publicação instantânea',
  },
]
</script>

<template>
  <section id="recursos" class="landing-section ligalab-features" aria-labelledby="features-title">
    <div class="ligalab-section-header">
      <p class="section-index">Recursos Tecnológicos</p>
      <h2 id="features-title">Tecnologia desenhada para orquestrar o caos criativo</h2>
      <p class="section-copy">
        Do primeiro rascunho de ideia à apuração final das notas, o Ligalab oferece todas as ferramentas para organizar, executar e auditar maratonas de inovação de forma profissional.
      </p>
    </div>

    <div class="ligalab-bento-grid">
      <article
        v-for="(feature, idx) in features"
        :key="feature.title"
        class="bento-card"
        :class="`bento-card--${idx}`"
      >
        <div class="bento-card__top">
          <span class="bento-card__icon" aria-hidden="true">{{ feature.icon }}</span>
          <span class="bento-card__tag">{{ feature.tag }}</span>
        </div>
        <h3 class="bento-card__title">{{ feature.title }}</h3>
        <p class="bento-card__desc">{{ feature.description }}</p>
        <div class="bento-card__footer">
          <span class="bento-card__highlight">{{ feature.highlight }}</span>
        </div>
      </article>
    </div>
  </section>
</template>
