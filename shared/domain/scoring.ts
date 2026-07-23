export interface WeightedCriterion {
  score: number
  weight: number
}

function round2(value: number): number {
  return Math.round((value + Number.EPSILON) * 100) / 100
}

function isFiniteNumber(value: number): boolean {
  return Number.isFinite(value)
}

function isScore(value: number): boolean {
  return isFiniteNumber(value) && value >= 1 && value <= 5
}

export function weightedScore(items: WeightedCriterion[]): number {
  if (items.some(({ score, weight }) =>
    !isFiniteNumber(score)
    || !Number.isInteger(score)
    || score < 1
    || score > 5
    || !isFiniteNumber(weight)
    || weight < 0,
  )) {
    throw new Error('invalid_score_or_weight')
  }

  const totalWeight = items.reduce((sum, item) => sum + item.weight, 0)
  if (!isFiniteNumber(totalWeight) || totalWeight <= 0) {
    throw new Error('positive_weight_required')
  }

  return items.reduce(
    (sum, item) => sum + item.score * item.weight,
    0,
  ) / totalWeight
}

export function finalTeamScore(evaluatorScores: number[]): number {
  if (!evaluatorScores.length) {
    throw new Error('evaluation_required')
  }
  if (evaluatorScores.some(score => !isScore(score))) {
    throw new Error('invalid_evaluator_score')
  }

  return round2(
    evaluatorScores.reduce((sum, score) => sum + score, 0)
    / evaluatorScores.length,
  )
}

export function isDisplayedTie(left: number, right: number): boolean {
  if (!isScore(left) || !isScore(right)) {
    throw new Error('invalid_team_score')
  }

  return round2(left) === round2(right)
}
