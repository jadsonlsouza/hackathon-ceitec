import { ceitecPublicContent } from '../../app/data/ceitec-public-content'
import type {
  PublicEventContent,
  PublishedCategoryResult,
} from '../../app/data/ceitec-public-content'

export default defineEventHandler(async (): Promise<PublicEventContent | null> => {
  const config = useRuntimeConfig()
  const url = config.public.supabaseUrl
  const key = config.public.supabasePublishableKey

  // Keeps local SSR and automated accessibility checks deterministic. A configured
  // deployment always reads the protected database RPCs.
  if (!url || !key) return ceitecPublicContent

  const headers = { apikey: key, Authorization: `Bearer ${key}` }
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
})
