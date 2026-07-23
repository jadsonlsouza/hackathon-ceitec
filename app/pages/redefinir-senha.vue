<script setup lang="ts">
const password = ref('')
const confirmation = ref('')
const errorMessage = ref('')
const success = ref(false)
const pending = ref(false)
const { $supabase } = useNuxtApp()

async function submit() {
  if (password.value.length < 8) {
    errorMessage.value = 'A senha deve ter pelo menos 8 caracteres.'
    return
  }
  if (password.value !== confirmation.value) {
    errorMessage.value = 'As senhas não coincidem.'
    return
  }

  pending.value = true
  errorMessage.value = ''
  const { error } = await $supabase.auth.updateUser({ password: password.value })
  pending.value = false

  if (error) return void (errorMessage.value = 'Não foi possível redefinir sua senha. Solicite um novo link.')
  success.value = true
}
</script>

<template>
  <main class="auth-page">
    <section class="auth-card" aria-labelledby="reset-title">
      <p class="eyebrow">Hackathon CEITEC</p>
      <h1 id="reset-title">Redefinir senha</h1>
      <p class="intro">Escolha uma nova senha para sua conta.</p>

      <form v-if="!success" @submit.prevent="submit">
        <label for="reset-password">Nova senha</label>
        <input id="reset-password" v-model="password" type="password" minlength="8" autocomplete="new-password" required>
        <label for="reset-confirmation">Confirme a nova senha</label>
        <input id="reset-confirmation" v-model="confirmation" type="password" minlength="8" autocomplete="new-password" required>
        <p v-if="errorMessage" class="form-error" role="alert">{{ errorMessage }}</p>
        <button type="submit" :disabled="pending">{{ pending ? 'Salvando...' : 'Salvar nova senha' }}</button>
      </form>
      <p v-else class="form-success" role="status">Senha redefinida com sucesso. <NuxtLink to="/login">Entrar agora</NuxtLink></p>
    </section>
  </main>
</template>
