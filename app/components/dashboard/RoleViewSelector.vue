<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import type { ActiveRoleView } from '../../utils/active-role-view'

const props = defineProps<{
  activeView: ActiveRoleView
  availableViews: ActiveRoleView[]
  setActiveView: (view: ActiveRoleView) => boolean
}>()

const roleNames = {
  global_admin: 'Administração',
  professor: 'Professor',
  monitor: 'Monitor',
  evaluator: 'Avaliador',
  student: 'Aluno',
} as const

const trigger = ref<HTMLButtonElement | null>(null)
const listbox = ref<HTMLElement | null>(null)
const open = ref(false)
const selectedIndex = ref(0)
const selectedView = computed(() => props.availableViews[selectedIndex.value] ?? props.activeView)
const selectorLabel = computed(() => {
  const eventContext = props.activeView.eventId ? ' · Evento atual' : ''
  return `${roleNames[props.activeView.role]}${eventContext}`
})

function activeIndex() {
  const index = props.availableViews.findIndex((view) => (
    view.role === props.activeView.role && view.eventId === props.activeView.eventId
  ))
  return index === -1 ? 0 : index
}

async function openListbox() {
  selectedIndex.value = activeIndex()
  open.value = true
  await nextTick()
  listbox.value?.focus()
}

async function dismiss(restoreFocus = false) {
  open.value = false
  if (restoreFocus) {
    await nextTick()
    trigger.value?.focus()
  }
}

function choose(view = selectedView.value) {
  props.setActiveView(view)
  void dismiss(true)
}

function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') {
    event.preventDefault()
    void dismiss(true)
    return
  }
  if (!open.value) return
  if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
    event.preventDefault()
    const direction = event.key === 'ArrowDown' ? 1 : -1
    selectedIndex.value = (selectedIndex.value + direction + props.availableViews.length) % props.availableViews.length
    return
  }
  if (event.key === 'Enter' || event.key === ' ') {
    event.preventDefault()
    choose()
  }
}
</script>

<template>
  <div
    data-role-view-selector
    class="role-view-selector"
    @keydown="handleKeydown"
  >
    <button
      ref="trigger"
      type="button"
      class="role-view-trigger"
      data-role-view-trigger
      aria-controls="role-view-listbox"
      aria-haspopup="listbox"
      :aria-expanded="open"
      @click="open ? dismiss() : openListbox()"
    >
      Visualização: {{ selectorLabel }}
    </button>

    <ul
      v-if="open"
      id="role-view-listbox"
      ref="listbox"
      class="role-view-listbox"
      role="listbox"
      tabindex="-1"
      :aria-activedescendant="`role-view-option-${selectedIndex}`"
    >
      <li
        v-for="(view, index) in availableViews"
        :id="`role-view-option-${index}`"
        :key="`${view.role}:${view.eventId ?? 'global'}`"
        class="role-view-option"
        role="option"
        :aria-selected="view.role === activeView.role && view.eventId === activeView.eventId"
        :class="{ 'is-highlighted': index === selectedIndex }"
        @click="choose(view)"
      >
        {{ roleNames[view.role] }}<span v-if="view.eventId"> · Evento atual</span>
      </li>
    </ul>
  </div>
</template>
