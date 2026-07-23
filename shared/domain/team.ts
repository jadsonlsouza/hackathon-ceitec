export type TeamCategory = 'junior' | 'senior'
export type TeamStatus = 'pending' | 'approved' | 'rejected'
export type MemberStatus =
  | 'invited'
  | 'join_requested'
  | 'active'
  | 'rejected'
  | 'removed'

export const canReserveSeat = (reservedSeats: number) => reservedSeats < 6

export const canSubmitForTeam = (status: TeamStatus) => status === 'approved'
