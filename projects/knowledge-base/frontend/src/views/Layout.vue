<template>
  <div class="layout">
    <!-- 侧边栏 -->
    <aside class="sidebar">
      <div class="sidebar-brand">📚 知识库</div>
      <nav class="sidebar-nav">
        <router-link
          v-if="userStore.isAdmin"
          to="/dashboard"
          class="nav-item"
          exact-active-class="active"
        >
          📊 仪表盘
        </router-link>
        <router-link to="/articles" class="nav-item" active-class="active">
          📝 文章列表
        </router-link>
        <router-link to="/search" class="nav-item" active-class="active">
          🔍 全文搜索
        </router-link>
        <router-link
          v-if="userStore.isEditor"
          to="/articles/create"
          class="nav-item"
          active-class="active"
        >
          ✏️ 创建文章
        </router-link>
        <router-link
          v-if="userStore.isEditor"
          to="/categories"
          class="nav-item"
          active-class="active"
        >
          📂 分类管理
        </router-link>
        <router-link
          v-if="userStore.isEditor"
          to="/tags"
          class="nav-item"
          active-class="active"
        >
          🏷️ 标签管理
        </router-link>
        <router-link
          v-if="userStore.isAdmin"
          to="/users"
          class="nav-item"
          active-class="active"
        >
          👥 用户管理
        </router-link>
      </nav>
    </aside>

    <!-- 主内容区 -->
    <div class="main-area">
      <!-- 顶栏 -->
      <header class="topbar">
        <span class="spacer"></span>
        <div v-if="userStore.user" class="user-info">
          <span class="user-name">{{ userStore.user.username }}</span>
          <span class="badge" :class="roleBadgeClass">{{ roleLabel }}</span>
          <button class="btn btn-ghost" @click="handleLogout">退出</button>
        </div>
      </header>

      <!-- 页面内容 -->
      <main class="content">
        <router-view />
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const userStore = useUserStore()

const roleLabel = computed(() => {
  const map: Record<string, string> = { ADMIN: '管理员', EDITOR: '编辑', READER: '读者' }
  return map[userStore.role || ''] || ''
})

const roleBadgeClass = computed(() => {
  const map: Record<string, string> = { ADMIN: 'badge-blue', EDITOR: 'badge-green', READER: 'badge-gray' }
  return map[userStore.role || ''] || 'badge-gray'
})

async function handleLogout() {
  await userStore.logout()
  router.push('/login')
}
</script>

<style scoped>
.layout {
  display: flex;
  min-height: 100vh;
}

.sidebar {
  width: 220px;
  background: #1a1a2e;
  color: #ccc;
  display: flex;
  flex-direction: column;
  flex-shrink: 0;
}

.sidebar-brand {
  padding: 20px;
  font-size: 18px;
  font-weight: 600;
  color: white;
}

.sidebar-nav {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 0 8px;
}

.nav-item {
  display: block;
  padding: 10px 12px;
  border-radius: 6px;
  color: #aaa;
  font-size: 14px;
  text-decoration: none;
  transition: background 0.15s, color 0.15s;
}

.nav-item:hover {
  background: rgba(255, 255, 255, 0.08);
  color: white;
  text-decoration: none;
}

.nav-item.active {
  background: rgba(67, 97, 238, 0.3);
  color: white;
}

.main-area {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.topbar {
  display: flex;
  align-items: center;
  padding: 12px 24px;
  background: white;
  border-bottom: 1px solid #eee;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.user-name {
  font-size: 14px;
}

.content {
  flex: 1;
  padding: 24px;
  overflow-y: auto;
}
</style>
