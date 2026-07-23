<script setup lang="ts">
import { computed, ref } from 'vue'
import { canvasRpcErrorMessage } from '../../utils/canvas-rpc-error'

interface ReviewBlock {
  id: string
  key: string
  title: string
  prompt: string
  position: number
}

const props = defineProps<{
  submissionId: string
  revision: number
  snapshot: Record<string, unknown>
  blocks: ReviewBlock[]
}>()

const emit = defineEmits<{ decided: [decision: 'approved' | 'returned'] }>()
const { $supabase } = useNuxtApp()
const feedback = ref('')
const processing = ref(false)
const decisionError = ref<string | null>(null)

const answers = computed(() => (
  [...props.blocks]
    .sort((a, b) => a.position - b.position)
    .map(block => ({
      ...block,
      content: props.snapshot[block.key],
    }))
))

function answerText(content: unknown) {
  if (content && typeof content === 'object' && 'text' in content) {
    return String(content.text ?? '')
  }
  if (typeof content === 'string') return content
  return content == null ? '' : JSON.stringify(content)
}

async function decide(decision: 'approved' | 'returned') {
  if (processing.value) return
  processing.value = true
  decisionError.value = null
  try {
    const { error } = await $supabase.rpc('decide_submission', {
      submission_id: props.submissionId,
      decision,
      feedback: feedback.value.trim() || null,
    })
    if (error) {
      decisionError.value = canvasRpcErrorMessage(error, 'Não foi possível registrar a revisão. Tente novamente.')
      return
    }
    emit('decided', decision)
  }
  catch (error: unknown) {
    decisionError.value = canvasRpcErrorMessage(error, 'Não foi possível registrar a revisão. Tente novamente.')
  }
  finally {
    processing.value = false
  }
}
</script>

<template>
  <section class="submission-review" aria-labelledby="review-revision-title">
    <header>
      <p class="eyebrow">Revisão imutável</p>
      <h2 id="review-revision-title">Revisão {{ revision }}</h2>
      <p class="field-help">As respostas abaixo são a versão registrada no momento do envio.</p>
    </header>

    <p v-if="answers.length === 0" class="request-status">Esta revisão não possui respostas registradas.</p>
    <article v-for="answer in answers" :key="answer.id" class="snapshot-answer">
      <h3>{{ answer.title }}</h3>
      <p v-if="answer.prompt" class="field-help">{{ answer.prompt }}</p>
      <p>{{ answerText(answer.content) || 'Sem resposta.' }}</p>
    </article>

    <label :for="`review-feedback-${submissionId}`">Feedback (opcional)</label>
    <textarea
      :id="`review-feedback-${submissionId}`"
      v-model="feedback"
      rows="4"
      :disabled="processing"
      placeholder="Escreva uma orientação para a equipe, se necessário."
    />
    <p v-if="decisionError" class="form-error" role="alert">{{ decisionError }}</p>
    <div class="request-actions">
      <button
        type="button"
        data-review-decision="approved"
        :disabled="processing"
        @click="decide('approved')"
      >
        {{ processing ? 'Processando…' : 'Aprovar sem exigir feedback' }}
      </button>
      <button
        type="button"
        class="danger-button"
        data-review-decision="returned"
        :disabled="processing"
        @click="decide('returned')"
      >
        Devolver para ajustes
      </button>
    </div>
  </section>
</template>
