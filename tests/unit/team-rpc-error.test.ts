import { describe, expect, it } from 'vitest'
import { teamRpcErrorMessage } from '../../app/utils/team-rpc-error'

describe('team RPC error messages', () => {
  it.each([
    ['event_not_available', 'não está mais disponível'],
    ['leader_member_required', 'inclua você como primeiro integrante'],
    ['member_already_reserved', 'e-mail ou matrícula já está em uso'],
    ['team_size_out_of_range', 'de 1 a 6 integrantes'],
    ['member_not_invited', 'convite não está mais disponível'],
    ['join_not_pending', 'não está mais pendente'],
    ['team_not_pending', 'equipe já recebeu uma decisão'],
    ['forbidden', 'não tem autorização'],
  ])('maps %s to actionable Portuguese copy', (code, expected) => {
    expect(teamRpcErrorMessage({ message: code })).toContain(expected)
  })

  it('does not disclose an unknown backend message', () => {
    const message = teamRpcErrorMessage({ message: 'internal postgres detail' })

    expect(message).not.toContain('internal postgres detail')
  })
})
