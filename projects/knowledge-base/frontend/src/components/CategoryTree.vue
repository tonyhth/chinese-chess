<template>
  <div class="category-tree">
    <CategoryTreeItem
      v-for="cat in tree"
      :key="cat.id"
      :node="cat"
      :depth="0"
      :model-value="modelValue"
      @update:model-value="$emit('update:modelValue', $event)"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import type { CategoryDTO } from '@/types/api'
import { getCategoryTree } from '@/api/category'
import CategoryTreeItem from './CategoryTreeItem.vue'

const props = defineProps<{
  modelValue: number | null
}>()

const emit = defineEmits<{
  'update:modelValue': [value: number | null]
}>()

const allCategories = ref<CategoryDTO[]>([])
const tree = computed(() => allCategories.value)

onMounted(async () => {
  try {
    const { data: res } = await getCategoryTree()
    allCategories.value = res.data
  } catch (e) {
    console.error('加载分类失败:', e)
  }
})
</script>

<style scoped>
.category-tree {
  padding: 4px 0;
}
</style>
