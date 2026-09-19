<script setup lang="ts">
import { ref } from 'vue'
import BrandLogo from '../brand/BrandLogo.vue'

const theme = ref<'dark' | 'light'>('dark')

function toggleTheme() {
  theme.value = theme.value === 'dark' ? 'light' : 'dark'
}
</script>

<template>
  <header class="platform-header" :data-theme="theme">
    <nav aria-label="Navegação principal" class="platform-header__nav">
      <NuxtLink to="/" aria-label="Página inicial do ligalab">
        <BrandLogo variant="dark" />
      </NuxtLink>
      <div class="platform-header__actions">
        <NuxtLink to="/eventos">Eventos</NuxtLink>
        <NuxtLink to="/login">Entrar</NuxtLink>
        <NuxtLink to="/cadastro">Cadastrar-se</NuxtLink>
        <button type="button" aria-label="Alternar tema" @click="toggleTheme">
          {{ theme === 'dark' ? 'Claro' : 'Escuro' }}
        </button>
      </div>
    </nav>
  </header>
</template>
