<script setup lang="ts">
const references = [
  {
    author: 'Alexander Osterwalder & Yves Pigneur',
    work: 'Business Model Generation',
    focus: 'Modelagem visual de negócios e proposta de valor aplicada no canvas de ideação.',
  },
  {
    author: 'Eric Ries',
    work: 'A Startup Enxuta',
    focus: 'Ciclo construir-medir-aprender, experimentação rápida e validação contínua de hipóteses.',
  },
  {
    author: 'Steve Blank & Bob Dorf',
    work: 'Startup: Manual do Empreendedor',
    focus: 'Desenvolvimento com foco no cliente, testes de mercado e resolução de dores reais.',
  },
  {
    author: 'Tim Brown',
    work: 'Design Thinking',
    focus: 'Empatia, colaboração multidisciplinar e prototipagem iterativa centrada no ser humano.',
  },
  {
    author: 'Klaus Schwab',
    work: 'A Quarta Revolução Industrial',
    focus: 'Tecnologias emergentes, inteligência artificial e novas competências para o futuro.',
  },
  {
    author: 'MEC / CNE / CES',
    work: 'Resolução nº 7, de 18 de dezembro de 2018',
    focus: 'Diretrizes curriculares para a Extensão na Educação Superior Brasileira.',
  },
]

const expectedOutcomes = [
  'Formação de estudantes protagonistas preparados para atuar como facilitadores e líderes.',
  'Desenvolvimento de soluções tecnológicas para problemas reais da sociedade e mercado.',
  'Fortalecimento da cultura de inovação colaborativa dentro e fora da universidade.',
  'Ampliação da integração entre ensino, pesquisa, extensão e demandas contemporâneas.',
]
</script>

<template>
  <section class="landing-section ligalab-theory" aria-labelledby="theory-title">
    <div class="ligalab-section-header">
      <p class="section-index">Fundamentação Acadêmica & Prática</p>
      <h2 id="theory-title">O rigor da ciência aliado à velocidade das startups</h2>
      <p class="section-copy">
        O Ligalab nasce como iniciativa da Liga de Empreendedorismo e Inovação — um projeto de extensão universitária voltado à formação contínua de estudantes, fundamentado nas principais referências globais de inovação e educação empreendedora.
      </p>
    </div>

    <!-- Grid de referências teóricas -->
    <div class="theory-grid">
      <div
        v-for="ref in references"
        :key="ref.work"
        class="theory-card"
      >
        <span class="theory-card__tag">Referência Teórica</span>
        <h3 class="theory-card__work">{{ ref.work }}</h3>
        <p class="theory-card__author">{{ ref.author }}</p>
        <p class="theory-card__focus">{{ ref.focus }}</p>
      </div>
    </div>

    <!-- Caixa de impacto institucional e resultados esperados -->
    <div class="theory-impact-box">
      <div class="theory-impact-header">
        <span class="theory-impact-badge">Extensão Universitária com Propósito</span>
        <h3>Impacto e Resultados Esperados</h3>
        <p>
          Mais do que um software, o Ligalab é um catalisador de competências socioemocionais (criatividade, liderança, comunicação e trabalho em equipe) que transforma o ecossistema acadêmico.
        </p>
      </div>

      <ul class="theory-outcomes-list">
        <li v-for="outcome in expectedOutcomes" :key="outcome" class="theory-outcome-item">
          <span class="theory-outcome-bullet" aria-hidden="true">✦</span>
          <span>{{ outcome }}</span>
        </li>
      </ul>
    </div>
  </section>
</template>
