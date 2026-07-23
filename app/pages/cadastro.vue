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
const { signUp } = useAuth()

async function submit() {
  if (!form.name || !form.email || !form.password) {
    errorMessage.value = 'Preencha todos os campos obrigatórios.'
    return
  }

  pending.value = true
  errorMessage.value = ''
  const { error } = await signUp({ ...form })
  pending.value = false

  if (error) return void (errorMessage.value = 'Não foi possível criar sua conta. Tente novamente.')
  success.value = true
}
</script>

<template>
  <main class="auth-page">
    <section class="auth-card" aria-labelledby="signup-title">
      <p class="eyebrow">Hackathon CEITEC</p>
      <h1 id="signup-title">Criar conta</h1>
      <p class="intro">Informe seus dados para começar.</p>

      <form v-if="!success" @submit.prevent="submit">
        <label for="signup-name">Nome completo</label>
        <input id="signup-name" v-model.trim="form.name" autocomplete="name" required>

        <label for="signup-email">E-mail</label>
        <input id="signup-email" v-model.trim="form.email" type="email" autocomplete="email" required>

        <label for="signup-password">Senha</label>
        <input id="signup-password" v-model="form.password" type="password" minlength="8" autocomplete="new-password" required>

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
