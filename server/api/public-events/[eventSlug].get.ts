import type {
  PublicEventContent,
  PublishedCategoryResult,
} from '../../../app/data/public-events'

const slugPattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/

export default defineEventHandler(async (event): Promise<PublicEventContent> => {
  const eventSlug = getRouterParam(event, 'eventSlug')
  if (!eventSlug || !slugPattern.test(eventSlug)) {
    throw eventNotFoundError()
  }

  const config = useRuntimeConfig()
  const url = config.public.supabaseUrl || process.env.NUXT_PUBLIC_SUPABASE_URL
  const key = config.public.supabasePublishableKey || process.env.NUXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
  if (!url || !key) {
    throw eventUnavailableError()
  }

  try {
    const headers = { apikey: key }
    const rows = await $fetch<Omit<PublicEventContent, 'results'>[]>(
      `${url}/rest/v1/rpc/get_public_event_content`,
      { method: 'POST', headers, body: { requested_slug: eventSlug } },
    )
    const content = rows.at(0)
    if (!content) {
      throw eventNotFoundError()
    }

    const results = await $fetch<PublishedCategoryResult[]>(
      `${url}/rest/v1/rpc/get_published_results`,
      { method: 'POST', headers, body: { event_slug: content.event_slug } },
    )
    return { ...content, results }
  }
  catch (error) {
    if ((error as { statusCode?: number }).statusCode) throw error
    throw eventUnavailableError()
  }
})

function eventNotFoundError() {
  return createError({
    statusCode: 404,
    statusMessage: 'Evento não encontrado.',
    message: 'Evento não encontrado.',
  })
}

function eventUnavailableError() {
  return createError({
    statusCode: 503,
    statusMessage: 'Evento temporariamente indisponível.',
    message: 'Evento temporariamente indisponível.',
  })
}
