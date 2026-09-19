<script setup lang="ts">
const partners = [
  {
    name: 'Liga de Inovação',
    badge: 'Origem & Metodologia',
    title: 'Liga de Empreendedorismo e Inovação',
    subtitle: 'Projeto de Extensão Universitária',
    description: 'Projeto extensionista que fomenta o protagonismo estudantil, a cultura empreendedora e concebeu o Ligalab a partir da vivência prática na facilitação de eventos.',
    src: '/brand/liga-inovacao.png',
    alt: 'Liga de Empreendedorismo e Inovação',
    width: 1024,
    height: 839,
    classModifier: 'liga',
    isLead: true,
  },
  {
    name: 'Metrópole Digital',
    badge: 'Ecossistema Tecnológico',
    title: 'Instituto Metrópole Digital (IMD)',
    subtitle: 'Polo Tecnológico & Inovação',
    description: 'Centro de excelência em tecnologia da informação e inovação, abrigando projetos de ponta e fortalecendo o ecossistema potiguar e nacional.',
    src: '/brand/metropole-digital.png',
    alt: 'Instituto Metrópole Digital — IMD',
    width: 1024,
    height: 248,
    classModifier: 'imd',
    isLead: false,
  },
  {
    name: 'UFRN',
    badge: 'Instituição de Origem',
    title: 'Universidade Federal do Rio Grande do Norte',
    subtitle: 'Ensino, Pesquisa e Extensão',
    description: 'Uma das principais universidades do Brasil, ancorando a extensão universitária como elemento transformador para a formação cidadã e o desenvolvimento regional.',
    src: '/brand/ufrn.png',
    alt: 'Universidade Federal do Rio Grande do Norte — UFRN',
    width: 594,
    height: 188,
    classModifier: 'ufrn',
    isLead: false,
  },
]

const pillars = [
  {
    icon: '🎯',
    title: 'Protagonismo Estudantil',
    desc: 'Estudantes liderando o design de processos, a facilitação de equipes e a criação de tecnologia aplicada.',
  },
  {
    icon: '🌱',
    title: 'Comunidade Permanente',
    desc: 'Formação continuada que capacita veteranos e novatos para multiplicar a cultura de inovação ano após ano.',
  },
  {
    icon: '🌐',
    title: 'Extensão de Alto Impacto',
    desc: 'Conexão direta entre o conhecimento acadêmico, demandas do ecossistema e desafios sociais reais.',
  },
]
</script>

<template>
  <section id="origem-liga" class="landing-section ligalab-origin" aria-labelledby="origin-title">
    <div class="ligalab-section-header">
      <p class="section-index">Nossa Origem & Propósito</p>
      <h2 id="origin-title">Nascido da Liga de Empreendedorismo e Inovação</h2>
      <p class="section-copy">
        O Ligalab não é um software genérico. Ele nasceu na vivência diária de estudantes e facilitadores universitários, unindo metodologia ativa e tecnologia para transformar o ecossistema de maratonas de inovação.
      </p>
    </div>

    <!-- História & Narrativa da Concepção -->
    <div class="origin-story-box">
      <div class="origin-story-content">
        <span class="origin-badge">Extensão Universitária • IMD / UFRN</span>
        <h3 class="origin-story-heading">Criado por quem vive maratonas e hackathons de verdade</h3>
        <p class="origin-story-text">
          A <strong>Liga de Empreendedorismo e Inovação</strong> é um projeto de extensão universitária do <strong>Instituto Metrópole Digital (IMD)</strong> da <strong>Universidade Federal do Rio Grande do Norte (UFRN)</strong>. Formada por alunos dedicados a transformar o aprendizado em ação, a Liga atua na capacitação de novos líderes e na organização de maratonas de ideação.
        </p>
        <p class="origin-story-text">
          Ao coordenar eventos com dezenas de equipes simultâneas, nossa equipe sentiu na pele as maiores dores do setor: planilhas frágeis que se perdiam, filas caóticas para chamar mentores e processos manuais de apuração. Para solucionar essas dores de forma definitiva, desenhamos e desenvolvemos o <strong>Ligalab</strong>: um sistema completo, fluido e centrado nas pessoas.
        </p>

        <!-- Pilares do DNA da Liga -->
        <div class="origin-pillars-grid">
          <div v-for="pillar in pillars" :key="pillar.title" class="origin-pillar-item">
            <span class="origin-pillar-icon" aria-hidden="true">{{ pillar.icon }}</span>
            <div class="origin-pillar-text">
              <strong class="origin-pillar-title">{{ pillar.title }}</strong>
              <span class="origin-pillar-desc">{{ pillar.desc }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Cards Institucionais (Liga, IMD, UFRN) -->
    <div class="origin-partners-grid">
      <article
        v-for="partner in partners"
        :key="partner.name"
        class="origin-partner-card"
        :class="`origin-partner-card--${partner.classModifier}`"
      >
        <div class="origin-logo-box">
          <img
            :src="partner.src"
            :alt="partner.alt"
            :width="partner.width"
            :height="partner.height"
            class="origin-partner-logo"
            :class="`origin-partner-logo--${partner.classModifier}`"
          >
        </div>
        <div class="origin-partner-body">
          <span
            class="origin-partner-badge"
            :class="{ 'origin-partner-badge--lead': partner.isLead }"
          >
            {{ partner.badge }}
          </span>
          <h4 class="origin-partner-name">{{ partner.title }}</h4>
          <p class="origin-partner-sub">{{ partner.subtitle }}</p>
          <p class="origin-partner-desc">{{ partner.description }}</p>
        </div>
      </article>
    </div>
  </section>
</template>
