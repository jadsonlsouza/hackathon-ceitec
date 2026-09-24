import { effectScope, nextTick } from 'vue'
import { useDashboardEventContext } from '../composables/useDashboardEventContext'
import {
  activeRoleViewRequirementForPath,
  shouldRedirectForActiveRoleView,
} from '../utils/active-role-view-guard'

export default defineNuxtRouteMiddleware(async (to) => {
  if (!activeRoleViewRequirementForPath(to.path)) return

  if (import.meta.server) return navigateTo('/app')

  const scope = effectScope()
  try {
    const destinationEventId = typeof to.params.eventId === 'string' ? to.params.eventId : null
    const context = scope.run(() => useDashboardEventContext(destinationEventId))!
    await context.refresh()
    await context.refreshTeamContext()
    await nextTick()
    if (!shouldRedirectForActiveRoleView({
      path: to.path,
      activeView: context.activeView.value,
      isServer: false,
    })) return
  }
  finally {
    scope.stop()
  }

  const message = useState<string | null>('active-role-view-message', () => null)
  message.value = 'Esta tarefa não está disponível na visualização selecionada.'
  return navigateTo('/app')
})
