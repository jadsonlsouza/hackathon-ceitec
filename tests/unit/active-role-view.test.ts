import { describe, expect, it } from 'vitest'
import {
  availableRoleViewsForAccess,
  resolveActiveRoleView,
} from '../../app/utils/active-role-view'

const EVENT_ID = '10000000-0000-4000-8000-000000000901'

describe('active role views', () => {
  it('lets a global admin narrow to professor but never derives admin from professor', () => {
    const views = availableRoleViewsForAccess({
      globalRole: 'global_admin',
      eventRoles: [],
      teamEventIds: [],
      eventId: EVENT_ID,
    })

    expect(views.map(view => view.role)).toEqual([
      'global_admin',
      'professor',
      'monitor',
      'evaluator',
      'student',
    ])
    expect(availableRoleViewsForAccess({
      globalRole: 'student',
      eventRoles: [{ event_id: EVENT_ID, role: 'professor' }],
      teamEventIds: [],
      eventId: EVENT_ID,
    }).map(view => view.role)).toEqual(['professor'])
  })

  it('falls back after a stored monitor role is revoked', () => {
    expect(resolveActiveRoleView({
      stored: { role: 'monitor', eventId: EVENT_ID },
      available: [{ role: 'student', eventId: EVENT_ID }],
    })).toEqual({ role: 'student', eventId: EVENT_ID })
  })
})
