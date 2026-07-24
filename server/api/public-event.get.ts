import { ceitecPublicContent } from '../../app/data/ceitec-public-content'
import type {
  PublicEventContent,
  PublishedCategoryResult,
} from '../../app/data/ceitec-public-content'

export default defineEventHandler(async (): Promise<PublicEventContent | null> => {
  const config = useRuntimeConfig()
  const url = config.public.supabaseUrl || process.env.NUXT_PUBLIC_SUPABASE_URL || 'https://vmbqqbjtmidjfrebppsz.supabase.co'
  const key = config.public.supabasePublishableKey || process.env.NUXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_DVQDKDL4D0MbbYgm5uTnXQ_0zu5_FBN'

  try {
    const headers = { apikey: key }
    const rows = await $fetch<Omit<PublicEventContent, 'results'>[]>(
      `${url}/rest/v1/rpc/get_featured_event_content`,
      { method: 'POST', headers, body: {} },
    )
    const content = rows.at(0)
    if (!content) return ceitecPublicContent

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
    return ceitecPublicContent
  }
})
