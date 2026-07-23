import { describe, expect, it } from 'vitest'
import { evaluationRpcErrorMessage } from '../../app/utils/evaluation-rpc-error'

describe('evaluation RPC error messages', () => {
  it('explains that a published category can no longer be edited', () => {
    expect(evaluationRpcErrorMessage(
      { message: 'category_results_published' },
      'fallback',
    )).toContain('já foram publicados')
  })
  it.each([
    ['authentication_required', 'Entre novamente'],
    ['forbidden', 'Professor responsável'],
    ['event_not_available', 'evento não está mais disponível'],
    ['event_not_in_evaluation', 'fase de avaliação'],
    ['approved_team_required', 'equipe aprovada'],
    ['evaluation_already_started', 'avaliações já começaram'],
    ['evaluation_config_frozen', 'configuração já foi congelada'],
    ['incomplete_scores', 'nota para todos os critérios'],
    ['evaluator_role_required', 'perfil de Avaliador não está ativo'],
  ])('maps %s without exposing the backend token', (backend, expected) => {
    const message = evaluationRpcErrorMessage(
      { message: backend },
      'Não foi possível concluir.',
    )
    expect(message).toContain(expected)
    expect(message).not.toContain(backend)
  })

  it('uses the safe fallback for unknown database details', () => {
    expect(evaluationRpcErrorMessage(
      { message: 'duplicate key secret detail' },
      'Não foi possível concluir.',
    )).toBe('Não foi possível concluir.')
  })
})
