const canvasMessages: Record<string, string> = {
  authentication_required: 'Sua sessão expirou. Entre novamente para continuar.',
  event_not_available: 'Este evento não está mais disponível.',
  forbidden: 'Você não tem permissão para realizar esta ação.',
  submission_not_found: 'Este envio não foi encontrado.',
  submission_not_editable: 'Este envio não pode mais ser editado.',
  team_not_approved: 'A equipe precisa ser aprovada antes do envio.',
  activity_not_published: 'Esta atividade ainda não foi publicada.',
  activity_not_open: 'Esta atividade ainda não está aberta.',
  activity_deadline_passed: 'O prazo desta atividade terminou.',
  submission_not_submittable: 'Este envio não está disponível para submissão.',
  resubmission_not_allowed: 'Esta atividade não permite um novo envio.',
  review_already_claimed: 'Outra pessoa já assumiu esta revisão.',
  submission_not_reviewable: 'Este envio não está disponível para revisão.',
  not_active_claimant: 'Sua atribuição para esta revisão não está mais ativa.',
  review_claim_expired: 'O tempo desta revisão expirou. Assuma o envio novamente.',
  primary_activity_category_conflict: 'Já existe uma atividade principal para uma das categorias escolhidas.',
}

function errorText(error: unknown) {
  if (typeof error === 'string') return error
  if (error && typeof error === 'object' && 'message' in error) return String(error.message)
  return ''
}

export function canvasRpcErrorMessage(
  error: unknown,
  fallback = 'Não foi possível concluir a ação. Tente novamente.',
) {
  const text = errorText(error)
  const code = Object.keys(canvasMessages).find(candidate => text.includes(candidate))
  return code ? canvasMessages[code] : fallback
}
