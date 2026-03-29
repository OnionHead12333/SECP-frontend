<template>
  <section class="card">
    <h2>服务状态</h2>
    <p v-if="loading">正在检测后端…</p>
    <p v-else-if="error" class="error">{{ error }}</p>
    <pre v-else class="json">{{ display }}</pre>
  </section>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { fetchHealth } from '@/api/health'

const loading = ref(true)
const error = ref('')
const data = ref(null)

const display = computed(() => (data.value ? JSON.stringify(data.value, null, 2) : ''))

onMounted(async () => {
  try {
    data.value = await fetchHealth()
  } catch (e) {
    error.value = e.message || String(e)
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.card {
  background: #fff;
  border-radius: 8px;
  padding: 1.25rem 1.5rem;
  border: 1px solid #e8e8e8;
}
.card h2 {
  margin: 0 0 1rem;
  font-size: 1rem;
}
.error {
  color: #b91c1c;
  margin: 0;
}
.json {
  margin: 0;
  padding: 1rem;
  background: #f8fafc;
  border-radius: 6px;
  font-size: 0.875rem;
  overflow-x: auto;
}
</style>
