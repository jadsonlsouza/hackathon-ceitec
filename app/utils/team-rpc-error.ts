export function teamRpcErrorMessage(
  error: unknown,
  fallback = 'Não foi possível concluir a operação. Tente novamente.',
) {
  const text = error instanceof Error
    ? error.message.toLowerCase()
    : typeof error === 'object' && error && 'message' in error
      ? String(error.message).toLowerCase()
      : ''

  if (text.includes('authentication_required')) return 'Sua sessão expirou. Entre novamente para continuar.'
  if (text.includes('event_not_available')) return 'Este evento não está mais disponível para equipes.'
  if (text.includes('event_required') || text.includes('cross_event_reference') || text.includes('cross_event_move_forbidden')) return 'A ação não corresponde a este evento.'
  if (text.includes('category_required')) return 'Selecione uma categoria para a equipe.'
  if (text.includes('team_name_required')) return 'Informe o nome da equipe.'
  if (text.includes('team_size_out_of_range')) return 'Uma equipe deve ter de 1 a 6 integrantes.'
  if (text.includes('members_array_required') || text.includes('invalid_member')) return 'Revise os dados dos integrantes informados.'
  if (text.includes('profile_required')) return 'Complete seu perfil antes de criar uma equipe.'
  if (text.includes('leader_member_required')) return 'Para criar a equipe, inclua você como primeiro integrante.'
  if (text.includes('member_already_reserved') || text.includes('duplicate') || text.includes('unique')) return 'Este e-mail ou matrícula já está em uso neste evento.'
  if (text.includes('member_required') || text.includes('member_not_found') || text.includes('member_not_invited')) return 'Este convite não está mais disponível.'
  if (text.includes('reserved_email_mismatch')) return 'Este convite foi reservado para outro e-mail.'
  if (text.includes('join_not_pending')) return 'Esta solicitação de entrada não está mais pendente.'
  if (text.includes('team_not_found')) return 'Esta equipe não está mais disponível.'
  if (text.includes('team_not_pending') || text.includes('invalid_decision')) return 'Esta equipe já recebeu uma decisão. Atualize a fila.'
  if (text.includes('forbidden')) return 'Você não tem autorização para realizar esta ação.'
  if (text.includes('team_delete_forbidden') || text.includes('team_member_delete_forbidden') || text.includes('team_leader_must_be_active_member') || text.includes('invalid_operation')) return 'Esta operação não está disponível para a equipe atual.'
  return fallback
}
