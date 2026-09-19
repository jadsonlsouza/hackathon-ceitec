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
    label: 'Estudantes & Hackers',
    icon: '🚀',
    tagline: 'Protagonismo real para transformar ideias em projetos validados',
    description: 'Interface intuitiva focada na experiência de desenvolvimento. As equipes montam o canvas em tempo real, recebem feedback de mentores e acompanham a agenda sem se perderem.',
    benefits: [
      'Canvas colaborativo com salvamento contínuo',
      'Abertura de chamados diretos para mentores',
      'Acompanhamento de trilhas de IA e oficinas',
      'Portfólio com vitrine pública dos projetos',
    ],
  },
  {
    id: 'organizadores',
    label: 'Organizadores & Ligas',
    icon: '⚡',
    tagline: 'Controle total da maratona sem planilhas ou desencontros',
    description: 'Painel completo de controle. Configure o cronograma, divida categorias, gerencie presenças, acompanhe a fila de solicitações e visualize o status de submissão de cada equipe em tempo real.',
    benefits: [
      'Monitoramento ao vivo de todas as equipes',
      'Configuração rápida de rubricas e critérios',
      'Auditoria de desempate e segurança de notas',
      'Publicação com 1 clique do placar final',
    ],
  },
  {
    id: 'mentores',
    label: 'Mentores & Facilitadores',
    icon: '💡',
    tagline: 'Facilitação guiada com histórico de atendimentos e feedbacks',
    description: 'Fila dinâmica de auxílio. Os mentores visualizam quem precisa de ajuda, quais blocos do canvas estão sendo trabalhados e oferecem orientações precisas sem sobreposição de atendimentos.',
    benefits: [
      'Fila organizada por ordem de chegada ou urgência',
      'Acesso direto aos blocos do canvas da equipe',
      'Histórico de feedbacks de checkpoints anteriores',
      'Conexão ágil entre teoria e prática de mercado',
    ],
  },
  {
    id: 'jurados',
    label: 'Avaliadores & Jurados',
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
      <h2 id="roles-title">Uma experiência pensada para cada ator da maratona</h2>
      <p class="section-copy">
        Hackathons de sucesso dependem da sinergia entre organizadores, participantes, mentores e jurados. O Ligalab oferece interfaces dedicadas para cada função.
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
