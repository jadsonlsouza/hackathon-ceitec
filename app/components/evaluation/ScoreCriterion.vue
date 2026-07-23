<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'

const props = defineProps<{
  criterionId: string
  name: string
  description: string
  modelValue?: number
}>()

const emit = defineEmits<{
  'update:modelValue': [value: number]
}>()

const options = [1, 2, 3, 4, 5] as const
const buttons = ref<Array<HTMLButtonElement | null>>([])
const nameId = computed(() => `criterion-${props.criterionId}-name`)
const descriptionId = computed(
  () => `criterion-${props.criterionId}-description`,
)

function select(value: number, moveFocus = false) {
  emit('update:modelValue', value)
  if (moveFocus) {
    void nextTick(() => buttons.value[value - 1]?.focus())
  }
}

function handleKeydown(event: KeyboardEvent, value: number) {
  let nextValue: number | null = null
  if (event.key === 'ArrowRight' || event.key === 'ArrowDown') {
    nextValue = Math.min(5, value + 1)
  }
  else if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') {
    nextValue = Math.max(1, value - 1)
  }
  else if (event.key === 'Home') {
    nextValue = 1
  }
  else if (event.key === 'End') {
    nextValue = 5
  }

  if (nextValue === null) return
  event.preventDefault()
  select(nextValue, true)
}

function setButtonRef(element: Element | null, index: number) {
  buttons.value[index] = element as HTMLButtonElement | null
}
</script>

<template>
  <fieldset class="score-criterion">
    <legend :id="nameId">{{ name }}</legend>
    <p :id="descriptionId" class="score-description">{{ description }}</p>
    <div
      class="score-options"
      role="radiogroup"
      :aria-labelledby="nameId"
      :aria-describedby="descriptionId"
    >
      <button
        v-for="(value, index) in options"
        :key="value"
        :ref="element => setButtonRef(element, index)"
        type="button"
        role="radio"
        class="score-option"
        :class="{ 'is-selected': modelValue === value }"
        :aria-checked="modelValue === value"
        :aria-label="`${value} de 5`"
        :tabindex="modelValue === value || (!modelValue && value === 1) ? 0 : -1"
        @click="select(value)"
        @keydown="handleKeydown($event, value)"
      >
        {{ value }}
      </button>
    </div>
  </fieldset>
</template>

<style scoped>
.score-criterion {
  border: 1px solid #334155;
  border-radius: .85rem;
  display: grid;
  gap: .75rem;
  margin: 0;
  padding: 1rem;
}

.score-criterion legend {
  font-size: 1.05rem;
  font-weight: 750;
  padding: 0 .35rem;
}

.score-description {
  color: #cbd5e1;
  line-height: 1.5;
  margin: 0;
}

.score-options {
  display: grid;
  gap: .55rem;
  grid-template-columns: repeat(5, minmax(44px, 1fr));
}

.score-option {
  align-items: center;
  background: #0f172a;
  border: 1px solid #64748b;
  border-radius: .6rem;
  color: #f8fafc;
  cursor: pointer;
  display: flex;
  font-weight: 800;
  justify-content: center;
  min-height: 44px;
  min-width: 44px;
}

.score-option.is-selected {
  background: #0284c7;
  border-color: #7dd3fc;
  box-shadow: 0 0 0 2px #38bdf855;
}
</style>
