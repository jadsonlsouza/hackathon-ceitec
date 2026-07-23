<script setup lang="ts">
import { ref, watch } from 'vue'

interface TiedTeam {
  team_id: string
  team_name: string
}

const props = defineProps<{
  eventId: string
  category: 'junior' | 'senior'
  displayedScore: number
  teams: TiedTeam[]
  processing: boolean
}>()

const emit = defineEmits<{
  resolve: [payload: {
    event_id: string
    category: 'junior' | 'senior'
    displayed_score: number
    ordered_team_ids: string[]
    justification: string
  }]
}>()

const orderedTeams = ref<TiedTeam[]>([...props.teams])
const justification = ref('')

watch(
  () => props.teams,
  teams => {
    orderedTeams.value = [...teams]
  },
  { deep: true },
)

function move(index: number, offset: -1 | 1) {
  const destination = index + offset
  if (destination < 0 || destination >= orderedTeams.value.length) return
  const next = [...orderedTeams.value]
  const [team] = next.splice(index, 1)
  if (!team) return
  next.splice(destination, 0, team)
  orderedTeams.value = next
}

function submit() {
  const normalized = justification.value.trim()
  if (props.processing || !normalized) return
  emit('resolve', {
    event_id: props.eventId,
    category: props.category,
    displayed_score: props.displayedScore,
    ordered_team_ids: orderedTeams.value.map(team => team.team_id),
    justification: normalized,
  })
}
</script>

<template>
  <section class="tie-resolution">
    <header>
      <div>
        <p class="eyebrow">
          Desempate manual
        </p>
        <h3>Nota {{ displayedScore.toFixed(2) }}</h3>
      </div>
      <span>{{ teams.length }} equipes empatadas</span>
    </header>

    <form @submit.prevent="submit">
      <ol class="tie-team-list">
        <li
          v-for="(team, index) in orderedTeams"
          :key="team.team_id"
          data-tie-team
        >
          <span class="tie-position">{{ index + 1 }}º</span>
          <strong>{{ team.team_name }}</strong>
          <div class="tie-order-actions">
            <button
              type="button"
              :disabled="processing || index === 0"
              :aria-label="`Mover ${team.team_name} para cima`"
              data-move-up
              @click="move(index, -1)"
            >
              ↑
            </button>
            <button
              type="button"
              :disabled="processing || index === orderedTeams.length - 1"
              :aria-label="`Mover ${team.team_name} para baixo`"
              data-move-down
              @click="move(index, 1)"
            >
              ↓
            </button>
          </div>
        </li>
      </ol>

      <label :for="`tie-justification-${category}-${displayedScore}`">
        Justificativa da decisão
      </label>
      <textarea
        :id="`tie-justification-${category}-${displayedScore}`"
        v-model="justification"
        required
        maxlength="4000"
        rows="4"
        :disabled="processing"
        placeholder="Registre os critérios discutidos com os avaliadores."
      />
      <p class="field-help">
        A ordem é auditada e não altera as notas originais.
      </p>
      <button
        type="submit"
        :disabled="processing || !justification.trim()"
      >
        {{ processing ? 'Registrando…' : 'Registrar desempate' }}
      </button>
    </form>
  </section>
</template>
