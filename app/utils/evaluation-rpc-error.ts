function backendMessage(error: unknown): string {
  if (!error || typeof error !== 'object' || !('message' in error)) return ''
  return String((error as { message?: unknown }).message ?? '')
}

const messages: Array<[string, string]> = [
  ['authentication_required', 'Entre novamente para continuar.'],
  ['forbidden', 'Somente o Professor responsável pode realizar esta ação.'],
  ['event_not_available', 'Este evento não está mais disponível.'],
  ['event_not_in_evaluation', 'Esta ação só está disponível na fase de avaliação.'],
  ['approved_team_required', 'É necessária pelo menos uma equipe aprovada nesta categoria.'],
  ['evaluation_already_started', 'A ordem não pode mudar porque as avaliações já começaram.'],
  ['category_results_published', 'Os resultados desta categoria já foram publicados.'],
  ['evaluation_config_frozen', 'A configuração já foi congelada para esta categoria.'],
  ['evaluation_already_frozen', 'A configuração já foi congelada para esta categoria.'],
  ['criterion_required', 'Cadastre pelo menos um critério ativo.'],
  ['positive_weight_required', 'Defina pelo menos um peso maior que zero.'],
  ['evaluator_required', 'Designe pelo menos um Avaliador para esta categoria.'],
  ['evaluator_role_required', 'O perfil de Avaliador não está ativo neste evento.'],
  ['evaluator_participant_conflict', 'Um Avaliador não pode integrar equipe da mesma categoria.'],
  ['evaluation_not_frozen', 'Congele a configuração antes de avaliar.'],
  ['not_assigned_to_category', 'Você não está designado para esta categoria.'],
  ['team_not_eligible', 'Esta equipe não faz parte da configuração congelada.'],
  ['incomplete_scores', 'Informe uma nota para todos os critérios.'],
  ['invalid_score', 'As notas devem ser números inteiros de 1 a 5.'],
  ['comment_too_long', 'O comentário deve ter no máximo 4.000 caracteres.'],
]

export function evaluationRpcErrorMessage(
  error: unknown,
  fallback: string,
): string {
  const raw = backendMessage(error)
  return messages.find(([token]) => raw.includes(token))?.[1] ?? fallback
}
