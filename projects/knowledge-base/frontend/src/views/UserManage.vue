<template>
  <div class="user-manage">
    <div class="page-header">
      <h2>用户管理</h2>
      <button class="btn btn-primary" @click="openCreate()">+ 新建用户</button>
    </div>

    <div class="card">
      <div v-if="loading" class="loading">加载中...</div>
      <table v-else-if="users.length" class="data-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>用户名</th>
            <th>邮箱</th>
            <th>角色</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="user in users" :key="user.id">
            <td>{{ user.id }}</td>
            <td>{{ user.username }}</td>
            <td>{{ user.email || '-' }}</td>
            <td>
              <span class="badge" :class="roleClass(user.role)">{{ roleLabel(user.role) }}</span>
            </td>
            <td class="actions">
              <select
                class="role-select"
                :value="user.role"
                :disabled="user.id === currentUserId"
                @change="handleRoleChange(user.id, ($event.target as HTMLSelectElement).value, user.role)"
              >
                <option value="ADMIN">管理员</option>
                <option value="EDITOR">编辑</option>
                <option value="READER">读者</option>
              </select>
              <button
                class="btn-text btn-text-danger"
                :disabled="user.id === currentUserId"
                @click="handleDelete(user)"
              >删除</button>
            </td>
          </tr>
        </tbody>
      </table>
      <div v-else class="empty-state">暂无用户</div>
      <Pagination :current-page="page" :page-size="20" :total="total" @update:current-page="page = $event; loadUsers()" />
    </div>

    <!-- 新建弹窗 -->
    <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
      <div class="modal">
        <h3>新建用户</h3>
        <div class="form-group">
          <label>用户名</label>
          <input v-model="form.username" class="form-input" placeholder="用户名" maxlength="64" />
        </div>
        <div class="form-group">
          <label>密码</label>
          <input v-model="form.password" class="form-input" type="password" placeholder="至少8位，含大小写字母和数字" />
        </div>
        <div class="form-group">
          <label>确认密码</label>
          <input v-model="form.confirmPassword" class="form-input" type="password" placeholder="再次输入密码" />
        </div>
        <div class="form-group">
          <label>邮箱（可选）</label>
          <input v-model="form.email" class="form-input" type="email" placeholder="user@example.com" />
        </div>
        <div class="form-group">
          <label>角色</label>
          <select v-model="form.role" class="form-input">
            <option value="READER">读者</option>
            <option value="EDITOR">编辑</option>
            <option value="ADMIN">管理员</option>
          </select>
        </div>
        <div class="modal-actions">
          <button class="btn btn-ghost" @click="showModal = false">取消</button>
          <button class="btn btn-primary" @click="handleCreate" :disabled="!form.username.trim() || form.password.length < 8 || !/[A-Z]/.test(form.password) || !/[a-z]/.test(form.password) || !/\d/.test(form.password) || form.confirmPassword !== form.password">
            创建
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import type { UserDTO } from '@/types/api'
import { getUsers, createUser, deleteUser, updateUserRole } from '@/api/user'
import { useUserStore } from '@/stores/user'
import Pagination from '@/components/Pagination.vue'

const userStore = useUserStore()
const currentUserId = computed(() => userStore.user?.id)

const users = ref<UserDTO[]>([])
const loading = ref(false)
const page = ref(1)
const total = ref(0)
const showModal = ref(false)

const form = ref({ username: '', password: '', confirmPassword: '', email: '', role: 'READER' })

onMounted(loadUsers)

async function loadUsers() {
  loading.value = true
  try {
    const { data: res } = await getUsers(page.value, 20)
    users.value = res.data.records
    total.value = res.data.total
  } catch (e) {
    console.error('加载用户失败:', e)
  } finally {
    loading.value = false
  }
}

function openCreate() {
  form.value = { username: '', password: '', email: '', role: 'READER' }
  showModal.value = true
}

async function handleCreate() {
  try {
    await createUser(form.value)
    showModal.value = false
    await loadUsers()
  } catch (e: any) {
    alert(e.response?.data?.message || '创建失败')
  }
}

async function handleRoleChange(userId: number, role: string, currentRole: string) {
  if (!confirm(`确定将用户角色修改为「${{ ADMIN: '管理员', EDITOR: '编辑', READER: '读者' }[role]}」？`)) {
    // 恢复 select 值
    loadUsers()
    return
  }
  try {
    await updateUserRole(userId, { role })
    await loadUsers()
  } catch (e: any) {
    alert(e.response?.data?.message || '修改角色失败')
    loadUsers()
  }
}

async function handleDelete(user: UserDTO) {
  if (!confirm(`确定删除用户「${user.username}」？`)) return
  try {
    await deleteUser(user.id)
    await loadUsers()
  } catch (e: any) {
    alert(e.response?.data?.message || '删除失败')
  }
}

function roleLabel(role: string): string {
  return { ADMIN: '管理员', EDITOR: '编辑', READER: '读者' }[role] || role
}

function roleClass(role: string): string {
  return { ADMIN: 'badge-blue', EDITOR: 'badge-green', READER: 'badge-gray' }[role] || 'badge-gray'
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

.actions {
  white-space: nowrap;
}

.role-select {
  padding: 4px 8px;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 13px;
  margin-right: 8px;
}

.badge {
  padding: 2px 8px;
  border-radius: 4px;
  font-size: 12px;
  font-weight: 500;
}

.badge-blue { background: #e3f2fd; color: #1565c0; }
.badge-green { background: #e8f5e9; color: #2e7d32; }
.badge-gray { background: #f5f5f5; color: #666; }

.btn-text {
  background: none;
  border: none;
  color: #888;
  font-size: 12px;
  cursor: pointer;
}

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
