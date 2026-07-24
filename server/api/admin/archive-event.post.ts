import { createHash, timingSafeEqual } from 'node:crypto'
import {
  createError,
  defineEventHandler,
  getHeader,
  readBody,
} from 'h3'
import { z } from 'zod'
import { createSupabaseAdminClient } from '../../utils/supabase-admin'

const MAX_AUTH_AGE_SECONDS = 10 * 60
const MAX_CLOCK_SKEW_SECONDS = 60

const ArchiveBody = z.object({
  eventId: z.string().uuid(),
  eventName: z.string().min(1),
  archiveSecret: z.string().min(12),
  copyConfig: z.boolean().optional().default(false),
})

interface ArchiveRpcRow {
  archived_event_id: string
  new_event_id: string
}

interface ArchiveAdminClient {
  auth: {
    getUser: (token: string) => Promise<{
      data: { user: { id: string } | null }
      error: unknown
    }>
  }
  from: (table: 'profiles') => {
    select: (columns: string) => {
      eq: (column: string, value: string) => {
        single: () => Promise<{
          data: { global_role?: string } | null
          error: unknown
        }>
      }
    }
  }
  rpc: (
    name: 'archive_and_create_event',
    args: {
      target_event: string
      confirmed_name: string
      actor: string
      copy_config: boolean
    },
  ) => Promise<{
    data: ArchiveRpcRow[] | null
    error: { message: string, code?: string } | null
  }>
}

export interface ArchiveRequest {
  authorization?: string
  body: unknown
  nowSeconds?: number
}

export interface ArchiveDependencies {
  admin: ArchiveAdminClient
  archiveSecret: string
}

function unauthorized() {
  return createError({
    statusCode: 401,
    message: 'Autenticação recente necessária',
  })
}

function bearerToken(authorization?: string) {
  const match = authorization?.match(/^Bearer ([^\s]+)$/)
  if (!match) throw unauthorized()
  return match[1]
}

function recentAuthenticationTimeFromVerifiedToken(token: string) {
  try {
    const segments = token.split('.')
    if (segments.length !== 3) throw new Error('invalid token')
    const payload = JSON.parse(
      Buffer.from(segments[1], 'base64url').toString('utf8'),
    ) as {
      auth_time?: unknown
      amr?: unknown
    }

    if (payload.auth_time !== undefined) {
      if (
        typeof payload.auth_time !== 'number'
        || !Number.isInteger(payload.auth_time)
      ) {
        throw new Error('invalid auth_time')
      }
      return payload.auth_time
    }

    if (!Array.isArray(payload.amr)) throw new Error('amr missing')

    const authenticationTimes = payload.amr.flatMap((entry: unknown) => {
      if (!entry || typeof entry !== 'object') return []
      const { method, timestamp } = entry as {
        method?: unknown
        timestamp?: unknown
      }
      if (
        typeof method !== 'string'
        || method === 'token_refresh'
        || method === 'anonymous'
        || method === 'email_change'
        || typeof timestamp !== 'number'
        || !Number.isInteger(timestamp)
      ) {
        return []
      }
      return [timestamp]
    })

    if (authenticationTimes.length === 0) {
      throw new Error('recent authentication method missing')
    }

    return Math.max(...authenticationTimes)
  }
  catch {
    throw unauthorized()
  }
}

function secretsMatch(provided: string, expected: string) {
  const providedDigest = createHash('sha256').update(provided).digest()
  const expectedDigest = createHash('sha256').update(expected).digest()
  return timingSafeEqual(providedDigest, expectedDigest)
}

function archiveRpcError(error: { message: string, code?: string }) {
  if (error.message.includes('event_name_mismatch')) {
    return createError({
      statusCode: 400,
      message: 'O nome do evento não confere',
    })
  }
  if (error.message.includes('event_not_found')) {
    return createError({
      statusCode: 404,
      message: 'Evento não encontrado',
    })
  }
  if (error.message.includes('event_already_archived')) {
    return createError({
      statusCode: 409,
      message: 'Evento já arquivado',
    })
  }
  if (error.message.includes('event_not_featured')) {
    return createError({
      statusCode: 409,
      message: 'Somente o evento principal pode ser arquivado',
    })
  }
  if (error.message.includes('forbidden')) {
    return createError({ statusCode: 403, message: 'Acesso negado' })
  }

  return createError({
    statusCode: 500,
    message: 'Não foi possível arquivar o evento',
  })
}

export async function processArchiveEvent(
  request: ArchiveRequest,
  dependencies: ArchiveDependencies,
) {
  const parsed = ArchiveBody.safeParse(request.body)
  if (!parsed.success) {
    throw createError({
      statusCode: 400,
      message: 'Dados de arquivamento inválidos',
    })
  }

  const token = bearerToken(request.authorization)
  const { data: userData, error: userError } =
    await dependencies.admin.auth.getUser(token)

  if (userError || !userData.user) throw unauthorized()

  const nowSeconds = request.nowSeconds ?? Math.floor(Date.now() / 1000)
  const authTime = recentAuthenticationTimeFromVerifiedToken(token)
  const authAge = nowSeconds - authTime
  if (
    authAge > MAX_AUTH_AGE_SECONDS
    || authAge < -MAX_CLOCK_SKEW_SECONDS
  ) {
    throw unauthorized()
  }

  const { data: profile, error: profileError } = await dependencies.admin
    .from('profiles')
    .select('global_role')
    .eq('id', userData.user.id)
    .single()

  if (profileError) {
    throw createError({
      statusCode: 500,
      message: 'Não foi possível verificar a autorização',
    })
  }
  if (profile?.global_role !== 'global_admin') {
    throw createError({ statusCode: 403, message: 'Acesso negado' })
  }

  if (
    !dependencies.archiveSecret
    || !secretsMatch(parsed.data.archiveSecret, dependencies.archiveSecret)
  ) {
    throw createError({ statusCode: 403, message: 'Acesso negado' })
  }

  const { data, error } = await dependencies.admin.rpc(
    'archive_and_create_event',
    {
      target_event: parsed.data.eventId,
      confirmed_name: parsed.data.eventName,
      actor: userData.user.id,
      copy_config: parsed.data.copyConfig,
    },
  )

  if (error) throw archiveRpcError(error)

  const result = data?.[0]
  if (!result) {
    throw createError({
      statusCode: 500,
      message: 'Resposta de arquivamento inválida',
    })
  }

  return {
    archivedEventId: result.archived_event_id,
    newEventId: result.new_event_id,
  }
}

export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig(event)
  const admin = createSupabaseAdminClient(event)

  return processArchiveEvent(
    {
      authorization: getHeader(event, 'authorization'),
      body: await readBody(event),
    },
    {
      admin: admin as unknown as ArchiveAdminClient,
      archiveSecret: config.eventArchiveSecret,
    },
  )
})
