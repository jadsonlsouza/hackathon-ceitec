export type PublicScheduleItem = {
  dayNumber: 1 | 2
  startsAt: string
  activity: string
  position: number
}

export type PublishedCategoryResult = {
  event_name: string
  event_slug: string
  category: 'junior' | 'senior'
  ranking: Array<{ position: number, team_name: string, score: number }>
  published_at: string
}

export type PublicEventContent = {
  event_name: string
  event_slug: string
  tagline: string
  presentation: string
  objectives: string[]
  venue: string
  date_label: string
  registration_open: boolean
  schedule: PublicScheduleItem[]
  results: PublishedCategoryResult[]
}

export const ceitecPublicContent: PublicEventContent = {
  event_name: 'Hackathon CEITEC',
  event_slug: 'hackathon-ceitec',
  tagline: 'Criando soluções, conectando o futuro.',
  presentation: 'O Hackathon CEITEC é um evento de dois dias que visa estimular a resolução criativa de problemas relacionados à tecnologia e à sustentabilidade. Participantes de diversas faixas etárias colaboram em grupos para desenvolver soluções tecnológicas inovadoras, vivenciando a rotina de uma verdadeira startup.',
  objectives: [
    'Inovação: Promover a criatividade no desenvolvimento de tecnologias sustentáveis.',
    'Trabalho em Equipe: Estimular a colaboração interdisciplinar entre os alunos.',
    'Prática Educativa: Proporcionar uma imersão real no campo do desenvolvimento e tecnologia.',
  ],
  venue: 'CAC - CEI Roberto Freire',
  date_label: '24 e 25 de julho',
  registration_open: true,
  schedule: [
    { dayNumber: 1, startsAt: '14:00', activity: 'Chegada e credenciamento', position: 1 },
    { dayNumber: 1, startsAt: '14:30', activity: 'Abertura oficial + explicação do Hackathon', position: 2 },
    { dayNumber: 1, startsAt: '15:40', activity: 'Pausa para lanche + networking', position: 3 },
    { dayNumber: 1, startsAt: '16:00', activity: 'Dinâmica de ideação guiada (5W2H)', position: 4 },
    { dayNumber: 1, startsAt: '17:00', activity: 'Checkpoint com mentores (pitch 3 min por equipe) e Desenvolvimento inicial', position: 5 },
    { dayNumber: 1, startsAt: '18:00', activity: 'Encerramento do Dia 1', position: 6 },
    { dayNumber: 2, startsAt: '07:15', activity: 'Acolhimento + energização', position: 1 },
    { dayNumber: 2, startsAt: '07:30', activity: 'Recall do dia anterior', position: 2 },
    { dayNumber: 2, startsAt: '08:00', activity: 'Trilhas simultâneas:\nFundamental: Protótipos com IA (CAC) / Protótipos com Hardware / Designs que impressionam / Apresentando minha ideia\nMédio: Startup (negócio + pitch + validação)', position: 3 },
    { dayNumber: 2, startsAt: '09:00', activity: 'Desenvolvimento guiado dos projetos', position: 4 },
    { dayNumber: 2, startsAt: '10:00', activity: 'Intervalo para lanche', position: 5 },
    { dayNumber: 2, startsAt: '10:20', activity: 'Continuação do desenvolvimento', position: 6 },
    { dayNumber: 2, startsAt: '11:30', activity: 'Pré-pitch com mentores (simulação)', position: 7 },
    { dayNumber: 2, startsAt: '12:15', activity: 'Intervalo para almoço', position: 8 },
    { dayNumber: 2, startsAt: '13:15', activity: 'Preparação final dos pitches', position: 9 },
    { dayNumber: 2, startsAt: '14:00', activity: 'Apresentações dos projetos', position: 10 },
    { dayNumber: 2, startsAt: '16:30', activity: 'Deliberação dos jurados', position: 11 },
    { dayNumber: 2, startsAt: '17:15', activity: 'Cerimônia de encerramento e premiação', position: 12 },
  ],
  results: [],
}
