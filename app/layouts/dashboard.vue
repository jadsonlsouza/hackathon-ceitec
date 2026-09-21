<script setup lang="ts">
import DashboardNavigation from '../components/dashboard/DashboardNavigation.vue'
import RoleViewSelector from '../components/dashboard/RoleViewSelector.vue'
import NotificationBell from '../components/dashboard/NotificationBell.vue'
import { useNotifications } from '../composables/useNotifications'
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
  activeView,
  availableViews,
  setActiveView,
} = useDashboardEventContext()
const roleViewMessage = useState<string | null>('active-role-view-message', () => null)
const notifications = useNotifications(activeView, currentEventId)
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
        :active-view="activeView"
        :current-event-id="currentEventId"
        :current-path="route.path"
      />
    </aside>
    <div class="dashboard-content">
      <header class="dashboard-layout-header">
        <NotificationBell
          :items="notifications.items.value"
          :pending="notifications.pending.value"
          :error="notifications.error.value"
          :can-compose="notifications.canCompose.value"
          :event-id="activeView?.role === 'professor' ? activeView.eventId : null"
          :mark-read="notifications.markRead"
          :refresh="notifications.refresh"
          :create-manual="notifications.createManual"
        />
        <p v-if="roleViewMessage" class="dashboard-role-view-message" role="status">
          {{ roleViewMessage }}
        </p>
        <RoleViewSelector
          v-if="activeView && availableViews.length > 1"
          :active-view="activeView"
          :available-views="availableViews"
          :set-active-view="setActiveView"
        />
      </header>
      <slot />
    </div>
  </div>
</template>
