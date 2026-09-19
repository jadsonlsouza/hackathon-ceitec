<script setup lang="ts">
const password = ref('')
const confirmation = ref('')
const errorMessage = ref('')
const success = ref(false)
const pending = ref(false)
const fieldErrors = reactive<Record<string, string>>({})
const { $supabase } = useNuxtApp()

async function submit() {
  const validation = validateNewPassword({ password: password.value, confirmation: confirmation.value })
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
    const { error } = await $supabase.auth.updateUser({ password: password.value })
    if (error) return void (errorMessage.value = 'Não foi possível redefinir sua senha. Solicite um novo link.')
    success.value = true
  } catch {
    errorMessage.value = 'Não foi possível redefinir sua senha. Solicite um novo link.'
  } finally {
    pending.value = false
  }
}
</script>

<template>
  <main class="auth-page">
    <section class="auth-card" aria-labelledby="reset-title">
      <p class="eyebrow">ligalab</p>
      <h1 id="reset-title">Redefinir senha</h1>
      <p class="intro">Escolha uma nova senha para sua conta.</p>

      <form v-if="!success" novalidate @submit.prevent="submit">
        <label for="reset-password">Nova senha</label>
        <input id="reset-password" v-model="password" type="password" autocomplete="new-password" :aria-describedby="fieldErrors.password ? 'reset-password-error' : undefined" :aria-invalid="Boolean(fieldErrors.password)">
        <p v-if="fieldErrors.password" id="reset-password-error" class="form-error" role="alert">{{ fieldErrors.password }}</p>
        <label for="reset-confirmation">Confirme a nova senha</label>
        <input id="reset-confirmation" v-model="confirmation" type="password" autocomplete="new-password" :aria-describedby="fieldErrors.confirmation ? 'reset-confirmation-error' : undefined" :aria-invalid="Boolean(fieldErrors.confirmation)">
        <p v-if="fieldErrors.confirmation" id="reset-confirmation-error" class="form-error" role="alert">{{ fieldErrors.confirmation }}</p>
        <p v-if="errorMessage" class="form-error" role="alert">{{ errorMessage }}</p>
        <button type="submit" :disabled="pending">{{ pending ? 'Salvando...' : 'Salvar nova senha' }}</button>
      </form>
      <p v-else class="form-success" role="status">Senha redefinida com sucesso. <NuxtLink to="/login">Entrar agora</NuxtLink></p>
    </section>
  </main>
</template>
