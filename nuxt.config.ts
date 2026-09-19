export default defineNuxtConfig({
  compatibilityDate: '2026-07-23',
  app: {
    head: {
      title: 'ligalab',
      htmlAttrs: { lang: 'pt-BR' },
      link: [
        { rel: 'icon', type: 'image/png', href: '/brand/liga-inovacao.png' },
      ],
    },
  },
  css: ['~/assets/css/main.css'],
  runtimeConfig: {
    supabaseSecretKey: '',
    eventArchiveSecret: '',
    allowStaticPublicContentFallback: process.env.NODE_ENV !== 'production',
    public: {
      supabaseUrl: process.env.NUXT_PUBLIC_SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://vmbqqbjtmidjfrebppsz.supabase.co',
      supabasePublishableKey: process.env.NUXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_DVQDKDL4D0MbbYgm5uTnXQ_0zu5_FBN',
    },
  },
  typescript: { strict: true },
})
