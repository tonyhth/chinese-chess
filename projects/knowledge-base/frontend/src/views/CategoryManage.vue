<template>
  <div class="category-manage">
    <div class="page-header">
      <h2>分类管理</h2>
      <button class="btn btn-primary" @click="openCreate()">+ 新建分类</button>
    </div>

    <!-- 树形展示 -->
    <div class="card">
      <div v-if="loading" class="loading">加载中...</div>
      <div v-else-if="tree.length === 0" class="empty-state">暂无分类</div>
      <div v-else class="tree-view">
        <CategoryManageNode
          v-for="cat in tree"
          :key="cat.id"
          :node="cat"
          :depth="0"
          @edit="openEdit"
          @delete="handleDelete"
          @manage-perm="openPermDialog"
        />
      </div>
    </div>

    <!-- 编辑弹窗 -->
    <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
      <div class="modal">
        <h3>{{ editingId ? '编辑分类' : '新建分类' }}</h3>
        <div class="form-group">
          <label>名称</label>
          <input v-model="form.name" class="form-input" placeholder="分类名称" maxlength="128" />
        </div>
        <div class="form-group">
          <label>Slug（URL 路径）</label>
          <input v-model="form.slug" class="form-input" placeholder="如 tech, backend" maxlength="128" />
        </div>
        <div class="form-group" v-if="allCategoriesFlat.length">
          <label>父分类</label>
          <select v-model="form.parentId" class="form-input">
            <option :value="null">无（根分类）</option>
            <option
              v-for="cat in allCategoriesFlat"
              :key="cat.id"
              :value="cat.id"
              :disabled="cat.id === editingId"
            >{{ cat.name }}</option>
          </select>
        </div>
        <div class="form-group">
          <label>描述（可选）</label>
          <input v-model="form.description" class="form-input" placeholder="简要描述" maxlength="512" />
        </div>
        <div class="modal-actions">
          <button class="btn btn-ghost" @click="showModal = false">取消</button>
          <button class="btn btn-primary" @click="handleSave" :disabled="!form.name.trim()">保存</button>
        </div>
      </div>
    </div>

    <!-- 分类权限管理弹窗 -->
    <PermissionDialog
      :visible="showPermDialog"
      title="分类"
      resource-type="category"
      :resource-id="permCategoryId"
      :load-fn="getCategoryPermissions"
      :set-fn="setCategoryPermissions"
      :remove-fn="removeCategoryPermission"
      @close="showPermDialog = false"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import type { CategoryDTO } from '@/types/api'
import { useAbort } from '@/composables/useAbort'

useAbort('/categories')
import { getCategoryTree, createCategory, updateCategory, deleteCategory } from '@/api/category'
import CategoryManageNode from '@/components/CategoryManageNode.vue'
import PermissionDialog from '@/components/PermissionDialog.vue'
import { getCategoryPermissions, setCategoryPermissions, removeCategoryPermission } from '@/api/permission'

const tree = ref<CategoryDTO[]>([])
const loading = ref(false)
const showModal = ref(false)
const editingId = ref<number | null>(null)
const showPermDialog = ref(false)
const permCategoryId = ref(0)

const form = ref({
  name: '',
  slug: '',
  description: '',
  parentId: null as number | null,
})

const allCategoriesFlat = computed(() => {
  const result: CategoryDTO[] = []
  function walk(nodes: CategoryDTO[]) {
    for (const node of nodes) {
      result.push(node)
      if (node.children?.length) walk(node.children)
    }
  }
  walk(tree.value)
  return result
})

onMounted(loadTree)

async function loadTree() {
  loading.value = true
  try {
    const { data: res } = await getCategoryTree()
    tree.value = res.data
  } catch (e) {
    console.error('加载分类失败:', e)
  } finally {
    loading.value = false
  }
}

function openCreate() {
  editingId.value = null
  form.value = { name: '', slug: '', description: '', parentId: null }
  showModal.value = true
}

function openEdit(cat: CategoryDTO) {
  editingId.value = cat.id
  form.value = {
    name: cat.name,
    slug: cat.slug,
    description: cat.description || '',
    parentId: cat.parentId,
  }
  showModal.value = true
}

async function handleSave() {
  try {
    if (editingId.value) {
      await updateCategory(editingId.value, form.value)
    } else {
      await createCategory(form.value)
    }
    showModal.value = false
    await loadTree()
  } catch (e: any) {
    alert(e.response?.data?.message || '保存失败')
  }
}

async function handleDelete(cat: CategoryDTO) {
  if (!confirm(`确定删除分类「${cat.name}」？`)) return
  try {
    await deleteCategory(cat.id)
    await loadTree()
  } catch (e: any) {
    alert(e.response?.data?.message || '删除失败')
  }
}

function openPermDialog(cat: CategoryDTO) {
  permCategoryId.value = cat.id
  showPermDialog.value = true
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

/* Node styles moved to CategoryManageNode.vue */

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
  max-width: 90vw;
}

.modal h3 {
  margin-bottom: 16px;
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
