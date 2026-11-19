<script setup lang="ts">
import { ref } from 'vue'

interface WorkflowStep {
  id: string
  phase: string
  title: string
  subtitle: string
  description: string
  icon: string
  deliverables: string[]
  previewMetrics: { label: string; value: string }[]
}

const steps: WorkflowStep[] = [
  {
    id: 'setup',
    phase: 'Fase 01 — Antes do Início',
    title: 'Setup & Configuração Ágil do Evento',
    subtitle: 'Tudo pronto em minutos, sem complicação',
    description: 'Configure os dados do evento, as categorias e os critérios de avaliação.',
    icon: '⚙️',
    deliverables: [
      'Página pública e links de inscrição prontos',
      'Configuração de rubricas e pesos para jurados',
      'Organização das categorias do evento',
      'Gestão de professores responsáveis',
    ],
    previewMetrics: [
      { label: 'Organização', value: 'Por evento' },
      { label: 'Avaliação', value: 'Critérios e pesos' },
    ],
  },
  {
    id: 'equipes-canvas',
    phase: 'Fase 02 — Durante a Maratona',
    title: 'Formação de Equipes & Canvas Colaborativo',
    subtitle: 'Ambiente estruturado para ideação com salvamento contínuo',
    description: 'Os participantes criam suas equipes e trabalham nas atividades disponibilizadas pela organização.',
    icon: '🧩',
    deliverables: [
      'Formação rápida de equipes com liderança definida',
      'Canvas em tempo real com autosave instantâneo',
      'Acompanhamento do status dos envios',
      'Atividades configuradas pela organização',
    ],
    previewMetrics: [
      { label: 'Autosave', value: 'Em tempo real' },
      { label: 'Entrega', value: 'Por equipe' },
    ],
  },
  {
    id: 'mentoria',
    phase: 'Fase 03 — Aceleração das Ideias',
    title: 'Revisão de entregas',
    subtitle: 'Acompanhamento por professores e monitores',
    description: 'A organização revisa os envios das equipes, aprova entregas e pode deixar feedback.',
    icon: '💡',
    deliverables: [
      'Consulta aos envios das equipes',
      'Validação das entregas',
      'Feedback opcional para os alunos',
      'Status disponível para a equipe',
    ],
    previewMetrics: [
      { label: 'Responsáveis', value: 'Professores e monitores' },
      { label: 'Retorno', value: 'Status e feedback' },
    ],
  },
  {
    id: 'bancas-placar',
    phase: 'Fase 04 — O Grande Final',
    title: 'Avaliação e resultados',
    subtitle: 'Avaliação sem planilhas e com desempate transparente',
    description: 'Os avaliadores atribuem notas conforme os critérios do evento. A organização acompanha a apuração e registra as decisões de desempate.',
    icon: '🏆',
    deliverables: [
      'Interface limpa de pontuação para bancas avaliadoras',
      'Cálculo de médias ponderadas',
      'Registro das decisões de desempate',
      'Publicação dos resultados por categoria',
    ],
    previewMetrics: [
      { label: 'Notas', value: 'Por critério' },
      { label: 'Resultados', value: 'Por categoria' },
    ],
  },
]

const activeStepIndex = ref(0)
const activeStep = computed(() => steps[activeStepIndex.value] ?? steps[0])
</script>

<template>
  <section id="como-funciona" class="landing-section ligalab-workflow" aria-labelledby="workflow-title">
    <div class="ligalab-section-header">
      <p class="section-index">Como a Plataforma Funciona</p>
      <h2 id="workflow-title">O ciclo completo da sua maratona de ponta a ponta</h2>
      <p class="section-copy">
        Do planejamento prévio à divulgação do ranking final, o Ligalab substitui dezenas de planilhas e formulários desconexos por um fluxo único, fluido e auditável.
      </p>
    </div>

    <!-- Seletor de Fases da Maratona -->
    <div class="workflow-stepper" role="tablist" aria-label="Fases do ciclo de vida da maratona">
      <button
        v-for="(step, idx) in steps"
        :key="step.id"
        type="button"
        role="tab"
        :id="`tab-step-${step.id}`"
        :aria-selected="activeStepIndex === idx"
        :aria-controls="`panel-step-${step.id}`"
        class="workflow-step-btn"
        :class="{ 'workflow-step-btn--active': activeStepIndex === idx }"
        @click="activeStepIndex = idx"
      >
        <span class="workflow-step-num">{{ idx + 1 }}</span>
        <div class="workflow-step-label">
          <span class="workflow-step-phase">{{ step.phase.split('—')[0].trim() }}</span>
          <span class="workflow-step-name">{{ step.title.split('&')[0].trim() }}</span>
        </div>
      </button>
    </div>

    <!-- Painel de Detalhe da Fase Ativa -->
    <div
      :id="`panel-step-${activeStep.id}`"
      role="tabpanel"
      :aria-labelledby="`tab-step-${activeStep.id}`"
      class="workflow-panel"
    >
      <div class="workflow-panel__main">
        <div class="workflow-panel__badge-row">
          <span class="workflow-panel__phase-tag">{{ activeStep.phase }}</span>
          <span class="workflow-panel__icon" aria-hidden="true">{{ activeStep.icon }}</span>
        </div>
        <h3 class="workflow-panel__title">{{ activeStep.title }}</h3>
        <p class="workflow-panel__subtitle">{{ activeStep.subtitle }}</p>
        <p class="workflow-panel__desc">{{ activeStep.description }}</p>

        <div class="workflow-deliverables">
          <h4 class="workflow-deliverables__title">O que a plataforma executa nesta etapa:</h4>
          <ul class="workflow-deliverables__list">
            <li v-for="item in activeStep.deliverables" :key="item" class="workflow-deliverables__item">
              <span class="workflow-deliverables__check" aria-hidden="true">✓</span>
              <span>{{ item }}</span>
            </li>
          </ul>
        </div>
      </div>

      <div class="workflow-panel__telemetry">
        <div class="telemetry-card">
          <div class="telemetry-card__header">
            <span class="telemetry-pulse" />
            <span class="telemetry-card__title">Indicadores de Eficiência</span>
          </div>
          <div class="telemetry-card__metrics">
            <div
              v-for="metric in activeStep.previewMetrics"
              :key="metric.label"
              class="telemetry-metric-tile"
            >
              <span class="telemetry-metric-value">{{ metric.value }}</span>
              <span class="telemetry-metric-label">{{ metric.label }}</span>
            </div>
          </div>
          <div class="telemetry-card__notice">
            <p>As informações ficam organizadas no evento.</p>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
