<script setup lang="ts">
import { ref } from 'vue'

interface FormaStep {
  letter: string
  name: string
  badge: string
  title: string
  description: string
  tools: string[]
}

const steps: FormaStep[] = [
  {
    letter: 'F',
    name: 'Formar',
    badge: 'Etapa 01 — Capacitação Contínua',
    title: 'Desenvolvimento de competências técnicas, comportamentais e de IA',
    description: 'Capacitação contínua dos estudantes por meio de oficinas, bootcamps e mentorias. Foco no desenvolvimento prático de habilidades em inteligência artificial, metodologias ágeis, liderança criativa e facilitação de grupos para preparar agentes multiplicadores.',
    tools: ['Trilhas de Capacitação & Oficinas', 'Módulos de IA & Prototipagem', 'Workshops Temáticos Simultâneos'],
  },
  {
    letter: 'O',
    name: 'Organizar',
    badge: 'Etapa 02 — Estruturação & Governança',
    title: 'Planejamento ágil de equipes, cronogramas e critérios de avaliação',
    description: 'Planejamento e estruturação sistemática das maratonas. Definição de objetivos claros, divisão de categorias (Júnior, Sênior e Universitário), parametrização de critérios de bancas e convite centralizado de equipes para garantir eventos sem atrito.',
    tools: ['Gestão de Categorias e Equipes', 'Cronograma com Alertas de Fase', 'Calibração de Rubricas Julgadoras'],
  },
  {
    letter: 'R',
    name: 'Realizar',
    badge: 'Etapa 03 — Execução da Maratona',
    title: 'Imersão prática com canvas colaborativo e acompanhamento ao vivo',
    description: 'A maratona em pleno funcionamento. As equipes constroem suas soluções guiadas por blocos estruturados de ideação com autosave contínuo, controle de presença integrado e apoio imediato através da fila de mentoria.',
    tools: ['Canvas de Ideação Guiada (5W2H/Lean)', 'Salvamento em Tempo Real sem Perda', 'Fila Dinâmica de Mentoria & Helpdesk'],
  },
  {
    letter: 'M',
    name: 'Multiplicar',
    badge: 'Etapa 04 — Disseminação & Impacto',
    title: 'Vitrine pública de soluções, rankings auditados e novos líderes',
    description: 'Disseminação da cultura de inovação dentro e fora da universidade. Os projetos desenvolvidos ganham visibilidade em páginas públicas de resultados com notas auditadas, preparando estudantes para atuarem como futuros facilitadores.',
    tools: ['Placar de Resultados Transparente', 'Vitrine Pública de Projetos', 'Histórico e Certificação de Participação'],
  },
  {
    letter: 'A',
    name: 'Apoiar',
    badge: 'Etapa 05 — Suporte & Extensão',
    title: 'Conexão institucional contínua entre academia, sociedade e mercado',
    description: 'Suporte metodológico, técnico e operacional a iniciativas extensionistas e desafios reais. Os integrantes atuam como monitores e parceiros estratégicos de organizações públicas e privadas, garantindo impacto comunitário sustentável.',
    tools: ['Auditoria e Governança de Eventos', 'Integração Curricular de Extensão', 'Ponte com Demandas Reais da Sociedade'],
  },
]

const activeIndex = ref(0)
</script>

<template>
  <section id="metodologia-forma" class="landing-section ligalab-forma" aria-labelledby="forma-title">
    <div class="ligalab-section-header">
      <p class="section-index">Metodologia Exclusiva</p>
      <h2 id="forma-title">O Framework FORMA: A inteligência metodológica do Ligalab</h2>
      <p class="section-copy">
        Nascido na Liga de Empreendedorismo e Inovação, o Framework FORMA é um modelo cíclico de aprendizagem ativa que transforma o aprendizado teórico em competências práticas e soluções de alto impacto.
      </p>
    </div>

    <!-- Seletor interativo dos pilares -->
    <div class="forma-nav" role="tablist" aria-label="Etapas do Framework FORMA">
      <button
        v-for="(step, idx) in steps"
        :key="step.letter"
        type="button"
        role="tab"
        :id="`tab-forma-${step.letter}`"
        :aria-selected="activeIndex === idx"
        :aria-controls="`panel-forma-${step.letter}`"
        class="forma-tab"
        :class="{ 'forma-tab--active': activeIndex === idx }"
        @click="activeIndex = idx"
      >
        <span class="forma-tab__letter">{{ step.letter }}</span>
        <span class="forma-tab__name">{{ step.name }}</span>
      </button>
    </div>

    <!-- Painel de detalhe do pilar ativo -->
    <div
      v-if="steps[activeIndex]"
      :id="`panel-forma-${steps[activeIndex].letter}`"
      role="tabpanel"
      :aria-labelledby="`tab-forma-${steps[activeIndex].letter}`"
      class="forma-card"
    >
      <div class="forma-card__header">
        <span class="forma-card__badge">{{ steps[activeIndex].badge }}</span>
        <h3 class="forma-card__title">{{ steps[activeIndex].title }}</h3>
      </div>
      <p class="forma-card__desc">{{ steps[activeIndex].description }}</p>

      <div class="forma-card__tools">
        <h4 class="forma-tools-title">Recursos do Ligalab nesta etapa:</h4>
        <ul class="forma-tools-list">
          <li v-for="tool in steps[activeIndex].tools" :key="tool" class="forma-tool-item">
            <span class="forma-tool-icon" aria-hidden="true">✓</span>
            <span>{{ tool }}</span>
          </li>
        </ul>
      </div>
    </div>
  </section>
</template>
