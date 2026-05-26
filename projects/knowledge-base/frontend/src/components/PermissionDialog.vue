<template>
  <div v-if="visible" class="modal-overlay" @click.self="close">
    <div class="modal permission-modal">
      <h3>{{ title }}权限管理</h3>
      <p class="permission-hint">
        💡 资源权限与角色权限取<strong>并集</strong>（宽松策略）：资源权限只能放大不能缩小角色权限。
      </p>

      <div v-if="loading" class="empty-state">加载中...</div>
      <template v-else>
        <!-- 当前权限列表 -->
        <div v-if="permissions.length" class="perm-list">
          <div v-for="p in permissions" :key="p.userId" class="perm-item">
            <span class="perm-user">{{ p.username }}</span>
            <select
              class="perm-select"
              :value="p.permission"
              @change="updatePermission(p.userId, ($event.target as HTMLSelectElement).value as PermissionLevel)"
            >
              <option value="VIEW">查看 (VIEW)</option>
              <option value="EDIT">编辑 (EDIT)</option>
              <option value="MANAGE">管理 (MANAGE)</option>
            </select>
            <button class="btn-text btn-text-danger" @click="removePermission(p.userId)">移除</button>
          </div>
        </div>
        <div v-else class="empty-state">暂未设置资源权限</div>

        <!-- 添加新权限 -->
        <div class="perm-add-wrapper">
          <div class="perm-add-search">
            <input
              v-model="newUsername"
              class="form-input perm-input"
              placeholder="搜索用户名或邮箱..."
              @input="onSearchInput"
              @focus="showSearchResults = searchResults.length > 0"
              @blur="onSearchBlur"
            />
            <div v-if="showSearchResults && searchResults.length" class="search-dropdown">
              <div
                v-for="u in searchResults"
                :key="u.id"
                class="search-item"
                @click="selectUser(u)"
              >
                <span>{{ u.username }}</span>
                <span v-if="u.email" class="search-email">{{ u.email }}</span>
              </div>
            </div>
          </div>
          <select v-model="newPermission" class="perm-select">
            <option value="VIEW">查看 (VIEW)</option>
            <option value="EDIT">编辑 (EDIT)</option>
            <option value="MANAGE">管理 (MANAGE)</option>
          </select>
          <button class="btn btn-primary btn-sm" :disabled="!newUsername.trim() || adding" @click="addPermission">
            添加
          </button>
        </div>
      </template>

      <div class="modal-actions">
        <button class="btn btn-ghost" @click="close">关闭</button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, onUnmounted } from 'vue'
import type { PermissionDTO, PermissionLevel, PermissionGrantRequest, UserDTO } from '@/types/api'
import { useUserStore } from '@/stores/user'
import { searchUsers } from '@/api/user'

const props = defineProps<{
  visible: boolean
  title: string
  resourceType: 'article' | 'category'
  resourceId: number
  loadFn: (id: number) => Promise<any>
  setFn: (id: number, permissions: PermissionGrantRequest[]) => Promise<any>
  removeFn: (resourceId: number, userId: number) => Promise<any>
}>()

const emit = defineEmits<{ close: [] }>()

const userStore = useUserStore()
const permissions = ref<PermissionDTO[]>([])
const loading = ref(false)
const adding = ref(false)
const newUsername = ref('')
const newPermission = ref<PermissionLevel>('VIEW')
const searchResults = ref<UserDTO[]>([])
const showSearchResults = ref(false)
let searchTimer: ReturnType<typeof setTimeout> | null = null

watch(() => props.visible, async (v) => {
  if (v) await load()
})

async function load() {
  loading.value = true
  try {
    const res = await props.loadFn(props.resourceId)
    permissions.value = res.data?.data || []
  } catch (e) {
    console.error('加载权限失败:', e)
  } finally {
    loading.value = false
  }
}

async function addPermission() {
  const username = newUsername.value.trim()
  if (!username) return

  // 前端预过滤：不能对自己授权
  if (username === userStore.user?.username) {
    alert('不能对自己授权')
    return
  }

  try {
    adding.value = true
    // 后端支持 username 授权，无需前端查用户 ID
    await props.setFn(props.resourceId, [{ username, permission: newPermission.value }])
    newUsername.value = ''
    await load()
  } catch (e: any) {
    alert(e.response?.data?.message || '添加失败')
  } finally {
    adding.value = false
  }
}

async function updatePermission(userId: number, permission: PermissionLevel) {
  try {
    await props.setFn(props.resourceId, [{ userId, permission }])
    await load()
  } catch (e: any) {
    alert(e.response?.data?.message || '更新失败')
  }
}

async function removePermission(userId: number) {
  if (!confirm('确定移除此权限？')) return
  try {
    await props.removeFn(props.resourceId, userId)
    await load()
  } catch (e: any) {
    alert(e.response?.data?.message || '移除失败')
  }
}

function close() {
  emit('close')
}

function onSearchInput() {
  showSearchResults.value = false  // 输入时先关闭，等搜索结果回来再显示
  if (searchTimer) clearTimeout(searchTimer)
  const q = newUsername.value.trim()
  if (!q) { searchResults.value = []; return }
  searchTimer = setTimeout(async () => {
    try {
      const res = await searchUsers(q, 1, 20, props.resourceType, props.resourceId)
      searchResults.value = res.data?.data?.records || []
      showSearchResults.value = searchResults.value.length > 0
    } catch { searchResults.value = [] }
  }, 300)
}

function onSearchBlur() {
  // 延迟关闭，让 click 事件先触发
  setTimeout(() => { showSearchResults.value = false }, 150)
}

function selectUser(user: UserDTO) {
  newUsername.value = user.username
  showSearchResults.value = false
  searchResults.value = []
}

onUnmounted(() => {
  if (searchTimer) clearTimeout(searchTimer)
})
</script>

<style scoped>
.modal-overlay {
  position: fixed; top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.4); display: flex; align-items: center;
  justify-content: center; z-index: 1000;
}
.permission-modal {
  background: white; padding: 24px; border-radius: 8px; width: 480px; max-width: 90vw;
  max-height: 80vh; overflow-y: auto;
}
.permission-modal h3 { margin-bottom: 8px; }
.permission-hint {
  font-size: 13px; color: #666; background: #f5f6fa; padding: 8px 12px;
  border-radius: 4px; margin-bottom: 16px; line-height: 1.5;
}
.perm-list { display: flex; flex-direction: column; gap: 8px; margin-bottom: 16px; }
.perm-item {
  display: flex; align-items: center; gap: 8px; padding: 8px 12px;
  background: #fafafa; border-radius: 4px;
}
.perm-user { font-weight: 500; font-size: 14px; min-width: 80px; }
.perm-select {
  padding: 4px 8px; border: 1px solid #ddd; border-radius: 4px;
  font-size: 13px; background: white;
}
.perm-add {
  display: flex; gap: 8px; padding-top: 12px; border-top: 1px solid #eee;
}
.perm-add-wrapper {
  display: flex; gap: 8px; padding-top: 12px; border-top: 1px solid #eee;
}
.perm-add-search {
  flex: 1; position: relative;
}
.search-dropdown {
  position: absolute; top: 100%; left: 0; right: 0;
  background: white; border: 1px solid #e0e0e0; border-radius: 4px;
  max-height: 180px; overflow-y: auto; box-shadow: 0 4px 8px rgba(0,0,0,0.1);
  z-index: 10;
}
.search-item {
  padding: 8px 12px; cursor: pointer; display: flex; justify-content: space-between;
  font-size: 13px;
}
.search-item:hover { background: #f5f6fa; }
.search-email { color: #999; font-size: 12px; }
.perm-input { flex: 1; }
.modal-actions { display: flex; justify-content: flex-end; margin-top: 16px; }
.btn-text-danger { color: #e63946; }
.btn-text-danger:hover { color: #c62828; }
.empty-state { color: #999; font-size: 14px; text-align: center; padding: 12px; }
</style>
