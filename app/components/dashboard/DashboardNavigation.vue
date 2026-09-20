<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import { navigationForActiveView } from '../../utils/dashboard-navigation'
import type { ActiveRoleView } from '../../utils/active-role-view'
import { useAuth } from '../../composables/useAuth'

const props = defineProps<{
  activeView: ActiveRoleView | null
  currentEventId: string | null
  currentPath: string
}>()

const navigationRoot = ref<HTMLElement | null>(null)
const menuToggle = ref<HTMLButtonElement | null>(null)
const menuOpen = ref(false)
const links = computed(() => navigationForActiveView(props.activeView, props.currentEventId))

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

const { signOut } = useAuth()
async function handleLogout() {
  await signOut()
  await navigateTo('/login')
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
      Nenhuma tarefa disponível nesta visualização.
    </p>

    <div class="dashboard-nav-footer">
      <button
        type="button"
        class="dashboard-logout-btn"
        @click="handleLogout"
      >
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
          <polyline points="16 17 21 12 16 7"/>
          <line x1="21" y1="12" x2="9" y2="12"/>
        </svg>
        Sair
      </button>
    </div>
  </div>
</template>
