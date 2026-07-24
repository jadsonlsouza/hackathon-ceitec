<script setup lang="ts">
const email = ref('')
const password = ref('')
const errorMessage = ref('')
const pending = ref(false)
const fieldErrors = reactive<Record<string, string>>({})
const { signInWithPassword, signInWithGoogle } = useAuth()

async function submitPassword() {
  const validation = validateLogin({ email: email.value, password: password.value })
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
  let successLogin = false
  try {
    const { error } = await signInWithPassword(email.value, password.value)
    if (error) {
      errorMessage.value = error.message === 'Invalid login credentials' 
        ? 'E-mail ou senha inválidos.' 
        : (error.message || 'E-mail ou senha inválidos.')
      return
    }
    successLogin = true
  } catch (err: any) {
    errorMessage.value = err?.message || 'Não foi possível entrar. Tente novamente.'
    return
  } finally {
    pending.value = false
  }

  if (successLogin) {
    await navigateTo('/app')
  }
}

async function submitGoogle() {
  pending.value = true
  errorMessage.value = ''
  try {
    const { error } = await signInWithGoogle()
    if (error) errorMessage.value = error.message || 'Não foi possível iniciar o login com Google.'
  } catch (err: any) {
    errorMessage.value = err?.message || 'Não foi possível iniciar o login com Google.'
  } finally {
    pending.value = false
  }
}
</script>

<template>
  <main class="auth-page">
    <section class="auth-card" aria-labelledby="login-title">
      <p class="eyebrow">Hackathon CEITEC</p>
      <h1 id="login-title">Entrar</h1>
      <p class="intro">Acesse sua conta para participar do evento.</p>

      <form novalidate @submit.prevent="submitPassword">
        <label for="login-email">E-mail</label>
        <input id="login-email" v-model.trim="email" type="email" autocomplete="email" :aria-describedby="fieldErrors.email ? 'login-email-error' : undefined" :aria-invalid="Boolean(fieldErrors.email)">
        <p v-if="fieldErrors.email" id="login-email-error" class="form-error" role="alert">{{ fieldErrors.email }}</p>

        <label for="login-password">Senha</label>
        <input id="login-password" v-model="password" type="password" autocomplete="current-password" :aria-describedby="fieldErrors.password ? 'login-password-error' : undefined" :aria-invalid="Boolean(fieldErrors.password)">
        <p v-if="fieldErrors.password" id="login-password-error" class="form-error" role="alert">{{ fieldErrors.password }}</p>

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
