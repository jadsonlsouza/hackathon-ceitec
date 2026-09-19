import { ceitecPublicContent } from '../../app/data/ceitec-public-content'
import type { PublicEventCard } from '../../app/data/public-events'

export default defineEventHandler(async (): Promise<PublicEventCard[]> => {
  const config = useRuntimeConfig()
  const url = config.public.supabaseUrl || process.env.NUXT_PUBLIC_SUPABASE_URL
  const key = config.public.supabasePublishableKey || process.env.NUXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
  const fallbackAllowed = config.allowStaticPublicContentFallback === true

  if (!url || !key) {
    if (fallbackAllowed) return [toFallbackCard()]
    throw eventsUnavailableError()
  }

  try {
    return await $fetch<PublicEventCard[]>(
      `${url}/rest/v1/rpc/get_public_event_catalog`,
      { method: 'POST', headers: { apikey: key }, body: {} },
    )
  }
  catch {
    if (fallbackAllowed) return [toFallbackCard()]
    throw eventsUnavailableError()
  }
})

function toFallbackCard(): PublicEventCard {
  return {
    event_name: ceitecPublicContent.event_name,
    event_slug: ceitecPublicContent.event_slug,
    tagline: ceitecPublicContent.tagline,
    venue: ceitecPublicContent.venue,
    date_label: ceitecPublicContent.date_label,
    registration_open: ceitecPublicContent.registration_open,
  }
}

function eventsUnavailableError() {
  return createError({
    statusCode: 503,
    statusMessage: 'Eventos temporariamente indisponíveis.',
    message: 'Eventos temporariamente indisponíveis.',
  })
}
