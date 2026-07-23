<script setup lang="ts">
const email = ref('')
const errorMessage = ref('')
const success = ref(false)
const pending = ref(false)
const { sendPasswordReset } = useAuth()

async function submit() {
  if (!email.value) {
    errorMessage.value = 'Informe seu e-mail.'
    return
  }

  pending.value = true
  errorMessage.value = ''
  const { error } = await sendPasswordReset(email.value)
  pending.value = false

  if (error) return void (errorMessage.value = 'Não foi possível enviar o link. Tente novamente.')
  success.value = true
}
</script>

<template>
  <main class="auth-page">
    <section class="auth-card" aria-labelledby="recovery-title">
      <p class="eyebrow">Hackathon CEITEC</p>
      <h1 id="recovery-title">Recuperar senha</h1>
      <p class="intro">Enviaremos um link seguro para redefinir sua senha.</p>

      <form v-if="!success" @submit.prevent="submit">
        <label for="recovery-email">E-mail</label>
        <input id="recovery-email" v-model.trim="email" type="email" autocomplete="email" required>
        <p v-if="errorMessage" class="form-error" role="alert">{{ errorMessage }}</p>
        <button type="submit" :disabled="pending">{{ pending ? 'Enviando...' : 'Enviar link' }}</button>
      </form>
      <p v-else class="form-success" role="status">Se houver uma conta com este e-mail, você receberá um link em breve.</p>
      <p class="auth-links"><NuxtLink to="/login">Voltar para entrar</NuxtLink></p>
    </section>
  </main>
</template>
