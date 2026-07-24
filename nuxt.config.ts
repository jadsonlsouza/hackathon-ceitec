export default defineNuxtConfig({
  compatibilityDate: '2026-07-23',
  app: {
    head: {
      title: 'Hackathon CEITEC',
      htmlAttrs: { lang: 'pt-BR' },
    },
  },
  css: ['~/assets/css/main.css'],
  runtimeConfig: {
    supabaseSecretKey: '',
    eventArchiveSecret: '',
    allowStaticPublicContentFallback: process.env.NODE_ENV !== 'production',
    public: {
      supabaseUrl: '',
      supabasePublishableKey: '',
    },
  },
  typescript: { strict: true },
})
