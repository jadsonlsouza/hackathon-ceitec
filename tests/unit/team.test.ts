import { describe, expect, it } from 'vitest'
import { canReserveSeat, canSubmitForTeam } from '../../shared/domain/team'

describe('team rules', () => {
  it('counts pending invitations as seats', () => {
    expect(canReserveSeat(5)).toBe(true)
    expect(canReserveSeat(6)).toBe(false)
  })

  it('allows submission only for approved teams', () => {
    expect(canSubmitForTeam('approved')).toBe(true)
    expect(canSubmitForTeam('pending')).toBe(false)
  })
})
