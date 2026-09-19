<script setup lang="ts">
import BrandLogo from '../brand/BrandLogo.vue'
import PlatformHeader from './PlatformHeader.vue'
</script>

<template>
  <div class="landing-page ligalab-home">
    <a class="skip-link" href="#conteudo-principal">Pular para o conteúdo</a>
    <PlatformHeader />
    <main id="conteudo-principal" tabindex="-1">
      <section class="ligalab-home__hero">
        <div class="ligalab-home__copy">
          <p class="eyebrow">Aprendizagem que ganha vida</p>
          <h1>Uma plataforma para transformar desafios em aprendizagem.</h1>
          <p>O Ligalab reúne eventos, equipes e ideias para que estudantes possam criar, colaborar e apresentar soluções com impacto.</p>
          <NuxtLink class="primary-cta" to="/eventos">Explorar eventos</NuxtLink>
        </div>
        <BrandLogo variant="light" />
      </section>
      <section class="landing-section ligalab-home__principles" aria-labelledby="principles-title">
        <p class="section-index">Como funciona</p>
        <h2 id="principles-title">Do desafio à solução, em comunidade.</h2>
        <div class="ligalab-home__principle-grid">
          <article><h3>Participe</h3><p>Inscreva-se em um evento e encontre sua equipe.</p></article>
          <article><h3>Construa</h3><p>Organize ideias e desenvolva sua proposta no canvas.</p></article>
          <article><h3>Compartilhe</h3><p>Receba feedback e apresente o que sua equipe criou.</p></article>
        </div>
      </section>
    </main>
    <footer class="landing-footer ligalab-footer"><BrandLogo variant="dark" decorative /><p>Ligalab — desafios que conectam pessoas e possibilidades.</p></footer>
  </div>
</template>
