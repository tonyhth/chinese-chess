<template>
  <div v-if="total > pageSize" class="pagination">
    <button class="btn btn-ghost btn-sm" :disabled="currentPage <= 1" @click="change(currentPage - 1)">
      ‹ 上一页
    </button>
    <span class="page-info">
      {{ currentPage }} / {{ totalPages }}
    </span>
    <button class="btn btn-ghost btn-sm" :disabled="currentPage >= totalPages" @click="change(currentPage + 1)">
      下一页 ›
    </button>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  currentPage: number
  pageSize: number
  total: number
}>()

const emit = defineEmits<{
  'update:currentPage': [value: number]
}>()

const totalPages = computed(() => Math.ceil(props.total / props.pageSize))

function change(page: number) {
  if (page < 1 || page > totalPages.value) return
  emit('update:currentPage', page)
}
</script>

<style scoped>
.pagination {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  margin-top: 16px;
  padding: 12px 0;
}

.page-info {
  font-size: 14px;
  color: #666;
}

.btn-sm {
  padding: 4px 12px;
  font-size: 13px;
}

.btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}
</style>
