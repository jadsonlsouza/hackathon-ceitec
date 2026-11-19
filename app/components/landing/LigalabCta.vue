<script setup lang="ts">
</script>

<template>
  <section class="landing-section ligalab-cta-section" aria-labelledby="cta-banner-title">
    <div class="ligalab-cta-card">
      <div class="ligalab-cta-glow" aria-hidden="true" />
      <div class="ligalab-cta-content">
        <span class="eyebrow">Participe</span>
        <h2 id="cta-banner-title">Encontre seu próximo evento</h2>
        <p class="section-copy">
          Consulte os eventos disponíveis e acesse sua conta para participar com sua equipe.
        </p>
        <div class="hero-actions">
          <NuxtLink class="primary-cta" to="/eventos">Ver eventos</NuxtLink>
          <NuxtLink class="secondary-cta" to="/login">Acessar minha conta</NuxtLink>
        </div>
      </div>
    </div>
  </section>
</template>
