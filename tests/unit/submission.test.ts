import { describe, expect, it } from 'vitest'
import { canTransition } from '../../shared/domain/submission'

describe('submission transitions', () => {
  it.each([
    ['draft', 'submitted', true],
    ['submitted', 'in_review', true],
    ['in_review', 'approved', true],
    ['in_review', 'returned', true],
    ['returned', 'resubmitted', true],
    ['approved', 'draft', false],
  ] as const)('%s -> %s is %s', (from, to, allowed) => {
    expect(canTransition(from, to)).toBe(allowed)
  })
})
