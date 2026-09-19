<script setup lang="ts">
const email = ref('')
const errorMessage = ref('')
const success = ref(false)
const pending = ref(false)
const fieldErrors = reactive<Record<string, string>>({})
const { sendPasswordReset } = useAuth()

async function submit() {
  const validation = validatePasswordReset({ email: email.value })
  Object.assign(fieldErrors, validation.errors)
  for (const field of Object.keys(fieldErrors)) {
    if (!(field in validation.errors)) delete fieldErrors[field]
  }
  if (validation.firstInvalidId) {
    await nextTick()
    focusFirstInvalidField(validation.firstInvalidId)
    return
  }

  pending.value = true
  errorMessage.value = ''
  try {
    const { error } = await sendPasswordReset(email.value)
    if (error) return void (errorMessage.value = 'Não foi possível enviar o link. Tente novamente.')
    success.value = true
  } catch {
    errorMessage.value = 'Não foi possível enviar o link. Tente novamente.'
  } finally {
    pending.value = false
  }
}
</script>

<template>
  <main class="auth-page">
    <section class="auth-card" aria-labelledby="recovery-title">
      <p class="eyebrow">ligalab</p>
      <h1 id="recovery-title">Recuperar senha</h1>
      <p class="intro">Enviaremos um link seguro para redefinir sua senha.</p>

      <form v-if="!success" novalidate @submit.prevent="submit">
        <label for="recovery-email">E-mail</label>
        <input id="recovery-email" v-model.trim="email" type="email" autocomplete="email" :aria-describedby="fieldErrors.email ? 'recovery-email-error' : undefined" :aria-invalid="Boolean(fieldErrors.email)">
        <p v-if="fieldErrors.email" id="recovery-email-error" class="form-error" role="alert">{{ fieldErrors.email }}</p>
        <p v-if="errorMessage" class="form-error" role="alert">{{ errorMessage }}</p>
        <button type="submit" :disabled="pending">{{ pending ? 'Enviando...' : 'Enviar link' }}</button>
      </form>
      <p v-else class="form-success" role="status">Se houver uma conta com este e-mail, você receberá um link em breve.</p>
      <p class="auth-links"><NuxtLink to="/login">Voltar para entrar</NuxtLink></p>
    </section>
  </main>
</template>
