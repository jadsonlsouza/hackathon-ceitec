import { describe, expect, it } from 'vitest'
import {
  finalTeamScore,
  isDisplayedTie,
  weightedScore,
} from '../../shared/domain/scoring'

describe('weightedScore', () => {
  it('calculates the weighted average for one evaluator', () => {
    expect(weightedScore([
      { score: 5, weight: 2 },
      { score: 3, weight: 1 },
    ])).toBeCloseTo(13 / 3)
  })

  it('accepts zero-weight criteria when another weight is positive', () => {
    expect(weightedScore([
      { score: 1, weight: 0 },
      { score: 5, weight: 1 },
    ])).toBe(5)
  })

  it('preserves numeric(8,2) decimal weights through final rounding', () => {
    expect(finalTeamScore([
      weightedScore([
        { score: 1, weight: 0.03 },
        { score: 2, weight: 0.21 },
      ]),
    ])).toBe(1.88)

    expect(finalTeamScore([
      weightedScore([
        { score: 2, weight: 0.15 },
        { score: 4, weight: 0.01 },
      ]),
    ])).toBe(2.13)
  })

  it('keeps integer weights compatible with decimal arithmetic', () => {
    expect(weightedScore([
      { score: 5, weight: 1 },
      { score: 3, weight: 1 },
    ])).toBe(4)
  })

  it.each([
    [[], 'positive_weight_required'],
    [[{ score: 3, weight: 0 }], 'positive_weight_required'],
    [[{ score: 0, weight: 1 }], 'invalid_score_or_weight'],
    [[{ score: 6, weight: 1 }], 'invalid_score_or_weight'],
    [[{ score: 3.5, weight: 1 }], 'invalid_score_or_weight'],
    [[{ score: 3, weight: -1 }], 'invalid_score_or_weight'],
    [[{ score: Number.NaN, weight: 1 }], 'invalid_score_or_weight'],
    [[{ score: 3, weight: Number.POSITIVE_INFINITY }], 'invalid_score_or_weight'],
    [[{ score: 3, weight: 0.001 }], 'invalid_score_or_weight'],
    [[{ score: 3, weight: 1.234 }], 'invalid_score_or_weight'],
    [[{ score: 3, weight: 1_000_000 }], 'invalid_score_or_weight'],
  ])('rejects invalid input %#', (items, expectedMessage) => {
    expect(() => weightedScore(items as { score: number; weight: number }[]))
      .toThrow(expectedMessage as string)
  })
})

describe('finalTeamScore', () => {
  it('averages evaluators and rounds the displayed result to two decimals', () => {
    expect(finalTeamScore([4.333, 4.667])).toBe(4.5)
    expect(finalTeamScore([4.994, 4.996])).toBe(5)
  })

  it('handles decimal floating-point edges deterministically', () => {
    expect(finalTeamScore([1.005])).toBe(1.01)
    expect(finalTeamScore([2.675])).toBe(2.68)
    expect(finalTeamScore([2.135])).toBe(2.14)
    expect(finalTeamScore([4.015])).toBe(4.02)
  })

  it('requires at least one finite evaluator score', () => {
    expect(() => finalTeamScore([])).toThrow('evaluation_required')
    expect(() => finalTeamScore([Number.NaN])).toThrow('invalid_evaluator_score')
    expect(() => finalTeamScore([Number.POSITIVE_INFINITY]))
      .toThrow('invalid_evaluator_score')
    expect(() => finalTeamScore([0])).toThrow('invalid_evaluator_score')
    expect(() => finalTeamScore([6])).toThrow('invalid_evaluator_score')
  })
})

describe('isDisplayedTie', () => {
  it('treats equal scores rounded to two decimals as a tie', () => {
    expect(isDisplayedTie(4.504, 4.503)).toBe(true)
    expect(isDisplayedTie(4.015, 4.02)).toBe(true)
  })

  it('does not tie scores whose displayed values differ', () => {
    expect(isDisplayedTie(4.504, 4.506)).toBe(false)
  })

  it('rejects non-finite scores', () => {
    expect(() => isDisplayedTie(Number.NaN, 4)).toThrow('invalid_team_score')
    expect(() => isDisplayedTie(0, 4)).toThrow('invalid_team_score')
  })
})
