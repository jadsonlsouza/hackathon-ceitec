import { describe, expect, it } from 'vitest'
import { loadCurrentAccess } from '../../app/composables/useCurrentAccess'

function queryResult<T>(result: T) {
  const promise = Promise.resolve(result)
  return {
    single: () => promise,
    then: promise.then.bind(promise),
  }
}

describe('loadCurrentAccess', () => {
  it('loads the current profile and all of the user event roles', async () => {
    const profile = {
      id: 'user-1',
      email: 'user@example.test',
      display_name: 'Usuário',
      global_role: 'student',
      created_at: '2026-07-23T00:00:00Z',
      updated_at: '2026-07-23T00:00:00Z',
    }
    const eventRoles = [{
      event_id: 'event-1',
      user_id: 'user-1',
      role: 'monitor',
      categories: [],
      approved_by: 'admin-1',
      approved_at: '2026-07-23T00:00:00Z',
    }]

    const client = {
      from(table: string) {
        return {
          select() {
            return {
              eq() {
                return queryResult(
                  table === 'profiles'
                    ? { data: profile, error: null }
                    : { data: eventRoles, error: null },
                )
              },
            }
          },
        }
      },
    }

    await expect(loadCurrentAccess(client as never, 'user-1')).resolves.toEqual({
      profile,
      eventRoles,
    })
  })

  it('surfaces a profile lookup failure', async () => {
    const expected = new Error('profile unavailable')
    const client = {
      from() {
        return {
          select() {
            return {
              eq() {
                return queryResult({ data: null, error: expected })
              },
            }
          },
        }
      },
    }

    await expect(loadCurrentAccess(client as never, 'user-1')).rejects.toBe(expected)
  })
})
