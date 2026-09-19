<script setup lang="ts">
withDefaults(defineProps<{
  variant: 'light' | 'dark'
  decorative?: boolean
}>(), {
  decorative: false,
})

const assets = {
  dark: { src: '/brand/ligalab-horizontal-white.png', width: 2172, height: 724 },
  light: { src: '/brand/ligalab-color.png', width: 1254, height: 1254 },
} as const
</script>

<template>
  <img
    class="brand-logo"
    :class="`brand-logo--${variant}`"
    :src="assets[variant].src"
    :alt="decorative ? '' : 'ligalab'"
    :width="assets[variant].width"
    :height="assets[variant].height"
  >
</template>
