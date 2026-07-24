import { execFileSync } from 'node:child_process'

export interface LocalSupabaseEnvironment {
  apiUrl: string
  dbUrl: string
  publishableKey: string
  serviceRoleKey: string
}

function parseEnv(output: string) {
  return Object.fromEntries(
    output
      .split(/\r?\n/)
      .map(line => line.match(/^([A-Z_]+)="(.*)"$/))
      .filter((match): match is RegExpMatchArray => Boolean(match))
      .map(match => [match[1], match[2]]),
  )
}

export function localSupabaseEnvironment(): LocalSupabaseEnvironment {
  let output = ''
  try {
    output = execFileSync('npx', ['supabase', 'status', '-o', 'env'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    })
  }
  catch {
    // A fully stopped local stack returns exit 1 and no environment.
  }
  let values = parseEnv(output)

  if (!values.API_URL || !values.SERVICE_ROLE_KEY) {
    // A database container may survive a partially stopped local stack. The
    // CLI reports that state as "already running", so normalize it first.
    execFileSync('npx', ['supabase', 'stop'], {
      stdio: ['ignore', 'ignore', 'inherit'],
    })
    execFileSync('npx', [
      'supabase',
      'start',
      '--exclude',
      'edge-runtime,imgproxy,logflare,mailpit,postgres-meta,storage-api,studio,supavisor,vector',
    ], {
      stdio: ['ignore', 'ignore', 'inherit'],
    })
    output = execFileSync('npx', ['supabase', 'status', '-o', 'env'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    })
    values = parseEnv(output)
  }

  const apiUrl = values.API_URL
  const dbUrl = values.DB_URL
  const publishableKey = values.PUBLISHABLE_KEY || values.ANON_KEY
  const serviceRoleKey = values.SERVICE_ROLE_KEY
  if (!apiUrl || !dbUrl || !publishableKey || !serviceRoleKey) {
    throw new Error('O Supabase local não forneceu todas as credenciais de teste.')
  }

  return { apiUrl, dbUrl, publishableKey, serviceRoleKey }
}
