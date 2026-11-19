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
    title: 'Avaliação com critérios e pesos',
    description: 'Defina critérios com notas e pesos personalizados. Coleta de avaliações em fluxo congelado, cálculo de médias ponderadas sem erros manuais e resolução transparente de empates com auditoria completa.',
    highlight: 'Zero planilhas manuais',
  },
  {
    icon: '🤝',
    tag: 'Acompanhamento',
    title: 'Revisão de envios',
    description: 'Professores e monitores acompanham as entregas das equipes, aprovam envios e podem deixar feedback.',
    highlight: 'Status para a equipe',
  },
  {
    icon: '👥',
    tag: 'Organização de Times',
    title: 'Gestão de Equipes & Categorias',
    description: 'Organize equipes por categoria, acompanhe integrantes e valide a participação no evento.',
    highlight: 'Equipes por evento',
  },
  {
    icon: '⏱️',
    tag: 'Ritmo do Evento',
    title: 'Oficinas e presença',
    description: 'Organize oficinas e acompanhe os registros de presença dos participantes.',
    highlight: 'Oficinas e presença',
  },
  {
    icon: '🏆',
    tag: 'Transparência & Visibilidade',
    title: 'Resultados por categoria',
    description: 'Acompanhe a avaliação e publique os resultados oficiais de cada categoria.',
    highlight: 'Resultados públicos',
  },
]
</script>

<template>
  <section id="recursos" class="landing-section ligalab-features" aria-labelledby="features-title">
    <div class="ligalab-section-header">
      <p class="section-index">Recursos Tecnológicos</p>
      <h2 id="features-title">Recursos para organizar o evento</h2>
      <p class="section-copy">
        Da formação das equipes à publicação dos resultados, acompanhe as etapas do hackathon.
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
