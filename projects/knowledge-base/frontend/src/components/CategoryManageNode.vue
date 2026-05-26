<template>
  <div class="manage-node">
    <div
      class="node-row"
      :style="{ paddingLeft: `${depth * 20 + 12}px` }"
    >
      <span
        v-if="node.children?.length"
        class="toggle-arrow"
        @click.stop="expanded = !expanded"
      >{{ expanded ? '▼' : '▶' }}</span>
      <span v-else class="toggle-arrow placeholder"></span>

      <span class="node-icon">{{ node.children?.length ? '📂' : '📄' }}</span>
      <span class="node-name">{{ node.name }}</span>
      <span class="node-slug">{{ node.slug }}</span>
      <span class="node-count" v-if="node.children?.length">{{ node.children.length }} 子分类</span>
      <div class="node-actions">
        <button class="btn-text" @click="$emit('edit', node)">编辑</button>
        <button class="btn-text" @click="$emit('manage-perm', node)">🔐 权限</button>
        <button class="btn-text btn-text-danger" @click="$emit('delete', node)">删除</button>
      </div>
    </div>
    <div v-if="expanded && node.children?.length">
      <CategoryManageNode
        v-for="child in node.children"
        :key="child.id"
        :node="child"
        :depth="depth + 1"
        @edit="$emit('edit', $event)"
        @delete="$emit('delete', $event)"
        @manage-perm="$emit('manage-perm', $event)"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import type { CategoryDTO } from '@/types/api'

withDefaults(defineProps<{
  node: CategoryDTO
  depth?: number
}>(), { depth: 0 })

defineEmits<{
  edit: [node: CategoryDTO]
  delete: [node: CategoryDTO]
  'manage-perm': [node: CategoryDTO]
}>()

const expanded = ref(true)
</script>

<style scoped>
.manage-node { margin-bottom: 4px; }

.node-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding-top: 8px;
  padding-bottom: 8px;
  padding-right: 12px;
  border-radius: 4px;
  transition: background 0.15s;
}
.node-row:hover { background: #f5f6fa; }

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
.toggle-arrow.placeholder { visibility: hidden; }

.node-icon { font-size: 14px; }
.node-name { font-weight: 500; font-size: 14px; }
.node-slug { font-size: 12px; color: #999; }
.node-count { font-size: 12px; color: #888; }

.node-actions {
  margin-left: auto;
  display: flex;
  gap: 8px;
}
.btn-text {
  background: none; border: none; color: #888;
  font-size: 12px; cursor: pointer;
}
.btn-text:hover { color: #4361ee; }
.btn-text-danger:hover { color: #e63946; }
</style>
