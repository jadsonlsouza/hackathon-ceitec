import { execFileSync } from 'node:child_process'
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createClient, type Session } from '@supabase/supabase-js'
import { localSupabaseEnvironment } from './local-supabase'

export const E2E_PASSWORD = 'Ceitec-E2E-2026!'
export const E2E_EVENT_A = '11111111-1111-4111-8111-111111111111'
export const E2E_EVENT_B = '22222222-2222-4222-8222-222222222222'
export const E2E_ARCHIVED_EVENT = '33333333-3333-4333-8333-333333333333'
export const E2E_TEAM_A = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
export const E2E_TEAM_B = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1'
export const E2E_ACTIVITY_A = 'ca000000-0000-4000-8000-000000000001'
export const E2E_SUBMISSION_B = 'db000000-0000-4000-8000-000000000001'

export const E2E_USERS = {
  admin: ['admin.e2e@ceitec.test', 'Admin Global'],
  professorA: ['professor.a.e2e@ceitec.test', 'Professor A'],
  professorB: ['professor.b.e2e@ceitec.test', 'Professor B'],
  monitor: ['monitor.e2e@ceitec.test', 'Monitor'],
  evaluatorJunior: ['avaliador.junior.e2e@ceitec.test', 'Avaliador Júnior'],
  evaluatorSenior: ['avaliador.senior.e2e@ceitec.test', 'Avaliador Sênior'],
  studentA: ['aluno.a.e2e@ceitec.test', 'Aluno A'],
  studentB: ['aluno.b.e2e@ceitec.test', 'Aluno B'],
  studentA2: ['aluno.a2.e2e@ceitec.test', 'Aluno A2'],
  studentSenior: ['aluno.senior.e2e@ceitec.test', 'Aluno Sênior'],
} as const

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../../..')
const authDir = resolve(root, 'tests/e2e/.auth')

function storageState(session: Session, apiUrl: string) {
  const storageKey = `sb-${new URL(apiUrl).hostname.split('.')[0]}-auth-token`
  return {
    cookies: [],
    origins: [{
      origin: 'http://127.0.0.1:3000',
      localStorage: [{ name: storageKey, value: JSON.stringify(session) }],
    }],
  }
}

export default async function globalSetup() {
  const local = localSupabaseEnvironment()
  execFileSync('npx', ['supabase', 'db', 'reset'], {
    cwd: root,
    stdio: ['ignore', 'ignore', 'inherit'],
  })

  const admin = createClient(local.apiUrl, local.serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  for (const [email, displayName] of Object.values(E2E_USERS)) {
    const { error } = await admin.auth.admin.createUser({
      email,
      password: E2E_PASSWORD,
      email_confirm: true,
      user_metadata: { full_name: displayName },
    })
    if (error) throw error
  }

  const fixtureSql = await readFile(resolve(root, 'tests/e2e/fixtures.sql'), 'utf8')
  execFileSync(
    'docker',
    ['exec', '-i', 'supabase_db_hackathon-ceitec', 'psql', '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres'],
    { input: fixtureSql, stdio: ['pipe', 'ignore', 'inherit'] },
  )

  await mkdir(authDir, { recursive: true })
  const client = createClient(local.apiUrl, local.publishableKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
  for (const [profile, [email]] of Object.entries(E2E_USERS)) {
    const { data, error } = await client.auth.signInWithPassword({
      email,
      password: E2E_PASSWORD,
    })
    if (error || !data.session) throw error ?? new Error(`Sessão ausente para ${profile}`)
    await writeFile(
      resolve(authDir, `${profile}.json`),
      JSON.stringify(storageState(data.session, local.apiUrl)),
      { mode: 0o600 },
    )
    await client.auth.signOut()
  }
}
