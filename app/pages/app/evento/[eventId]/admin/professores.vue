<script setup lang="ts">
definePageMeta({ middleware: 'auth' })

const route = useRoute()
const eventId = computed(() => String(route.params.eventId))
const { $supabase } = useNuxtApp()
const supabase = $supabase as any
const { profile, eventRoles, pending: accessPending, error: accessError } = useCurrentAccess()

const isProfessor = computed(() =>
  profile.value?.global_role === 'global_admin'
  || eventRoles.value.some(role =>
    role.event_id === eventId.value && role.role === 'professor',
  ),
)

const professorsKey = computed(() => `admin-professors:${eventId.value}`)
const { data: professors, pending, error, refresh } = await useAsyncData(
  professorsKey,
  async () => {
    if (!isProfessor.value) return []
    const { data, error: rolesError } = await supabase
      .from('event_roles')
      .select('user_id, approved_at, profile:profiles!event_roles_user_id_fkey(display_name, email)')
      .eq('event_id', eventId.value)
      .eq('role', 'professor')
      .order('approved_at')
    if (rolesError) throw rolesError
    return data ?? []
  },
  {
    server: false,
    default: () => [] as any[],
    watch: [eventId, eventRoles, profile],
  },
)

const addEmail = ref('')
const adding = ref(false)
const addError = ref<string | null>(null)
const addSuccess = ref<string | null>(null)

async function addProfessor() {
  if (adding.value || !addEmail.value.trim()) return
  adding.value = true
  addError.value = null
  addSuccess.value = null
  try {
    const { error: rpcError } = await supabase.rpc('add_event_professor', {
      p_event_id: eventId.value,
      p_email: addEmail.value.trim(),
    })
    if (rpcError) throw rpcError
    addSuccess.value = `Professor ${addEmail.value.trim()} adicionado com sucesso.`
    addEmail.value = ''
    await refresh()
  } catch (err: any) {
    const msg = err?.message ?? ''
    if (msg.includes('user_not_found')) addError.value = 'Nenhum usuário encontrado com este e-mail.'
    else if (msg.includes('cannot_add_self')) addError.value = 'Você não pode adicionar a si mesmo.'
    else if (msg.includes('forbidden')) addError.value = 'Você não tem permissão para esta ação.'
    else addError.value = 'Não foi possível adicionar o professor. Verifique o e-mail e tente novamente.'
  } finally {
    adding.value = false
  }
}

const removingId = ref<string | null>(null)
const removeError = ref<string | null>(null)

async function removeProfessor(userId: string) {
  if (removingId.value) return
  if (!confirm('Tem certeza que deseja remover este professor?')) return
  removingId.value = userId
  removeError.value = null
  try {
    const { error: rpcError } = await supabase.rpc('remove_event_professor', {
      p_event_id: eventId.value,
      p_user_id: userId,
    })
    if (rpcError) throw rpcError
    await refresh()
  } catch (err: any) {
    const msg = err?.message ?? ''
    if (msg.includes('last_professor')) removeError.value = 'Não é possível remover o último professor do evento.'
    else if (msg.includes('cannot_remove_self')) removeError.value = 'Você não pode remover a si mesmo.'
    else removeError.value = 'Não foi possível remover o professor.'
  } finally {
    removingId.value = null
  }
}

function formatDate(dateStr: string) {
  return new Date(dateStr).toLocaleDateString('pt-BR')
}
</script>

<template>
  <main class="professors-admin-page">
    <header class="page-header">
      <p class="eyebrow">Administração do evento</p>
      <h1>Professores / Administradores</h1>
      <p class="intro">
        Adicione ou remova professores com acesso administrativo completo ao evento.
        Todos os professores podem aprovar solicitações, gerenciar equipes, avaliadores e resultados.
      </p>
    </header>

    <p v-if="accessPending || (isProfessor && pending)" class="request-status">
      Carregando…
    </p>
    <p v-else-if="accessError || (isProfessor && error)" class="form-error" role="alert">
      Não foi possível carregar os dados.
    </p>
    <p v-else-if="!isProfessor" class="form-error" role="alert">
      Somente professores têm acesso a esta área.
    </p>

    <template v-else>
      <section class="professors-section">
        <h2>Professores atuais</h2>
        <p v-if="removeError" class="form-error" role="alert">{{ removeError }}</p>

        <ul class="professor-list">
          <li v-for="prof in professors" :key="prof.user_id" class="professor-card">
            <div class="professor-info">
              <span class="professor-avatar">{{ (prof.profile?.display_name ?? 'P')[0].toUpperCase() }}</span>
              <div>
                <strong>{{ prof.profile?.display_name ?? 'Sem nome' }}</strong>
                <p class="professor-email">{{ prof.profile?.email ?? '—' }}</p>
                <p class="professor-meta">Adicionado em {{ formatDate(prof.approved_at) }}</p>
              </div>
            </div>
            <button
              v-if="prof.user_id !== profile?.id"
              type="button"
              class="danger-button compact"
              :disabled="removingId === prof.user_id"
              @click="removeProfessor(prof.user_id)"
            >
              {{ removingId === prof.user_id ? 'Removendo…' : 'Remover' }}
            </button>
            <span v-else class="you-badge">Você</span>
          </li>
          <li v-if="!professors.length" class="empty-state">
            Nenhum professor encontrado.
          </li>
        </ul>
      </section>

      <section class="add-professor-section">
        <h2>Adicionar professor</h2>
        <p class="section-desc">
          O usuário precisa já ter uma conta cadastrada na plataforma.
          Insira o e-mail cadastrado na conta dele.
        </p>

        <p v-if="addError" class="form-error" role="alert">{{ addError }}</p>
        <p v-if="addSuccess" class="form-success" role="status">{{ addSuccess }}</p>

        <form class="add-form" @submit.prevent="addProfessor">
          <div class="input-row">
            <input
              id="add-professor-email"
              v-model="addEmail"
              type="email"
              placeholder="email@exemplo.com"
              :disabled="adding"
              required
            >
            <button type="submit" :disabled="adding || !addEmail.trim()">
              {{ adding ? 'Adicionando…' : 'Adicionar Professor' }}
            </button>
          </div>
        </form>
      </section>
    </template>
  </main>
</template>

<style scoped>
.professors-admin-page {
  max-width: 720px;
  margin: 0 auto;
  padding: 2rem 1.5rem 4rem;
}
.page-header { margin-bottom: 2.5rem; }
.eyebrow {
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: #94a3b8;
  margin: 0 0 0.25rem;
}
h1 {
  font-size: 1.75rem;
  font-weight: 700;
  color: #f1f5f9;
  margin: 0 0 0.5rem;
}
.intro {
  color: #94a3b8;
  font-size: 0.95rem;
  line-height: 1.6;
  margin: 0;
}
.professors-section,
.add-professor-section {
  background: rgba(255,255,255,0.04);
  border: 1px solid rgba(255,255,255,0.08);
  border-radius: 12px;
  padding: 1.5rem;
  margin-bottom: 1.5rem;
}
h2 {
  font-size: 1.05rem;
  font-weight: 600;
  color: #f1f5f9;
  margin: 0 0 1rem;
}
.section-desc {
  color: #94a3b8;
  font-size: 0.875rem;
  margin: -0.5rem 0 1rem;
}
.professor-list {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}
.professor-card {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  background: rgba(255,255,255,0.03);
  border: 1px solid rgba(255,255,255,0.07);
  border-radius: 8px;
  padding: 0.875rem 1rem;
}
.professor-info {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}
.professor-avatar {
  width: 38px;
  height: 38px;
  border-radius: 50%;
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  color: #fff;
  font-weight: 700;
  font-size: 1rem;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.professor-info strong { color: #f1f5f9; font-size: 0.9rem; }
.professor-email { color: #94a3b8; font-size: 0.8rem; margin: 0.1rem 0 0; }
.professor-meta { color: #64748b; font-size: 0.75rem; margin: 0; }
.you-badge {
  font-size: 0.75rem;
  font-weight: 600;
  color: #6366f1;
  background: rgba(99,102,241,0.12);
  border: 1px solid rgba(99,102,241,0.25);
  border-radius: 20px;
  padding: 0.2rem 0.6rem;
  white-space: nowrap;
}
.empty-state { color: #64748b; font-size: 0.875rem; padding: 0.5rem; }
.add-form { margin-top: 0.5rem; }
.input-row { display: flex; gap: 0.75rem; }
.input-row input {
  flex: 1;
  background: rgba(255,255,255,0.06);
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 8px;
  color: #f1f5f9;
  padding: 0.6rem 0.875rem;
  font-size: 0.9rem;
}
.input-row input:focus {
  outline: none;
  border-color: #6366f1;
  box-shadow: 0 0 0 3px rgba(99,102,241,0.15);
}
.input-row input::placeholder { color: #475569; }
.input-row input:disabled { opacity: 0.6; }
button {
  background: #6366f1;
  color: #fff;
  border: none;
  border-radius: 8px;
  padding: 0.6rem 1.2rem;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: opacity 0.15s;
  white-space: nowrap;
}
button:hover:not(:disabled) { opacity: 0.88; }
button:disabled { opacity: 0.5; cursor: not-allowed; }
.danger-button {
  background: transparent;
  color: #f87171;
  border: 1px solid rgba(248,113,113,0.3);
}
.danger-button:hover:not(:disabled) { background: rgba(248,113,113,0.1); opacity: 1; }
.danger-button.compact { padding: 0.4rem 0.875rem; font-size: 0.8rem; }
.form-error { color: #f87171; font-size: 0.875rem; margin: 0.5rem 0; }
.form-success { color: #4ade80; font-size: 0.875rem; margin: 0.5rem 0; }
.request-status { color: #94a3b8; font-size: 0.9rem; }
</style>
