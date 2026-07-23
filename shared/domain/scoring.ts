export interface WeightedCriterion {
  score: number
  weight: number
}

const MAX_WEIGHT_CENTS = 99_999_999

function shiftDecimal(value: number, places: number): number {
  const [coefficient, exponent = '0'] = value.toString().split('e')
  return Number(`${coefficient}e${Number(exponent) + places}`)
}

function round2(value: number): number {
  const shifted = shiftDecimal(Math.abs(value), 2)
  const rounded = Math.sign(value) * Math.round(shifted)
  return shiftDecimal(rounded, -2)
}

function isFiniteNumber(value: number): boolean {
  return Number.isFinite(value)
}

function isScore(value: number): boolean {
  return isFiniteNumber(value) && value >= 1 && value <= 5
}

function weightToCents(weight: number): bigint | null {
  if (!isFiniteNumber(weight) || weight < 0) {
    return null
  }

  const [coefficient, exponentText = '0'] = weight.toString().split('e')
  const fractionLength = coefficient.split('.')[1]?.length ?? 0
  const decimalPlaces = Math.max(
    0,
    fractionLength - Number(exponentText),
  )
  const cents = shiftDecimal(weight, 2)

  if (
    decimalPlaces > 2
    || !Number.isSafeInteger(cents)
    || cents > MAX_WEIGHT_CENTS
  ) {
    return null
  }

  return BigInt(cents)
}

export function weightedScore(items: WeightedCriterion[]): number {
  let totalWeightCents = 0n
  let weightedTotal = 0n

  for (const { score, weight } of items) {
    const weightCents = weightToCents(weight)
    if (
      !Number.isInteger(score)
      || score < 1
      || score > 5
      || weightCents === null
    ) {
      throw new Error('invalid_score_or_weight')
    }

    totalWeightCents += weightCents
    weightedTotal += BigInt(score) * weightCents
  }

  if (totalWeightCents <= 0n) {
    throw new Error('positive_weight_required')
  }

  return Number(weightedTotal) / Number(totalWeightCents)
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
