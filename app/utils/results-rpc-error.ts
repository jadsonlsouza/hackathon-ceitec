function backendMessage(error: unknown): string {
  if (!error || typeof error !== 'object' || !('message' in error)) return ''
  return String((error as { message?: unknown }).message ?? '')
}

const messages: Array<[string, string]> = [
  ['authentication_required', 'Entre novamente para continuar.'],
  ['forbidden', 'Somente o Professor responsável pode realizar esta ação.'],
  ['event_not_available', 'Este evento não está mais disponível.'],
  ['event_not_in_evaluation', 'Os resultados só podem ser concluídos na fase de avaliação.'],
  ['evaluations_incomplete', 'Todas as equipes precisam receber as avaliações previstas.'],
  ['unresolved_ties', 'Resolva todos os empates antes de publicar.'],
  ['stale_tie_decision', 'As avaliações mudaram. Revise e registre novamente o desempate.'],
  ['invalid_tie_order', 'A ordem deve incluir cada equipe empatada uma única vez.'],
  ['justification_required', 'Informe a justificativa do desempate.'],
  ['tie_already_resolved', 'Este empate já possui uma decisão registrada.'],
  ['category_already_published', 'Esta categoria já foi publicada.'],
  ['evaluation_not_frozen', 'Congele a avaliação desta categoria antes de publicar.'],
]

export function resultsRpcErrorMessage(
  error: unknown,
  fallback: string,
): string {
  const raw = backendMessage(error)
  return messages.find(([token]) => raw.includes(token))?.[1] ?? fallback
}
