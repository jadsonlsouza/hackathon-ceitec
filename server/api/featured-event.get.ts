export interface FeaturedEvent {
  id: string
  name: string
  slug: string
  status: string
}

export default defineEventHandler(async (): Promise<FeaturedEvent | null> => {
  const config = useRuntimeConfig()
  const url = config.public.supabaseUrl || process.env.NUXT_PUBLIC_SUPABASE_URL || 'https://vmbqqbjtmidjfrebppsz.supabase.co'
  const key = config.public.supabasePublishableKey || process.env.NUXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_DVQDKDL4D0MbbYgm5uTnXQ_0zu5_FBN'

  try {
    const rows = await $fetch<FeaturedEvent[]>(
      `${url}/rest/v1/events?is_featured=eq.true&select=id,name,slug,status&limit=1`,
      {
        headers: {
          apikey: key,
          Authorization: `Bearer ${key}`,
        },
      },
    )
    return rows.at(0) ?? null
  }
  catch {
    return null
  }
})
