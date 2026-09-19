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

export type PublicEventCard = {
  event_name: string
  event_slug: string
  tagline: string
  venue: string
  date_label: string
  registration_open: boolean
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
