import { describe, expect, it } from 'vitest'
import { canApproveRequest } from '../../shared/domain/access'

describe('canApproveRequest', () => {
  it('allows global admin to approve professors', () => {
    expect(canApproveRequest('global_admin', null, 'professor')).toBe(true)
  })

  it('allows professor to approve monitor and evaluator only', () => {
    expect(canApproveRequest('student', 'professor', 'monitor')).toBe(true)
    expect(canApproveRequest('student', 'professor', 'professor')).toBe(false)
  })
})
