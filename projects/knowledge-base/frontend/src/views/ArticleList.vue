<template>
  <div>
    <div class="page-header">
      <h2>文章列表</h2>
      <router-link v-if="userStore.isEditor" to="/articles/create" class="btn btn-primary">
        + 新建文章
      </router-link>
    </div>

    <!-- 搜索过滤 -->
    <div class="card filter-bar">
      <input
        v-model="filters.keyword"
        class="form-input"
        placeholder="搜索标题或摘要..."
        @keyup.enter="loadArticles"
      />
      <select v-model="filters.status" class="form-input">
        <option value="">全部状态</option>
        <option value="PUBLISHED">已发布</option>
        <option value="DRAFT">草稿</option>
        <option value="ARCHIVED">已归档</option>
      </select>
      <button class="btn btn-primary" @click="loadArticles">🔍 搜索</button>
    </div>

    <!-- 批量操作 -->
    <div v-if="selectedIds.length && userStore.isEditor" class="batch-bar">
      <span>已选 {{ selectedIds.length }} 篇</span>
      <button class="btn btn-ghost" @click="batchDelete">🗑 批量删除</button>
    </div>

    <!-- 列表 -->
    <div v-if="loading" class="loading">加载中...</div>
    <div v-else-if="articles.length === 0" class="card empty-state">暂无文章</div>
    <div v-else class="article-list">
      <label class="article-item card" v-for="article in articles" :key="article.id">
        <input
          v-if="userStore.isEditor"
          type="checkbox"
          :checked="selectedIds.includes(article.id)"
          @change="toggleSelect(article.id)"
        />
        <router-link :to="`/articles/${article.id}`" class="article-link">
          <h3 class="article-title">{{ article.title }}</h3>
          <p class="article-summary">{{ article.summary || '无摘要' }}</p>
          <div class="article-meta">
            <span>👤 {{ article.authorName || '未知' }}</span>
            <span v-if="article.categoryName">📂 {{ article.categoryName }}</span>
            <span class="badge" :class="statusClass(article.status)">{{ statusLabel(article.status) }}</span>
            <span>{{ formatTime(article.updatedAt) }}</span>
          </div>
          <div v-if="article.tags?.length" class="article-tags">
            <span v-for="tag in article.tags" :key="tag.id" class="tag-chip">{{ tag.name }}</span>
          </div>
        </router-link>
        <div v-if="canOperate(article)" class="item-actions">
          <router-link v-if="canEdit(article)" :to="`/articles/${article.id}/edit`" class="btn-text">✏️ 编辑</router-link>
          <button v-if="canDel(article)" class="btn-text btn-text-danger" @click="handleDeleteSingle(article)">🗑 删除</button>
        </div>
      </label>
    </div>

    <Pagination
      :current-page="page"
      :page-size="size"
      :total="total"
      @update:current-page="page = $event; loadArticles()"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useUserStore } from '@/stores/user'
import { getArticles, batchDeleteArticles } from '@/api/article'
import { batchQueryPermissions } from '@/api/permission'
import { canEditArticle, canDeleteArticle } from '@/utils/permission'
import Pagination from '@/components/Pagination.vue'
import type { ArticleDTO, PermissionLevel } from '@/types/api'
import { useAbort } from '@/composables/useAbort'

const userStore = useUserStore()

useAbort('/articles')

const articles = ref<ArticleDTO[]>([])
const permMap = ref<Record<number, PermissionLevel | undefined>>({})
const loading = ref(false)
const page = ref(1)
const size = ref(20)
const total = ref(0)
const selectedIds = ref<number[]>([])

const filters = ref({ keyword: '', status: '' })

onMounted(loadArticles)

async function loadArticles() {
  loading.value = true
  try {
    const { data: res } = await getArticles({
      page: page.value,
      size: size.value,
      keyword: filters.value.keyword || undefined,
      status: filters.value.status || undefined,
    })
    articles.value = res.data.records
    total.value = res.data.total
    selectedIds.value = []

    // 批量查询资源权限（仅非 ADMIN 需要查）
    if (userStore.isLoggedIn && userStore.role !== 'ADMIN' && articles.value.length > 0) {
      try {
        const ids = articles.value.map(a => a.id)
        const permRes = await batchQueryPermissions(ids)
        permMap.value = (permRes.data?.data || {}) as Record<number, PermissionLevel | undefined>
      } catch {
        permMap.value = {}  // fallback 到纯角色判断
      }
    } else {
      permMap.value = {}
    }
  } catch (e) {
    console.error('加载文章失败:', e)
  } finally {
    loading.value = false
  }
}

function toggleSelect(id: number) {
  const idx = selectedIds.value.indexOf(id)
  if (idx >= 0) {
    selectedIds.value.splice(idx, 1)
  } else {
    selectedIds.value.push(id)
  }
}

async function batchDelete() {
  if (!confirm(`确定删除选中的 ${selectedIds.value.length} 篇文章？`)) return
  try {
    await batchDeleteArticles({ ids: selectedIds.value })
    await loadArticles()
  } catch (e) {
    console.error('批量删除失败:', e)
  }
}

function canEdit(article: ArticleDTO): boolean {
  return canEditArticle(userStore.role, article.authorId, userStore.user?.id, permMap.value[article.id])
}

function canDel(article: ArticleDTO): boolean {
  return canDeleteArticle(userStore.role, article.authorId, userStore.user?.id, permMap.value[article.id])
}

function canOperate(article: ArticleDTO): boolean {
  return canEdit(article) || canDel(article)
}

async function handleDeleteSingle(article: ArticleDTO) {
  if (!confirm(`确定删除文章「${article.title}」？`)) return
  try {
    await batchDeleteArticles({ ids: [article.id] })
    await loadArticles()
  } catch (e) {
    console.error('删除失败:', e)
  }
}

function statusLabel(status: string): string {
  return { DRAFT: '草稿', PUBLISHED: '已发布', ARCHIVED: '已归档' }[status] || status
}

function statusClass(status: string): string {
  return { DRAFT: 'badge-gray', PUBLISHED: 'badge-green', ARCHIVED: 'badge-yellow' }[status] || 'badge-gray'
}

function formatTime(dateStr: string): string {
  return new Date(dateStr).toLocaleString('zh-CN')
}
</script>

<style scoped>
.filter-bar {
  display: flex;
  gap: 8px;
  margin-bottom: 12px;
  padding: 12px 16px;
}

.filter-bar .form-input {
  max-width: 200px;
}

.batch-bar {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px 16px;
  background: #fff3e0;
  border-radius: 6px;
  margin-bottom: 12px;
  font-size: 14px;
}

.article-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.article-item {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 12px 16px;
}

.article-item input[type="checkbox"] {
  margin-top: 4px;
  accent-color: #4361ee;
}

.article-link {
  flex: 1;
  text-decoration: none;
  color: inherit;
}

.article-link:hover .article-title {
  color: #4361ee;
}

.article-title {
  font-size: 16px;
  font-weight: 600;
  margin-bottom: 4px;
  transition: color 0.15s;
}

.article-summary {
  font-size: 13px;
  color: #888;
  margin-bottom: 8px;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.article-meta {
  display: flex;
  gap: 12px;
  font-size: 12px;
  color: #aaa;
}

.article-tags {
  display: flex;
  gap: 6px;
  margin-top: 6px;
}

.item-actions {
  display: flex;
  flex-direction: column;
  gap: 4px;
  flex-shrink: 0;
  padding-left: 8px;
}
.btn-text {
  background: none; border: none; color: #888;
  font-size: 12px; cursor: pointer; text-decoration: none;
}
.btn-text:hover { color: #4361ee; }
.btn-text-danger:hover { color: #e63946; }

.tag-chip {
  padding: 1px 8px;
  background: #f0f0f5;
  border-radius: 10px;
  font-size: 11px;
  color: #666;
}

.badge {
  padding: 1px 6px;
  border-radius: 3px;
  font-size: 11px;
  font-weight: 500;
}

.badge-green { background: #e8f5e9; color: #2e7d32; }
.badge-gray { background: #f5f5f5; color: #666; }
.badge-yellow { background: #fff3e0; color: #e65100; }

.loading, .empty-state {
  color: #999;
  font-size: 14px;
  text-align: center;
  padding: 20px;
}
</style>
