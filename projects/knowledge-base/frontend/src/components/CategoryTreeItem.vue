<template>
  <div class="tree-item">
    <div
      class="tree-row"
      :style="{ paddingLeft: `${depth * 20 + 8}px` }"
    >
      <!-- 折叠箭头（有子节点时显示） -->
      <span
        v-if="node.children?.length"
        class="toggle-arrow"
        @click.stop="expanded = !expanded"
      >{{ expanded ? '▼' : '▶' }}</span>
      <span v-else class="toggle-arrow placeholder"></span>

      <label class="tree-label" @click.prevent>
        <input
          type="radio"
          :value="node.id"
          :checked="modelValue === node.id"
          @change="select(node.id)"
        />
        <span class="tree-icon">{{ node.children?.length ? '📂' : '📄' }}</span>
        {{ node.name }}
      </label>
    </div>

    <!-- 递归子节点 -->
    <div v-if="expanded && node.children?.length" class="tree-children">
      <CategoryTreeItem
        v-for="child in node.children"
        :key="child.id"
        :node="child"
        :depth="depth + 1"
        :model-value="modelValue"
        @update:model-value="$emit('update:modelValue', $event)"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import type { CategoryDTO } from '@/types/api'

const props = withDefaults(defineProps<{
  node: CategoryDTO
  depth?: number
  modelValue: number | null
}>(), {
  depth: 0,
})

const emit = defineEmits<{
  'update:modelValue': [value: number | null]
}>()

const expanded = ref(true)

function select(id: number) {
  emit('update:modelValue', id)
}
</script>

<style scoped>
.tree-item {
  margin-bottom: 2px;
}

.tree-row {
  display: flex;
  align-items: center;
  gap: 4px;
  padding-top: 2px;
  padding-bottom: 2px;
  padding-right: 8px;
  border-radius: 4px;
  transition: background 0.15s;
}

.tree-row:hover {
  background: #f5f6fa;
}

.toggle-arrow {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 16px;
  height: 16px;
  font-size: 10px;
  color: #888;
  cursor: pointer;
  flex-shrink: 0;
  user-select: none;
}

.toggle-arrow.placeholder {
  visibility: hidden;
}

.tree-label {
  display: flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
  font-size: 14px;
}

.tree-icon {
  font-size: 14px;
}

.tree-label input[type="radio"] {
  accent-color: #4361ee;
}
</style>
