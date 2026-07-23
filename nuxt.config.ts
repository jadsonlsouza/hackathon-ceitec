export default defineNuxtConfig({
  compatibilityDate: '2026-07-23',
  css: ['~/assets/css/main.css'],
  runtimeConfig: {
    supabaseSecretKey: '',
    eventArchiveSecret: '',
    public: {
      supabaseUrl: '',
      supabasePublishableKey: '',
    },
  },
  typescript: { strict: true },
})
