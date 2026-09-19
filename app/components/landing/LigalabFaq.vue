<script setup lang="ts">
import { ref } from 'vue'

interface FaqItem {
  question: string
  answer: string
}

const faqs: FaqItem[] = [
  {
    question: 'O que é o Ligalab?',
    answer: 'O Ligalab é a plataforma de gestão de hackathons e maratonas de inovação criada pela Liga de Empreendedorismo e Inovação. O sistema automatiza todas as etapas do evento: credenciamento, formação de equipes, ideação estruturada em canvas, fila de mentoria em tempo real, avaliação de bancas e publicação auditada de resultados.',
  },
  {
    question: 'O que é a Liga de Empreendedorismo e Inovação?',
    answer: 'É um projeto permanente de extensão universitária dedicado a capacitar estudantes para atuarem como líderes, facilitadores e multiplicadores da cultura de inovação. A Liga utiliza metodologias ativas e o Framework FORMA para apoiar eventos, desafios e aproximar a universidade da sociedade.',
  },
  {
    question: 'Como o Framework FORMA funciona dentro da plataforma?',
    answer: 'O Framework FORMA (Formar, Organizar, Realizar, Multiplicar, Apoiar) orienta os módulos da ferramenta: na etapa Formar, a plataforma gerencia trilhas e oficinas; em Organizar, calibra cronogramas e bancas; em Realizar, viabiliza o canvas com autosave e a mentoria; em Multiplicar, divulga o placar público de resultados; e em Apoiar, fornece governança e auditoria completas.',
  },
  {
    question: 'Como posso explorar ou me inscrever nos eventos disponíveis?',
    answer: 'Você pode acessar o catálogo público de eventos pelo botão "Explorar eventos" ou pelo menu superior na rota /eventos. Lá você encontrará os desafios abertos, detalhes de cronograma, categorias e o formulário de cadastro de equipes.',
  },
  {
    question: 'Como os jurados avaliam as equipes no Ligalab?',
    answer: 'Os avaliadores acessam uma interface focada que apresenta os critérios com pesos pré-definidos pelos organizadores. As notas são registradas em tempo real com algoritmo de desempate automático e controle de concorrência, eliminando a necessidade de planilhas manuais propensas a erros.',
  },
]

const openIndexes = ref<number[]>([0])

function toggleFaq(index: number) {
  if (openIndexes.value.includes(index)) {
    openIndexes.value = openIndexes.value.filter(i => i !== index)
  } else {
    openIndexes.value.push(index)
  }
}

function isOpen(index: number): boolean {
  return openIndexes.value.includes(index)
}
</script>

<template>
  <section class="landing-section ligalab-faq" aria-labelledby="faq-title">
    <div class="ligalab-section-header">
      <p class="section-index">Tire suas dúvidas</p>
      <h2 id="faq-title">Perguntas frequentes sobre o Ligalab</h2>
      <p class="section-copy">
        Conheça mais sobre como a plataforma funciona, a metodologia aplicada e como participar das próximas maratonas.
      </p>
    </div>

    <div class="faq-list">
      <article
        v-for="(item, idx) in faqs"
        :key="item.question"
        class="faq-item"
        :class="{ 'faq-item--open': isOpen(idx) }"
      >
        <h3>
          <button
            type="button"
            class="faq-question-btn"
            :id="`faq-btn-${idx}`"
            :aria-expanded="isOpen(idx)"
            :aria-controls="`faq-answer-${idx}`"
            @click="toggleFaq(idx)"
          >
            <span>{{ item.question }}</span>
            <span class="faq-chevron" aria-hidden="true">{{ isOpen(idx) ? '−' : '+' }}</span>
          </button>
        </h3>
        <div
          v-show="isOpen(idx)"
          :id="`faq-answer-${idx}`"
          role="region"
          :aria-labelledby="`faq-btn-${idx}`"
          class="faq-answer-panel"
        >
          <p>{{ item.answer }}</p>
        </div>
      </article>
    </div>
  </section>
</template>
