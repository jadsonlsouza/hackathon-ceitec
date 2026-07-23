import { flushPromises, mount } from '@vue/test-utils'
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

const rpc = vi.fn()

beforeAll(() => {
  vi.stubGlobal('useNuxtApp', () => ({ $supabase: { rpc } }))
})

afterAll(() => vi.unstubAllGlobals())
beforeEach(() => rpc.mockReset())

describe('SubmissionReview', () => {
  it('renders immutable snapshot answers and approves once without feedback', async () => {
    let resolveDecision!: (value: unknown) => void
    rpc.mockReturnValueOnce(new Promise(resolve => { resolveDecision = resolve }))
    const SubmissionReview = (await import('../../app/components/reviews/SubmissionReview.vue')).default
    const wrapper = mount(SubmissionReview, {
      props: {
        submissionId: 'submission-1',
        revision: 2,
        snapshot: { problema: { text: 'Resposta congelada' } },
        blocks: [
          { id: 'block-1', key: 'problema', title: 'Problema', prompt: 'Explique o contexto.', position: 1 },
        ],
      },
    })

    expect(wrapper.text()).toContain('Resposta congelada')
    await wrapper.get('[data-review-decision="approved"]').trigger('click')
    await wrapper.get('[data-review-decision="approved"]').trigger('click')
    await flushPromises()

    expect(rpc).toHaveBeenCalledOnce()
    expect(rpc).toHaveBeenCalledWith('decide_submission', {
      submission_id: 'submission-1',
      decision: 'approved',
      feedback: null,
    })
    expect(wrapper.get('[data-review-decision="approved"]').attributes()).toHaveProperty('disabled')

    resolveDecision({ data: { status: 'approved' }, error: null })
    await flushPromises()
    expect(wrapper.emitted('decided')).toEqual([['approved']])
  })

  it('returns with trimmed optional feedback and never exposes a backend error', async () => {
    rpc.mockResolvedValueOnce({ data: null, error: { message: 'not_active_claimant confidential' } })
    const SubmissionReview = (await import('../../app/components/reviews/SubmissionReview.vue')).default
    const wrapper = mount(SubmissionReview, {
      props: {
        submissionId: 'submission-1',
        revision: 1,
        snapshot: {},
        blocks: [],
      },
    })

    await wrapper.get('textarea').setValue('  Detalhe melhor a validação.  ')
    await wrapper.get('[data-review-decision="returned"]').trigger('click')
    await flushPromises()

    expect(rpc).toHaveBeenCalledWith('decide_submission', {
      submission_id: 'submission-1',
      decision: 'returned',
      feedback: 'Detalhe melhor a validação.',
    })
    expect(wrapper.get('[role="alert"]').text()).toContain('não está mais ativa')
    expect(wrapper.text()).not.toContain('not_active_claimant')
    expect(wrapper.text()).not.toContain('confidential')
  })
})
