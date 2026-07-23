import { describe, expect, it } from 'vitest'
import { resultsRpcErrorMessage } from '../../app/utils/results-rpc-error'

describe('result RPC errors', () => {
  it('maps stale tie decisions to an actionable message', () => {
    expect(resultsRpcErrorMessage(
      { message: 'stale_tie_decision' },
      'fallback',
    )).toContain('Revise')
  })

  it('never exposes unknown backend details', () => {
    expect(resultsRpcErrorMessage(
      { message: '<script>internal secret</script>' },
      'Não foi possível publicar.',
    )).toBe('Não foi possível publicar.')
  })
})
