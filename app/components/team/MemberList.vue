<script setup lang="ts">
import type { Database } from '~/types/database'

type TeamMember = Database['public']['Tables']['team_members']['Row']

defineProps<{
  members: TeamMember[]
  isLeader: boolean
  processingId: string | null
}>()

const emit = defineEmits<{
  decide: [memberId: string, approve: boolean]
}>()

function statusLabel(status: TeamMember['status']) {
  const labels = {
    invited: 'Convite reservado',
    join_requested: 'Aguardando decisão do líder',
    active: 'Participação confirmada',
    rejected: 'Entrada recusada',
  }
  return labels[status]
}
</script>

<template>
  <ul class="member-list" aria-label="Integrantes da equipe">
    <li v-for="member in members" :key="member.id" class="member-card">
      <div>
        <h3>{{ member.name }}</h3>
        <p>{{ member.email }} · Matrícula {{ member.enrollment }}</p>
        <p class="member-status">
          {{ statusLabel(member.status) }}
        </p>
      </div>

      <div v-if="isLeader && member.status === 'join_requested'" class="member-actions">
        <button
          type="button"
          data-member-action="approve"
          :disabled="processingId !== null"
          @click="emit('decide', member.id, true)"
        >
          Aprovar entrada
        </button>
        <button
          type="button"
          class="danger-button"
          data-member-action="reject"
          :disabled="processingId !== null"
          @click="emit('decide', member.id, false)"
        >
          Recusar entrada
        </button>
      </div>
    </li>
  </ul>
</template>
