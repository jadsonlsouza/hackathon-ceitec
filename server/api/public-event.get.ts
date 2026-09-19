import { ceitecPublicContent } from '../../app/data/ceitec-public-content'
import type {
  PublicEventContent,
  PublishedCategoryResult,
} from '../../app/data/public-events'

export default defineEventHandler(async (): Promise<PublicEventContent | null> => {
  const config = useRuntimeConfig()
  const url = config.public.supabaseUrl || process.env.NUXT_PUBLIC_SUPABASE_URL
  const key = config.public.supabasePublishableKey || process.env.NUXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
  const fallbackAllowed = config.allowStaticPublicContentFallback === true

  if (!url || !key) {
    if (fallbackAllowed) return ceitecPublicContent
    throw publicUnavailableError()
  }

  try {
    const headers = { apikey: key }
    const rows = await $fetch<Omit<PublicEventContent, 'results'>[]>(
      `${url}/rest/v1/rpc/get_featured_event_content`,
      { method: 'POST', headers, body: {} },
    )
    const content = rows.at(0)
    if (!content) {
      if (fallbackAllowed) return ceitecPublicContent
      throw publicUnavailableError()
    }

    const results = await $fetch<PublishedCategoryResult[]>(
      `${url}/rest/v1/rpc/get_published_results`,
      {
        method: 'POST',
        headers,
        body: { event_slug: content.event_slug },
      },
    )

    return { ...content, results }
  }
  catch (error) {
    if ((error as { statusCode?: number }).statusCode) throw error
    if (fallbackAllowed) return ceitecPublicContent
    throw publicUnavailableError()
  }
})

function publicUnavailableError() {
  return createError({
    statusCode: 503,
    statusMessage: 'Conteúdo público temporariamente indisponível',
    message: 'Conteúdo público temporariamente indisponível',
  })
}
