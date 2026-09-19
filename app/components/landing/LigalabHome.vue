<script setup lang="ts">
import BrandLogo from '../brand/BrandLogo.vue'
import PlatformHeader from './PlatformHeader.vue'
import LigalabMetrics from './LigalabMetrics.vue'
import LigalabPartners from './LigalabPartners.vue'
import LigalabForma from './LigalabForma.vue'
import LigalabFeatures from './LigalabFeatures.vue'
import LigalabRoles from './LigalabRoles.vue'
import LigalabTheory from './LigalabTheory.vue'
import LigalabFaq from './LigalabFaq.vue'
import LigalabCta from './LigalabCta.vue'
</script>

<template>
  <div class="landing-page ligalab-home">
    <a class="skip-link" href="#conteudo-principal">Pular para o conteúdo</a>
    <PlatformHeader :show-theme-toggle="false" initial-theme="light" />

    <main id="conteudo-principal" tabindex="-1">
      <!-- Hero Section Tecnológico -->
      <section class="ligalab-home__hero">
        <div class="ligalab-home__copy">
          <p class="eyebrow">Liga de Empreendedorismo e Inovação</p>
          <h1>Uma plataforma para transformar desafios em aprendizagem.</h1>
          <p class="ligalab-home__lead">
            O Ligalab é o ecossistema tecnológico completo para planejar, gerenciar e avaliar maratonas de ideação e hackathons. Unindo metodologias ativas ao rigor acadêmico, conectamos estudantes, mentores e jurados em uma experiência ágil e transformadora.
          </p>
          <div class="hero-actions">
            <NuxtLink class="primary-cta" to="/eventos">Explorar eventos</NuxtLink>
            <a class="secondary-cta" href="#metodologia-forma">Conhecer Metodologia FORMA</a>
          </div>
        </div>

        <div class="ligalab-home__hero-visual">
          <div class="ligalab-brand-wrapper">
            <BrandLogo variant="light" />
          </div>

          <!-- Cockpit / Radar Telemetria Tecnológico -->
          <div class="hero-cockpit" aria-hidden="true">
            <div class="cockpit-header">
              <span class="cockpit-dot" />
              <span class="cockpit-title">LIGALAB TELEMETRY // LIVE</span>
            </div>
            <div class="cockpit-grid">
              <div class="cockpit-tile">
                <span class="cockpit-label">Gestão de Equipes</span>
                <span class="cockpit-value">100% Ágil</span>
              </div>
              <div class="cockpit-tile">
                <span class="cockpit-label">Canvas Colaborativo</span>
                <span class="cockpit-value">Autosave Ativo</span>
              </div>
              <div class="cockpit-tile">
                <span class="cockpit-label">Fila de Mentoria</span>
                <span class="cockpit-value">Zero Gargalos</span>
              </div>
              <div class="cockpit-tile">
                <span class="cockpit-label">Critérios de Avaliação</span>
                <span class="cockpit-value">Notas Auditadas</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Faixa de Métricas e Pilares -->
      <LigalabMetrics />

      <!-- Realização & Apoio Institucional (Liga, IMD, UFRN) -->
      <LigalabPartners />

      <!-- Metodologia Framework FORMA -->
      <LigalabForma />

      <!-- Bento Grid de Recursos Tecnológicos -->
      <LigalabFeatures />

      <!-- Experiência Multi-Papel -->
      <LigalabRoles />

      <!-- Fundamentação Teórica e DNA da Liga -->
      <LigalabTheory />

      <!-- Perguntas Frequentes (FAQ) -->
      <LigalabFaq />

      <!-- Banner Final de Conversão -->
      <LigalabCta />
    </main>

    <footer class="landing-footer ligalab-footer">
      <div class="ligalab-footer-content">
        <div class="ligalab-footer-brand-col">
          <BrandLogo variant="dark" decorative />
          <p>Ligalab — Sistema Operacional de Hackathons desenvolvido com a metodologia da Liga de Empreendedorismo e Inovação.</p>
        </div>

        <div class="ligalab-footer-partners">
          <span class="footer-partners-title">Apoio & Realização Institucional:</span>
          <div class="footer-partners-row">
            <div class="footer-partner-chip" title="Liga de Empreendedorismo e Inovação">
              <img src="/brand/liga-inovacao.png" alt="Liga de Empreendedorismo e Inovação" width="1024" height="839">
            </div>
            <div class="footer-partner-chip" title="Instituto Metrópole Digital — IMD">
              <img src="/brand/metropole-digital.png" alt="Instituto Metrópole Digital — IMD" width="1024" height="248">
            </div>
            <div class="footer-partner-chip" title="Universidade Federal do Rio Grande do Norte — UFRN">
              <img src="/brand/ufrn.png" alt="Universidade Federal do Rio Grande do Norte — UFRN" width="594" height="188">
            </div>
          </div>
        </div>

        <div class="ligalab-footer-links">
          <NuxtLink to="/eventos">Catálogo de Eventos</NuxtLink>
          <NuxtLink to="/login">Entrar</NuxtLink>
          <NuxtLink to="/cadastro">Cadastrar-se</NuxtLink>
        </div>
      </div>
    </footer>
  </div>
</template>
