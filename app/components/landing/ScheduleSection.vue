<script setup lang="ts">
import type { PublicScheduleItem } from '~/data/ceitec-public-content'

const props = defineProps<{ items: PublicScheduleItem[] }>()
const day = (dayNumber: 1 | 2) => props.items
  .filter(item => item.dayNumber === dayNumber)
  .sort((a, b) => a.position - b.position)
</script>

<template>
  <section id="programacao" class="landing-section" aria-labelledby="schedule-title">
    <p class="section-index">03 — Programação</p>
    <h2 id="schedule-title">Dois dias para construir o extraordinário</h2>
    <div class="schedule-grid">
      <article v-for="dayNumber in [1, 2] as const" :key="dayNumber" class="schedule-day">
        <h3>
          Dia {{ dayNumber }} —
          {{ dayNumber === 1 ? 'Imersão e ideação' : 'Desenvolvimento e apresentação' }}
        </h3>
        <div class="table-scroll">
          <table>
            <thead><tr><th scope="col">Horário</th><th scope="col">Atividade</th></tr></thead>
            <tbody>
              <tr v-for="item in day(dayNumber)" :key="item.position">
                <th scope="row"><time :datetime="item.startsAt">{{ item.startsAt }}</time></th>
                <td class="schedule-activity">{{ item.activity }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </article>
    </div>
  </section>
</template>
