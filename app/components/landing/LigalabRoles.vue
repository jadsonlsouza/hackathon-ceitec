<script setup lang="ts">
import { ref } from 'vue'

interface RoleItem {
  id: string
  label: string
  icon: string
  tagline: string
  description: string
  benefits: string[]
}

const roles: RoleItem[] = [
  {
    id: 'estudantes',
    label: 'Alunos',
    icon: '🚀',
    tagline: 'Protagonismo real para transformar ideias em projetos validados',
    description: 'As equipes realizam atividades, acompanham seus envios e recebem o retorno de professores e monitores.',
    benefits: [
      'Canvas colaborativo com salvamento contínuo',
      'Acompanhamento dos envios e feedbacks',
      'Consulta a oficinas e presença',
      'Participação em equipes do evento',
    ],
  },
  {
    id: 'organizadores',
    label: 'Professores e administradores',
    icon: '⚡',
    tagline: 'Controle total da maratona sem planilhas ou desencontros',
    description: 'Configure eventos, acompanhe equipes e envios e organize os critérios de avaliação.',
    benefits: [
      'Monitoramento ao vivo de todas as equipes',
      'Configuração rápida de rubricas e critérios',
      'Auditoria de desempate e segurança de notas',
      'Publicação dos resultados do evento',
    ],
  },
  {
    id: 'mentores',
    label: 'Monitores',
    icon: '💡',
    tagline: 'Acompanhe entregas e apoie as equipes',
    description: 'Monitores acompanham os envios das equipes, validam entregas e podem enviar feedback.',
    benefits: [
      'Consulta aos envios do evento',
      'Validação das entregas',
      'Feedback opcional para as equipes',
      'Acompanhamento do status de revisão',
    ],
  },
  {
    id: 'jurados',
    label: 'Avaliadores',
    icon: '🎖️',
    tagline: 'Avaliação sem estresse com critérios congelados e cálculo automático',
    description: 'Interface limpa e rápida para bancas finais. Os jurados pontuam cada equipe conforme a ordem de apresentação, consultam o resumo da solução e registram comentários de forma protegida.',
    benefits: [
      'Notas com base em critérios parametrizados',
      'Proteção contra cliques duplicados e perdas',
      'Cálculo ponderado automático sem planilhas',
      'Deliberação rápida com suporte a desempates',
    ],
  },
]

const activeRoleId = ref('estudantes')
const activeRole = computed(() => roles.find(r => r.id === activeRoleId.value) ?? roles[0])
</script>

<template>
  <section class="landing-section ligalab-roles" aria-labelledby="roles-title">
    <div class="ligalab-section-header">
      <p class="section-index">Experiência Multi-Papel</p>
      <h2 id="roles-title">Uma visão para cada perfil</h2>
      <p class="section-copy">
        Alunos, professores, monitores, avaliadores e administradores encontram as tarefas do seu papel em cada evento.
      </p>
    </div>

    <!-- Navegação por abas de papéis -->
    <div class="roles-tablist" role="tablist" aria-label="Selecione o perfil de usuário">
      <button
        v-for="role in roles"
        :key="role.id"
        type="button"
        role="tab"
        :id="`tab-role-${role.id}`"
        :aria-selected="activeRoleId === role.id"
        :aria-controls="`panel-role-${role.id}`"
        class="role-tab"
        :class="{ 'role-tab--active': activeRoleId === role.id }"
        @click="activeRoleId = role.id"
      >
        <span class="role-tab__icon" aria-hidden="true">{{ role.icon }}</span>
        <span class="role-tab__label">{{ role.label }}</span>
      </button>
    </div>

    <!-- Painel do papel ativo -->
    <div
      :id="`panel-role-${activeRole.id}`"
      role="tabpanel"
      :aria-labelledby="`tab-role-${activeRole.id}`"
      class="role-panel"
    >
      <div class="role-panel__header">
        <span class="role-panel__icon" aria-hidden="true">{{ activeRole.icon }}</span>
        <div>
          <h3 class="role-panel__title">{{ activeRole.label }}</h3>
          <p class="role-panel__tagline">{{ activeRole.tagline }}</p>
        </div>
      </div>
      <p class="role-panel__description">{{ activeRole.description }}</p>

      <div class="role-panel__benefits">
        <h4 class="role-benefits-title">Destaques da experiência:</h4>
        <ul class="role-benefits-list">
          <li v-for="b in activeRole.benefits" :key="b" class="role-benefit-item">
            <span class="role-benefit-check" aria-hidden="true">✓</span>
            <span>{{ b }}</span>
          </li>
        </ul>
      </div>
    </div>
  </section>
</template>
