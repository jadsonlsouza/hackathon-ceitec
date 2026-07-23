import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import HeroSection from '../../app/components/landing/HeroSection.vue'
import PublicResults from '../../app/components/landing/PublicResults.vue'
import ScheduleSection from '../../app/components/landing/ScheduleSection.vue'

const NuxtLink = {
  props: ['to'],
  template: '<a :href="to"><slot /></a>',
}

describe('public landing components', () => {
  it('renders one accessible hero identity and both calls to action', () => {
    const wrapper = mount(HeroSection, {
      props: {
        eventName: 'Hackathon CEITEC',
        tagline: 'Criando soluções, conectando o futuro.',
        registrationOpen: true,
      },
      global: { stubs: { NuxtLink } },
    })

    expect(wrapper.findAll('h1')).toHaveLength(1)
    expect(wrapper.get('img').attributes()).toMatchObject({
      alt: 'CEITEC',
      width: '1029',
      height: '252',
    })
    expect(wrapper.get('a[href="/cadastro"]').text()).toContain('Inscreva-se')
    expect(wrapper.get('a[href="/login"]').text()).toContain('Entrar')
  })

  it('uses real table semantics and preserves multiline track detail', () => {
    const wrapper = mount(ScheduleSection, {
      props: {
        items: [
          { dayNumber: 1, startsAt: '14:00', activity: 'Credenciamento', position: 1 },
          {
            dayNumber: 2,
            startsAt: '08:00',
            activity: 'Trilhas simultâneas:\nFundamental: IA\nMédio: Startup',
            position: 1,
          },
        ],
      },
    })

    expect(wrapper.findAll('table')).toHaveLength(2)
    expect(wrapper.findAll('th[scope="col"]')).toHaveLength(4)
    expect(wrapper.text()).toContain('Fundamental: IA')
    expect(wrapper.text()).toContain('Médio: Startup')
  })

  it('renders no results section until a sanitized snapshot exists', async () => {
    const wrapper = mount(PublicResults, {
      props: { eventSlug: 'hackathon-ceitec', results: [] },
      global: { stubs: { NuxtLink } },
    })

    expect(wrapper.html()).toBe('<!--v-if-->')
    await wrapper.setProps({
      results: [{
        event_name: 'Hackathon CEITEC',
        event_slug: 'hackathon-ceitec',
        category: 'junior',
        ranking: [{ position: 1, team_name: 'Equipe A', score: 4.8 }],
        published_at: '2026-07-25T17:15:00Z',
      }],
    })
    expect(wrapper.get('[data-public-ranking]').text()).toContain('Equipe A')
    expect(wrapper.get('a').attributes('href')).toBe('/resultados/hackathon-ceitec')
  })
})
