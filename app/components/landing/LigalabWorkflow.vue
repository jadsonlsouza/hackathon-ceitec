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
    description: 'Configure o evento definindo categorias (Júnior, Universitário, Aberto), trilhas temáticas, formulários customizados de inscrição, pesos de critérios para bancas e limites de integrantes por equipe. O sistema gera automaticamente os links de divulgação e controle de vagas.',
    icon: '⚙️',
    deliverables: [
      'Página pública e links de inscrição prontos',
      'Configuração de rubricas e pesos para jurados',
      'Definição de trilhas (ex: IA, Saúde, Cidades Inteligentes)',
      'Regulamento integrado e termo de consentimento',
    ],
    previewMetrics: [
      { label: 'Tempo médio de setup', value: '15 min' },
      { label: 'Formulários dinâmicos', value: '100% Flexíveis' },
    ],
  },
  {
    id: 'equipes-canvas',
    phase: 'Fase 02 — Durante a Maratona',
    title: 'Formação de Equipes & Canvas Colaborativo',
    subtitle: 'Ambiente estruturado para ideação com salvamento contínuo',
    description: 'Os participantes credenciam-se pelo e-mail ou Google OAuth, montam equipes por link de convite e trabalham diretamente no Canvas de Ideação. Cada bloco (Problema, Validação, Proposta de Valor, Viabilidade e Pitch) conta com salvamento em tempo real, eliminando qualquer risco de perda de conteúdo.',
    icon: '🧩',
    deliverables: [
      'Formação rápida de equipes com liderança definida',
      'Canvas em tempo real com autosave instantâneo',
      'Acompanhamento de entregáveis por marcos temporais',
      'Histórico seguro de edições e versões da solução',
    ],
    previewMetrics: [
      { label: 'Autosave', value: 'Em tempo real' },
      { label: 'Risco de perda', value: '0%' },
    ],
  },
  {
    id: 'mentoria',
    phase: 'Fase 03 — Aceleração das Ideias',
    title: 'Fila Inteligente de Mentoria & Suporte',
    subtitle: 'Helpdesk organizado para mentores e facilitadores',
    description: 'Acabe com o caos de equipes levantando a mão ou mentores vagando sem saber quem precisa de auxílio. Os times solicitam mentoria selecionando a área (Tecnologia, Negócios, Design, Pitch) e o sistema organiza a fila em tempo real, registrando anotações e feedback de cada atendimento.',
    icon: '💡',
    deliverables: [
      'Chamados categorizados por especialidade do mentor',
      'Fila transparente com status: Aguardando / Em Atendimento',
      'Registro de checkpoints e recomendações aos alunos',
      'Métricas de tempo de resposta para a coordenação',
    ],
    previewMetrics: [
      { label: 'Gargalos físicos', value: 'Zero filas' },
      { label: 'Histórico de mentorias', value: 'Auditado' },
    ],
  },
  {
    id: 'bancas-placar',
    phase: 'Fase 04 — O Grande Final',
    title: 'Bancas Julgadoras & Placar Instantâneo',
    subtitle: 'Avaliação sem planilhas e com desempate transparente',
    description: 'Durante as apresentações (pitches), os jurados acessam sua tela protegida para atribuir notas critério a critério. O Ligalab calcula as médias ponderadas automaticamente, aplica os critérios de desempate pré-definidos no regulamento e permite publicar o placar final oficial com um único clique.',
    icon: '🏆',
    deliverables: [
      'Interface limpa de pontuação para bancas avaliadoras',
      'Cálculo de médias ponderadas sem risco de erro humano',
      'Algoritmo de desempate auditável conforme o edital',
      'Publicação imediata do placar e vitrine pública de projetos',
    ],
    previewMetrics: [
      { label: 'Erros de cálculo', value: 'Zero' },
      { label: 'Publicação do ranking', value: '1 clique' },
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
            <p>Acompanhamento automatizado em tempo real por organizadores e participantes.</p>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
