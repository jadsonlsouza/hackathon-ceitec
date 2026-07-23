export type SubmissionStatus =
  | 'draft'
  | 'submitted'
  | 'in_review'
  | 'returned'
  | 'resubmitted'
  | 'approved'

const transitions: Record<SubmissionStatus, SubmissionStatus[]> = {
  draft: ['submitted'],
  submitted: ['in_review'],
  in_review: ['approved', 'returned'],
  returned: ['resubmitted'],
  resubmitted: ['in_review'],
  approved: [],
}

export const canTransition = (
  from: SubmissionStatus,
  to: SubmissionStatus,
) => transitions[from].includes(to)
