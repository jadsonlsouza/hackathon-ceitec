export interface WeightedCriterion {
  score: number
  weight: number
}

const MAX_WEIGHT_CENTS = 99_999_999

interface ScaledDecimal {
  integer: bigint
  scale: number
}

function powerOfTen(exponent: number): bigint {
  return 10n ** BigInt(exponent)
}

function scaledDecimal(value: number): ScaledDecimal {
  const [coefficient, exponentText = '0'] = value.toString().split('e')
  const negative = coefficient.startsWith('-')
  const unsigned = negative ? coefficient.slice(1) : coefficient
  const [whole, fraction = ''] = unsigned.split('.')
  let integer = BigInt(`${whole}${fraction}`)
  let scale = fraction.length - Number(exponentText)

  if (scale < 0) {
    integer *= powerOfTen(-scale)
    scale = 0
  }

  while (scale > 0 && integer % 10n === 0n) {
    integer /= 10n
    scale -= 1
  }

  return {
    integer: negative ? -integer : integer,
    scale,
  }
}

function divideRoundHalfAway(
  numerator: bigint,
  denominator: bigint,
): bigint {
  const negative = numerator < 0n
  const magnitude = negative ? -numerator : numerator
  const quotient = magnitude / denominator
  const remainder = magnitude % denominator
  const rounded = quotient + (remainder * 2n >= denominator ? 1n : 0n)
  return negative ? -rounded : rounded
}

function round2(value: number): number {
  const decimal = scaledDecimal(value)
  const cents = divideRoundHalfAway(
    decimal.integer * 100n,
    powerOfTen(decimal.scale),
  )
  return Number(cents) / 100
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

  const decimal = scaledDecimal(weight)
  if (decimal.scale > 2) {
    return null
  }

  const cents = decimal.integer * powerOfTen(2 - decimal.scale)
  if (cents > BigInt(MAX_WEIGHT_CENTS)) {
    return null
  }

  return cents
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

  const decimals = evaluatorScores.map(scaledDecimal)
  const commonScale = Math.max(...decimals.map(decimal => decimal.scale))
  const sum = decimals.reduce(
    (total, decimal) =>
      total
      + decimal.integer * powerOfTen(commonScale - decimal.scale),
    0n,
  )
  const denominator
    = powerOfTen(commonScale) * BigInt(evaluatorScores.length)
  const cents = divideRoundHalfAway(
    sum * 100n,
    denominator,
  )
  return Number(cents) / 100
}

export function isDisplayedTie(left: number, right: number): boolean {
  if (!isScore(left) || !isScore(right)) {
    throw new Error('invalid_team_score')
  }

  return round2(left) === round2(right)
}
