<script setup lang="ts">
defineProps<{
  title: string
  value: string
  status: string
  state: 'pending' | 'empty' | 'error' | 'ready'
  actionLabel: string
  actionTo: string
}>()
</script>

<template>
  <article class="status-card" :data-card-status="state">
    <h2>{{ title }}</h2>
    <p class="status-card-value">
      {{ value }}
    </p>
    <p
      class="status-card-copy"
      :role="state === 'error' ? 'alert' : 'status'"
    >
      {{ status }}
    </p>
    <NuxtLink data-card-action :to="actionTo">
      {{ actionLabel }}
    </NuxtLink>
  </article>
</template>
