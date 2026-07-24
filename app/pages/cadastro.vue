<script setup lang="ts">
import type { SignUpInput } from '~/composables/useAuth'

const form = reactive<SignUpInput>({
  name: '',
  email: '',
  password: '',
  requestedRole: 'student',
})
const errorMessage = ref('')
const pending = ref(false)
const success = ref(false)
const fieldErrors = reactive<Record<string, string>>({})
const { signUp } = useAuth()

async function submit() {
  const validation = validateSignUp(form)
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
    const { error } = await signUp({ ...form })
    if (error) {
      errorMessage.value = error.message || 'Não foi possível criar sua conta. Tente novamente.'
      return
    }
    success.value = true
  } catch (err: any) {
    errorMessage.value = err?.message || 'Não foi possível criar sua conta. Tente novamente.'
  } finally {
    pending.value = false
  }
}
</script>

<template>
  <main class="auth-page">
    <section class="auth-card" aria-labelledby="signup-title">
      <p class="eyebrow">Hackathon CEITEC</p>
      <h1 id="signup-title">Criar conta</h1>
      <p class="intro">Informe seus dados para começar.</p>

      <form v-if="!success" novalidate @submit.prevent="submit">
        <label for="signup-name">Nome completo</label>
        <input id="signup-name" v-model.trim="form.name" autocomplete="name" :aria-describedby="fieldErrors.name ? 'signup-name-error' : undefined" :aria-invalid="Boolean(fieldErrors.name)">
        <p v-if="fieldErrors.name" id="signup-name-error" class="form-error" role="alert">{{ fieldErrors.name }}</p>

        <label for="signup-email">E-mail</label>
        <input id="signup-email" v-model.trim="form.email" type="email" autocomplete="email" :aria-describedby="fieldErrors.email ? 'signup-email-error' : undefined" :aria-invalid="Boolean(fieldErrors.email)">
        <p v-if="fieldErrors.email" id="signup-email-error" class="form-error" role="alert">{{ fieldErrors.email }}</p>

        <label for="signup-password">Senha</label>
        <input id="signup-password" v-model="form.password" type="password" autocomplete="new-password" :aria-describedby="fieldErrors.password ? 'signup-password-error' : undefined" :aria-invalid="Boolean(fieldErrors.password)">
        <p v-if="fieldErrors.password" id="signup-password-error" class="form-error" role="alert">{{ fieldErrors.password }}</p>

        <label for="signup-role">Como deseja participar?</label>
        <select id="signup-role" v-model="form.requestedRole">
          <option value="student">Estudante</option>
          <option value="professor">Professor(a)</option>
          <option value="monitor">Monitor(a)</option>
          <option value="evaluator">Avaliador(a)</option>
        </select>
        <p class="field-help">Funções além de estudante precisam de aprovação.</p>

        <p v-if="errorMessage" class="form-error" role="alert">{{ errorMessage }}</p>
        <button type="submit" :disabled="pending">{{ pending ? 'Criando conta...' : 'Criar conta' }}</button>
      </form>

      <p v-else class="form-success" role="status">Verifique seu e-mail para confirmar sua conta.</p>
      <p class="auth-links"><NuxtLink to="/login">Já tenho uma conta</NuxtLink></p>
    </section>
  </main>
</template>
