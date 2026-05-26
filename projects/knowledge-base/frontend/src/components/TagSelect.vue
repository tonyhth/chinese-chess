<template>
  <div class="tag-select">
    <div class="tag-selected">
      <span v-for="tag in selected" :key="tag.id" class="tag-chip">
        {{ tag.name }}
        <button class="tag-remove" @click="remove(tag.id)">&times;</button>
      </span>
      <input
        v-model="keyword"
        class="tag-input"
        placeholder="搜索标签..."
        @focus="showDropdown = true"
        @blur="hideDropdown"
      />
    </div>
    <ul v-if="showDropdown && filteredOptions.length" class="tag-dropdown">
      <li
        v-for="tag in filteredOptions"
        :key="tag.id"
        class="tag-option"
        @mousedown.prevent="add(tag)"
      >
        <span v-if="tag.color" class="tag-dot" :style="{ background: tag.color }"></span>
        {{ tag.name }}
      </li>
    </ul>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import type { TagDTO } from '@/types/api'
import { getTags } from '@/api/tag'

const props = defineProps<{
  modelValue: TagDTO[]
}>()

const emit = defineEmits<{
  'update:modelValue': [value: TagDTO[]]
}>()

const allTags = ref<TagDTO[]>([])
const keyword = ref('')
const showDropdown = ref(false)

const selected = computed(() => props.modelValue)

const filteredOptions = computed(() => {
  const selectedIds = new Set(selected.value.map(t => t.id))
  const kw = keyword.value.toLowerCase()
  return allTags.value.filter(
    t => !selectedIds.has(t.id) && (!kw || t.name.toLowerCase().includes(kw))
  )
})

onMounted(async () => {
  try {
    const { data: res } = await getTags()
    allTags.value = res.data
  } catch (e) {
    console.error('加载标签失败:', e)
  }
})

function add(tag: TagDTO) {
  emit('update:modelValue', [...selected.value, tag])
  keyword.value = ''
}

function remove(id: number) {
  emit('update:modelValue', selected.value.filter(t => t.id !== id))
}

function hideDropdown() {
  setTimeout(() => { showDropdown.value = false }, 150)
}
</script>

<style scoped>
.tag-select {
  position: relative;
}

.tag-selected {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  padding: 6px 10px;
  border: 1px solid #ddd;
  border-radius: 6px;
  min-height: 38px;
  align-items: center;
}

.tag-selected:focus-within {
  border-color: #4361ee;
}

.tag-chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 8px;
  background: #eef0ff;
  color: #4361ee;
  border-radius: 4px;
  font-size: 13px;
}

.tag-remove {
  background: none;
  border: none;
  color: #999;
  cursor: pointer;
  font-size: 16px;
  line-height: 1;
  padding: 0 2px;
}

.tag-remove:hover {
  color: #e63946;
}

.tag-input {
  flex: 1;
  min-width: 80px;
  border: none;
  outline: none;
  font-size: 14px;
  padding: 2px 0;
}

.tag-dropdown {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  z-index: 100;
  background: white;
  border: 1px solid #ddd;
  border-radius: 6px;
  max-height: 200px;
  overflow-y: auto;
  margin-top: 4px;
  list-style: none;
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

.tag-option {
  padding: 8px 12px;
  cursor: pointer;
  font-size: 14px;
  display: flex;
  align-items: center;
  gap: 6px;
}

.tag-option:hover {
  background: #f5f6fa;
}

.tag-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
}
</style>
