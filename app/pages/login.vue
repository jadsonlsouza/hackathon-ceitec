<script setup lang="ts">
const email = ref('')
const password = ref('')
const errorMessage = ref('')
const pending = ref(false)
const { signInWithPassword, signInWithGoogle } = useAuth()

async function submitPassword() {
  if (!email.value || !password.value) {
    errorMessage.value = 'Informe seu e-mail e sua senha.'
    return
  }

  pending.value = true
  errorMessage.value = ''
  const { error } = await signInWithPassword(email.value, password.value)
  pending.value = false

  if (error) return void (errorMessage.value = 'E-mail ou senha inválidos.')
  await navigateTo('/app')
}

async function submitGoogle() {
  pending.value = true
  errorMessage.value = ''
  const { error } = await signInWithGoogle()
  pending.value = false

  if (error) errorMessage.value = 'Não foi possível iniciar o login com Google.'
}
</script>

<template>
  <main class="auth-page">
    <section class="auth-card" aria-labelledby="login-title">
      <p class="eyebrow">Hackathon CEITEC</p>
      <h1 id="login-title">Entrar</h1>
      <p class="intro">Acesse sua conta para participar do evento.</p>

      <form @submit.prevent="submitPassword">
        <label for="login-email">E-mail</label>
        <input id="login-email" v-model.trim="email" type="email" autocomplete="email" required>

        <label for="login-password">Senha</label>
        <input id="login-password" v-model="password" type="password" autocomplete="current-password" required>

        <p v-if="errorMessage" class="form-error" role="alert">{{ errorMessage }}</p>
        <button type="submit" :disabled="pending">{{ pending ? 'Entrando...' : 'Entrar com e-mail' }}</button>
      </form>

      <div class="divider" aria-hidden="true">ou</div>
      <button class="secondary-button" type="button" :disabled="pending" @click="submitGoogle">
        Continuar com Google
      </button>

      <nav class="auth-links" aria-label="Opções de acesso">
        <NuxtLink to="/recuperar-senha">Esqueci minha senha</NuxtLink>
        <NuxtLink to="/cadastro">Criar conta</NuxtLink>
      </nav>
    </section>
  </main>
</template>
