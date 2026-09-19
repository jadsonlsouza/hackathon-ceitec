export default defineEventHandler((event) => {
  setResponseHeader(event, 'Cache-Control', 'no-store, max-age=0')
  return {
    ok: true,
    service: 'ligalab',
    timestamp: new Date().toISOString(),
  }
})
