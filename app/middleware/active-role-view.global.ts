import { nextTick } from 'vue'
import type { ActiveRole } from '../utils/active-role-view'
import { useDashboardEventContext } from '../composables/useDashboardEventContext'

function requiredRolesForPath(path: string): ActiveRole[] | null {
  if (!path.startsWith('/app/') || path === '/app/') return null
  if (path.startsWith('/app/admin/')) return ['global_admin']
  if (/^\/app\/evento\/[^/]+\/admin\//.test(path)) return ['professor']
  if (/^\/app\/evento\/[^/]+\/revisoes(?:\/|$)/.test(path)) return ['professor', 'monitor']
  if (/^\/app\/evento\/[^/]+\/avaliacao(?:\/|$)/.test(path)) return ['evaluator']
  if (/^\/app\/evento\/[^/]+\/(equipe|atividades|oficinas|presenca)(?:\/|$)/.test(path)) return ['student']
  if (/^\/app\/evento\/[^/]+\/(equipes|solicitacoes)(?:\/|$)/.test(path)) return ['professor']
  return null
}

export default defineNuxtRouteMiddleware(async (to) => {
  if (import.meta.server || !to.path.startsWith('/app')) return

  const requiredRoles = requiredRolesForPath(to.path)
  if (!requiredRoles) return

  const context = useDashboardEventContext()
  await context.refresh()
  await nextTick()

  if (context.activeView.value && requiredRoles.includes(context.activeView.value.role)) return

  const message = useState<string | null>('active-role-view-message', () => null)
  message.value = 'Esta tarefa não está disponível na visualização selecionada.'
  return navigateTo('/app')
})
