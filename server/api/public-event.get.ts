import { ceitecPublicContent } from '../../app/data/ceitec-public-content'
import type {
  PublicEventContent,
  PublishedCategoryResult,
} from '../../app/data/ceitec-public-content'

export default defineEventHandler(async (): Promise<PublicEventContent | null> => {
  const config = useRuntimeConfig()
  const url = config.public.supabaseUrl
  const key = config.public.supabasePublishableKey

  if (!url || !key) {
    if (config.allowStaticPublicContentFallback === true) return ceitecPublicContent
    throw createError({
      statusCode: 503,
      message: 'Conteúdo público temporariamente indisponível',
    })
  }

  try {
    const headers = { apikey: key }
    const rows = await $fetch<Omit<PublicEventContent, 'results'>[]>(
      `${url}/rest/v1/rpc/get_featured_event_content`,
      { method: 'POST', headers, body: {} },
    )
    const content = rows.at(0)
    if (!content) return null

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
  catch {
    throw createError({
      statusCode: 503,
      message: 'Conteúdo público temporariamente indisponível',
    })
  }
})
