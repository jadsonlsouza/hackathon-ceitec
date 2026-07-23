export default defineNuxtConfig({
  compatibilityDate: '2026-07-23',
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
