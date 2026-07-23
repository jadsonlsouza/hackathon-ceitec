<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import {
  capabilitiesForAccess,
  dashboardNavigation,
} from '../../utils/dashboard-navigation'

const props = defineProps<{
  profile: { global_role: 'student' | 'global_admin' } | null
  eventRoles: Array<{
    event_id: string
    role: 'professor' | 'monitor' | 'evaluator'
  }>
  currentEventId: string | null
  teamEventIds: string[]
  currentPath: string
}>()

const navigationRoot = ref<HTMLElement | null>(null)
const menuToggle = ref<HTMLButtonElement | null>(null)
const menuOpen = ref(false)
const capabilities = computed(() => capabilitiesForAccess(
  props.profile,
  props.eventRoles,
  props.currentEventId,
  props.teamEventIds,
))
const links = computed(() => dashboardNavigation(capabilities.value, props.currentEventId))

function isCurrent(to: string) {
  return props.currentPath === to || props.currentPath.startsWith(`${to}/`)
}

async function toggleMenu() {
  menuOpen.value = !menuOpen.value
  if (menuOpen.value) {
    await nextTick()
    navigationRoot.value?.querySelector<HTMLElement>('[data-dashboard-link]')?.focus()
  }
}

async function closeMenu(restoreFocus = false) {
  menuOpen.value = false
  if (restoreFocus) {
    await nextTick()
    menuToggle.value?.focus()
  }
}

function handleKeydown(event: KeyboardEvent) {
  if (event.key !== 'Escape' || !menuOpen.value) return
  event.preventDefault()
  void closeMenu(true)
}
</script>

<template>
  <div
    ref="navigationRoot"
    data-dashboard-navigation
    class="dashboard-navigation"
    @keydown="handleKeydown"
  >
    <button
      ref="menuToggle"
      type="button"
      class="dashboard-menu-toggle"
      data-dashboard-menu-toggle
      aria-controls="dashboard-navigation-list"
      :aria-expanded="menuOpen"
      @click="toggleMenu"
    >
      <span aria-hidden="true">☰</span>
      Menu
    </button>

    <nav aria-label="Navegação do painel">
      <ul
        id="dashboard-navigation-list"
        class="dashboard-nav-list"
        :class="{ 'is-open': menuOpen }"
      >
        <li v-for="link in links" :key="link.to">
          <NuxtLink
            data-dashboard-link
            :to="link.to"
            :aria-current="isCurrent(link.to) ? 'page' : undefined"
            @click="closeMenu()"
          >
            {{ link.label }}
          </NuxtLink>
        </li>
      </ul>
    </nav>

    <p v-if="links.length === 0" class="dashboard-nav-empty">
      Nenhum acesso ativo neste evento.
    </p>
  </div>
</template>
