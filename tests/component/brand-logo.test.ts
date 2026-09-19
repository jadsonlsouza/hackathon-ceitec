import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import BrandLogo from '../../app/components/brand/BrandLogo.vue'
import PlatformHeader from '../../app/components/landing/PlatformHeader.vue'

const NuxtLink = {
  props: ['to'],
  template: '<a :href="to"><slot /></a>',
}

describe('Ligalab brand and public navigation', () => {
  it('renders the white horizontal Ligalab logo with a readable platform name', () => {
    const wrapper = mount(BrandLogo, { props: { variant: 'dark' } })
    expect(wrapper.get('img').attributes()).toMatchObject({
      src: '/brand/ligalab-horizontal-white.png',
      alt: 'ligalab',
      width: '2172',
      height: '724',
    })
  })

  it('uses the color logo as decorative artwork when a visible name accompanies it', () => {
    const wrapper = mount(BrandLogo, { props: { variant: 'light', decorative: true } })
    expect(wrapper.get('img').attributes('src')).toBe('/brand/ligalab-color.png')
    expect(wrapper.get('img').attributes('alt')).toBe('')
  })

  it('keeps Eventos focused while changing the platform theme', async () => {
    const wrapper = mount(PlatformHeader, {
      attachTo: document.body,
      global: { stubs: { NuxtLink } },
    })
    const events = wrapper.get('a[href="/eventos"]')
    ;(events.element as HTMLAnchorElement).focus()
    await wrapper.get('button[aria-label="Alternar tema"]').trigger('click')

    expect(document.activeElement).toBe(events.element)
    expect(wrapper.attributes('data-theme')).toBe('light')
    expect(wrapper.get('a[href="/login"]').text()).toBe('Entrar')
    expect(wrapper.get('a[href="/cadastro"]').text()).toContain('Cadastrar')
    wrapper.unmount()
  })
})
