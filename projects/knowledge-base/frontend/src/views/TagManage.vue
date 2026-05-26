<template>
  <div class="tag-manage">
    <div class="page-header">
      <h2>标签管理</h2>
      <button class="btn btn-primary" @click="openCreate()">+ 新建标签</button>
    </div>

    <div class="card">
      <div v-if="loading" class="loading">加载中...</div>
      <table v-else-if="tags.length" class="data-table">
        <thead>
          <tr>
            <th>名称</th>
            <th>颜色</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="tag in tags" :key="tag.id">
            <td>
              <span v-if="tag.color" class="color-dot" :style="{ background: tag.color }"></span>
              {{ tag.name }}
            </td>
            <td>
              <span v-if="tag.color" class="color-badge" :style="{ background: tag.color + '22', color: tag.color }">
                {{ tag.color }}
              </span>
              <span v-else class="color-none">未设置</span>
            </td>
            <td class="actions">
              <button class="btn-text" @click="openEdit(tag)">编辑</button>
              <button class="btn-text btn-text-danger" @click="handleDelete(tag)">删除</button>
            </td>
          </tr>
        </tbody>
      </table>
      <div v-else class="empty-state">暂无标签</div>
    </div>

    <!-- 编辑弹窗 -->
    <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
      <div class="modal">
        <h3>{{ editingId ? '编辑标签' : '新建标签' }}</h3>
        <div class="form-group">
          <label>名称</label>
          <input v-model="form.name" class="form-input" placeholder="标签名称" maxlength="64" />
        </div>
        <div class="form-group">
          <label>颜色（可选）</label>
          <div class="color-input-row">
            <input v-model="form.color" class="form-input" placeholder="#4361ee 或 red" maxlength="16" />
            <span v-if="form.color" class="color-preview" :style="{ background: form.color }"></span>
          </div>
        </div>
        <div class="modal-actions">
          <button class="btn btn-ghost" @click="showModal = false">取消</button>
          <button class="btn btn-primary" @click="handleSave" :disabled="!form.name.trim()">保存</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import type { TagDTO } from '@/types/api'
import { getTags, createTag, updateTag, deleteTag } from '@/api/tag'

const tags = ref<TagDTO[]>([])
const loading = ref(false)
const showModal = ref(false)
const editingId = ref<number | null>(null)

const form = ref({ name: '', color: '' })

onMounted(loadTags)

async function loadTags() {
  loading.value = true
  try {
    const { data: res } = await getTags()
    tags.value = res.data
  } catch (e) {
    console.error('加载标签失败:', e)
  } finally {
    loading.value = false
  }
}

function openCreate() {
  editingId.value = null
  form.value = { name: '', color: '' }
  showModal.value = true
}

function openEdit(tag: TagDTO) {
  editingId.value = tag.id
  form.value = { name: tag.name, color: tag.color || '' }
  showModal.value = true
}

async function handleSave() {
  try {
    if (editingId.value) {
      await updateTag(editingId.value, form.value)
    } else {
      await createTag(form.value)
    }
    showModal.value = false
    await loadTags()
  } catch (e: any) {
    alert(e.response?.data?.message || '保存失败')
  }
}

async function handleDelete(tag: TagDTO) {
  if (!confirm(`确定删除标签「${tag.name}」？`)) return
  try {
    await deleteTag(tag.id)
    await loadTags()
  } catch (e: any) {
    alert(e.response?.data?.message || '删除失败')
  }
}
</script>

<style scoped>
.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16px;
}

.card {
  background: white;
  padding: 20px;
  border-radius: 8px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.08);
}

.data-table {
  width: 100%;
  border-collapse: collapse;
}

.data-table th, .data-table td {
  padding: 10px 12px;
  text-align: left;
  border-bottom: 1px solid #f0f0f0;
  font-size: 14px;
}

.data-table th {
  font-weight: 600;
  color: #666;
  font-size: 13px;
}

.color-dot {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  margin-right: 6px;
}

.color-badge {
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 12px;
}

.color-none { color: #ccc; font-size: 12px; }

.actions { white-space: nowrap; }

.btn-text {
  background: none;
  border: none;
  color: #888;
  font-size: 12px;
  cursor: pointer;
  margin-right: 8px;
}

.btn-text:hover { color: #4361ee; }
.btn-text-danger:hover { color: #e63946; }

.modal-overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.4);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal {
  background: white;
  padding: 24px;
  border-radius: 8px;
  width: 400px;
}

.modal h3 { margin-bottom: 16px; }

.color-input-row {
  display: flex;
  align-items: center;
  gap: 8px;
}

.color-preview {
  width: 24px;
  height: 24px;
  border-radius: 4px;
  border: 1px solid #eee;
  flex-shrink: 0;
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 16px;
}

.loading, .empty-state {
  color: #999;
  font-size: 14px;
  text-align: center;
  padding: 20px;
}
</style>
