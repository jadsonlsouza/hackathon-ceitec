<script setup lang="ts">
import { ref, onMounted } from 'vue'

const { $supabase } = useNuxtApp()
const pending = ref(false)
const errorMessage = ref('')
const selectedRole = ref<'student' | 'professor' | 'monitor' | 'evaluator' | null>(null)

interface FeaturedEvent {
  id: string
  name: string
  slug: string
  status: string
}

const featuredEvent = ref<FeaturedEvent | null>(null)
const eventLoading = ref(true)

onMounted(async () => {
  try {
    featuredEvent.value = await $fetch<FeaturedEvent | null>('/api/featured-event')
  }
  catch {
    featuredEvent.value = null
  }
  finally {
    eventLoading.value = false
  }
})

const roles = [
  {
    value: 'student' as const,
    label: 'Estudante',
    description: 'Participo com minha equipe, envio projetos e colaboro nas atividades do hackathon.',
    icon: '🎓',
    note: null,
  },
  {
    value: 'monitor' as const,
    label: 'Monitor(a)',
    description: 'Auxilio as equipes, revisando envios e apoiando o andamento do evento.',
    icon: '🧑‍🏫',
    note: 'Requer aprovação do professor responsável.',
  },
  {
    value: 'professor' as const,
    label: 'Professor(a)',
    description: 'Coordeno o evento, gerencio equipes e monitores, e aprovo solicitações.',
    icon: '👨‍💼',
    note: 'Requer aprovação do administrador geral.',
  },
  {
    value: 'evaluator' as const,
    label: 'Avaliador(a)',
    description: 'Avalio os projetos e apresentações das equipes inscritas no evento.',
    icon: '⚖️',
    note: 'Requer aprovação do professor responsável.',
  },
]

async function confirm() {
  if (!selectedRole.value) return
  if (!featuredEvent.value && selectedRole.value !== 'student') {
    errorMessage.value = 'Nenhum evento ativo encontrado. Entre em contato com o administrador.'
    return
  }

  pending.value = true
  errorMessage.value = ''

  try {
    if (selectedRole.value === 'student') {
      // Students don't need a role_request; mark onboarding as done in metadata.
      const { error } = await $supabase.auth.updateUser({
        data: { onboarding_done: true },
      })
      if (error) throw error
    }
    else {
      const { error } = await $supabase.rpc('request_role', {
        target_role: selectedRole.value,
        target_event: featuredEvent.value!.id,
      })
      if (error) throw error
    }

    await navigateTo('/app')
  }
  catch (err: any) {
    errorMessage.value = err?.message || 'Não foi possível concluir. Tente novamente.'
  }
  finally {
    pending.value = false
  }
}
</script>

<template>
  <main class="onboarding-page">
    <div class="onboarding-card">
      <div class="onboarding-header">
        <p class="eyebrow">Hackathon CEITEC</p>
        <h1>Como você vai participar?</h1>
        <p class="intro">
          <span v-if="eventLoading">Carregando evento…</span>
          <span v-else-if="featuredEvent">
            Selecione seu perfil para o evento
            <strong>{{ featuredEvent.name }}</strong>.
          </span>
          <span v-else>
            Selecione seu perfil de participação.
          </span>
        </p>
      </div>

      <div class="role-grid" role="radiogroup" aria-label="Selecione seu perfil">
        <label
          v-for="role in roles"
          :key="role.value"
          class="role-card"
          :class="{ 'is-selected': selectedRole === role.value }"
        >
          <input
            type="radio"
            name="role"
            :value="role.value"
            class="role-radio"
            @change="selectedRole = role.value"
          >
          <span class="role-icon" aria-hidden="true">{{ role.icon }}</span>
          <span class="role-label">{{ role.label }}</span>
          <span class="role-description">{{ role.description }}</span>
          <span v-if="role.note" class="role-note">{{ role.note }}</span>
        </label>
      </div>

      <p v-if="errorMessage" class="form-error" role="alert">{{ errorMessage }}</p>

      <button
        class="onboarding-confirm-btn"
        type="button"
        :disabled="!selectedRole || pending"
        @click="confirm"
      >
        <span v-if="pending">Salvando…</span>
        <span v-else-if="!selectedRole">Selecione um perfil</span>
        <span v-else>Confirmar e entrar</span>
      </button>
    </div>
  </main>
</template>
