<script setup lang="ts">
import type { Database } from '../../../types/database'

definePageMeta({ middleware: 'auth' })

type AuditRow = Pick<
  Database['public']['Tables']['audit_log']['Row'],
  'id' | 'event_id' | 'action' | 'entity_type' | 'entity_id' | 'created_at'
>

const { $supabase } = useNuxtApp()
const { profile, pending: accessPending, error: accessError } = useCurrentAccess()
const isAuthorized = computed(() => profile.value?.global_role === 'global_admin')
const audit = useAsyncData(
  'global-audit-log',
  async () => {
    if (!isAuthorized.value) return [] as AuditRow[]
    const { data, error } = await $supabase
      .from('audit_log')
      .select('id,event_id,action,entity_type,entity_id,created_at')
      .order('created_at', { ascending: false })
      .limit(100)
    if (error) throw error
    return (data ?? []) as AuditRow[]
  },
  {
    server: false,
    default: () => [] as AuditRow[],
    watch: [profile],
  },
)
</script>

<template>
  <main class="dashboard-page">
    <header class="dashboard-header">
      <p class="eyebrow">
        Administração geral
      </p>
      <h1>Auditoria</h1>
      <p class="intro">
        Consulte as ações administrativas mais recentes sem expor dados internos.
      </p>
    </header>

    <p v-if="accessPending || (isAuthorized && audit.pending.value)" class="request-status">
      Carregando auditoria…
    </p>
    <p v-else-if="accessError || (isAuthorized && audit.error.value)" class="form-error" role="alert">
      Não foi possível carregar a auditoria.
    </p>
    <p v-else-if="!isAuthorized" class="form-error" role="alert">
      Somente a administração geral pode consultar esta página.
    </p>
    <p v-else-if="audit.data.value.length === 0" class="request-status">
      Nenhum registro de auditoria encontrado.
    </p>
    <div v-else class="table-scroll">
      <table class="audit-table">
        <thead>
          <tr>
            <th scope="col">Data</th>
            <th scope="col">Ação</th>
            <th scope="col">Tipo</th>
            <th scope="col">Identificador</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="entry in audit.data.value" :key="entry.id">
            <td><time :datetime="entry.created_at">{{ new Date(entry.created_at).toLocaleString('pt-BR') }}</time></td>
            <td>{{ entry.action }}</td>
            <td>{{ entry.entity_type }}</td>
            <td>{{ entry.entity_id }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </main>
</template>
