const messages: Record<string, string> = {
  forbidden: 'Você não tem permissão para editar o conteúdo deste evento.',
  event_required: 'Não foi possível identificar o evento.',
  invalid_content: 'Revise os textos públicos antes de salvar.',
  invalid_objectives: 'Informe objetivos válidos, sem campos em branco.',
  invalid_schedule: 'Revise os horários e atividades da programação.',
  schedule_days_required: 'Inclua ao menos uma atividade em cada dia.',
  duplicate_schedule_position: 'Use posições únicas em cada dia.',
}

export function publicContentRpcError(error: unknown) {
  const raw = error instanceof Error
    ? error.message
    : typeof error === 'object' && error && 'message' in error
      ? String(error.message)
      : ''
  const key = Object.keys(messages).find(candidate => raw.includes(candidate))
  return key ? messages[key] : 'Não foi possível salvar agora. Tente novamente.'
}
