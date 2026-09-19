<script setup lang="ts">
import DashboardNavigation from '../components/dashboard/DashboardNavigation.vue'
import { useDashboardEventContext } from '../composables/useDashboardEventContext'

const route = useRoute()
const {
  profile,
  eventRoles,
  pending,
  error,
  teamEventIds,
  contextPending,
  contextError,
  currentEventId,
} = useDashboardEventContext()
</script>

<template>
  <div class="dashboard-shell">
    <aside class="dashboard-sidebar">
      <NuxtLink to="/app" class="dashboard-brand" aria-label="Painel ligalab">
        <BrandLogo variant="dark" />
      </NuxtLink>
      <p v-if="pending || contextPending" class="dashboard-access-state">
        Carregando seus acessos…
      </p>
      <p v-else-if="error || contextError" class="dashboard-access-error" role="alert">
        Não foi possível carregar seus acessos.
      </p>
      <DashboardNavigation
        v-else
        :profile="profile"
        :event-roles="eventRoles"
        :current-event-id="currentEventId"
        :team-event-ids="teamEventIds"
        :current-path="route.path"
      />
    </aside>
    <div class="dashboard-content">
      <slot />
    </div>
  </div>
</template>
