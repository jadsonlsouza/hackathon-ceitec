<script setup lang="ts">
const metrics = [
  {
    value: '5 Pilares',
    label: 'Framework FORMA',
    detail: 'Formar, Organizar, Realizar, Multiplicar e Apoiar',
  },
  {
    value: 'Equipes',
    label: 'Projetos colaborativos',
    detail: 'Participantes organizam suas entregas em conjunto',
  },
  {
    value: 'Canvas',
    label: 'Atividades e feedback',
    detail: 'Envios acompanhados por professores e monitores',
  },
  {
    value: 'Extensão Universitária',
    label: 'Impacto Social & Acadêmico',
    detail: 'Conexão real entre universidade, sociedade e ecossistema tech',
  },
]
</script>

<template>
  <section class="ligalab-metrics-bar" aria-label="Métricas e destaques do Ligalab">
    <div class="ligalab-metrics-grid">
      <div v-for="item in metrics" :key="item.label" class="ligalab-metric-item">
        <span class="ligalab-metric-value">{{ item.value }}</span>
        <strong class="ligalab-metric-label">{{ item.label }}</strong>
        <p class="ligalab-metric-detail">{{ item.detail }}</p>
      </div>
    </div>
  </section>
</template>
