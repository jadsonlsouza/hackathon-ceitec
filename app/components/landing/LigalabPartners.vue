<script setup lang="ts">
const partners = [
  {
    name: 'Liga de Inovação',
    role: 'Realização',
    desc: 'Liga de Empreendedorismo e Inovação',
    sub: 'Projeto de Extensão Universitária',
    src: '/brand/liga-inovacao.png',
    alt: 'Liga de Empreendedorismo e Inovação',
    width: 1024,
    height: 839,
    classModifier: 'liga',
    isLead: true,
  },
  {
    name: 'Metrópole Digital',
    role: 'Ecossistema',
    desc: 'Instituto Metrópole Digital (IMD)',
    sub: 'Polo Tecnológico & Inovação',
    src: '/brand/metropole-digital.png',
    alt: 'Instituto Metrópole Digital — IMD',
    width: 1024,
    height: 248,
    classModifier: 'imd',
    isLead: false,
  },
  {
    name: 'UFRN',
    role: 'Instituição',
    desc: 'Universidade Federal do Rio Grande do Norte',
    sub: 'Ensino, Pesquisa e Extensão',
    src: '/brand/ufrn.png',
    alt: 'Universidade Federal do Rio Grande do Norte — UFRN',
    width: 594,
    height: 188,
    classModifier: 'ufrn',
    isLead: false,
  },
]
</script>

<template>
  <section class="ligalab-partners" aria-label="Realização e Apoio Institucional">
    <div class="ligalab-partners__inner">
      <p class="partners-eyebrow">Iniciativa & Realização Institucional</p>
      <div class="partners-grid">
        <article
          v-for="partner in partners"
          :key="partner.name"
          class="partner-card"
          :class="`partner-card--${partner.classModifier}`"
        >
          <div class="partner-logo-box">
            <img
              :src="partner.src"
              :alt="partner.alt"
              :width="partner.width"
              :height="partner.height"
              class="partner-logo"
              :class="`partner-logo--${partner.classModifier}`"
            >
          </div>
          <div class="partner-meta">
            <span
              class="partner-badge"
              :class="{ 'partner-badge--lead': partner.isLead }"
            >
              {{ partner.role }}
            </span>
            <h3 class="partner-name">{{ partner.name }}</h3>
            <p class="partner-desc">{{ partner.desc }}</p>
            <span class="partner-sub">{{ partner.sub }}</span>
          </div>
        </article>
      </div>
    </div>
  </section>
</template>
