export interface WeightedCriterion {
  readonly score: number
  readonly weight: number
}

declare const exactWeightedScoreBrand: unique symbol

export type ExactWeightedScore = Readonly<{
  numerator: bigint
  denominator: bigint
  [exactWeightedScoreBrand]: true
}>

const MAX_WEIGHT_CENTS = 99_999_999

interface ScaledDecimal {
  integer: bigint
  scale: number
}

interface Rational {
  numerator: bigint
  denominator: bigint
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

function greatestCommonDivisor(left: bigint, right: bigint): bigint {
  let dividend = left < 0n ? -left : left
  let divisor = right < 0n ? -right : right

  while (divisor !== 0n) {
    const remainder = dividend % divisor
    dividend = divisor
    divisor = remainder
  }

  return dividend
}

function reduceRational(
  numerator: bigint,
  denominator: bigint,
): Rational {
  const divisor = greatestCommonDivisor(numerator, denominator)
  return {
    numerator: numerator / divisor,
    denominator: denominator / divisor,
  }
}

function addRationals(left: Rational, right: Rational): Rational {
  const denominatorDivisor = greatestCommonDivisor(
    left.denominator,
    right.denominator,
  )
  const leftMultiplier = right.denominator / denominatorDivisor
  const rightMultiplier = left.denominator / denominatorDivisor

  return reduceRational(
    left.numerator * leftMultiplier
    + right.numerator * rightMultiplier,
    left.denominator * leftMultiplier,
  )
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

export function weightedScore(
  items: readonly WeightedCriterion[],
): ExactWeightedScore {
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

  const reduced = reduceRational(weightedTotal, totalWeightCents)
  return Object.freeze(reduced) as ExactWeightedScore
}

function isExactWeightedScore(
  score: ExactWeightedScore | number,
): score is ExactWeightedScore {
  return typeof score === 'object'
    && score !== null
    && typeof score.numerator === 'bigint'
    && typeof score.denominator === 'bigint'
}

function isValidExactScore(score: ExactWeightedScore): boolean {
  return score.denominator > 0n
    && score.numerator >= score.denominator
    && score.numerator <= score.denominator * 5n
}

function scoreAsRational(
  score: ExactWeightedScore | number,
): Rational {
  if (isExactWeightedScore(score)) {
    return {
      numerator: score.numerator,
      denominator: score.denominator,
    }
  }

  const decimal = scaledDecimal(score)
  return {
    numerator: decimal.integer,
    denominator: powerOfTen(decimal.scale),
  }
}

export function scoreToNumber(score: ExactWeightedScore): number {
  if (!isValidExactScore(score)) {
    throw new Error('invalid_evaluator_score')
  }
  return Number(score.numerator) / Number(score.denominator)
}

export function finalTeamScore(
  evaluatorScores: readonly (ExactWeightedScore | number)[],
): number {
  if (!evaluatorScores.length) {
    throw new Error('evaluation_required')
  }
  if (evaluatorScores.some(score =>
    isExactWeightedScore(score)
      ? !isValidExactScore(score)
      : !isScore(score),
  )) {
    throw new Error('invalid_evaluator_score')
  }

  const sum = evaluatorScores
    .map(scoreAsRational)
    .reduce(
      addRationals,
      { numerator: 0n, denominator: 1n },
    )
  const average = reduceRational(
    sum.numerator,
    sum.denominator * BigInt(evaluatorScores.length),
  )
  const cents = divideRoundHalfAway(
    average.numerator * 100n,
    average.denominator,
  )
  return Number(cents) / 100
}

export function isDisplayedTie(left: number, right: number): boolean {
  if (!isScore(left) || !isScore(right)) {
    throw new Error('invalid_team_score')
  }

  return round2(left) === round2(right)
}
