<template>
  <div class="article-detail" v-if="article">
    <div class="page-header">
      <button class="btn btn-ghost" @click="$router.back()">← 返回</button>
      <div class="header-right" v-if="userStore.user">
        <button
          v-if="canManagePerm"
          class="btn btn-ghost"
          @click="showPermDialog = true"
        >🔐 权限</button>
        <button
          v-if="canEdit"
          class="btn btn-ghost"
          @click="$router.push(`/articles/${article.id}/edit`)"
        >✏️ 编辑</button>
        <button
          v-if="canDelete"
          class="btn btn-danger"
          @click="handleDelete"
        >🗑 删除</button>
      </div>
    </div>

    <article class="article-card">
      <h1 class="article-title">{{ article.title }}</h1>
      <div class="article-meta">
        <span>👤 {{ article.authorName || '未知' }}</span>
        <span>📅 {{ formatTime(article.createdAt) }}</span>
        <span>👁 {{ article.viewCount }} 次阅读</span>
        <span>📌 v{{ article.version }}</span>
        <span class="badge" :class="statusClass">{{ statusLabel }}</span>
      </div>

      <div v-if="article.tags?.length" class="article-tags">
        <span v-for="tag in article.tags" :key="tag.id" class="tag-chip">
          <span v-if="tag.color" class="tag-dot" :style="{ background: tag.color }"></span>
          {{ tag.name }}
        </span>
      </div>
    </article>

    <!-- 页内 Tab 切换 -->
    <div class="tab-bar">
      <button
        v-for="tab in tabs"
        :key="tab.key"
        class="tab-btn"
        :class="{ active: activeTab === tab.key }"
        @click="activeTab = tab.key"
      >{{ tab.label }}</button>
    </div>

    <div class="tab-content">
      <!-- Tab: 正文 -->
      <div v-show="activeTab === 'content'" class="article-content">
        <MarkdownPreview :content="article.content || ''" />
      </div>

      <!-- Tab: 评论 -->
      <div v-show="activeTab === 'comments'" class="comments-section">
        <h2>评论 ({{ comments.length }})</h2>

        <div v-if="userStore.isLoggedIn" class="comment-form">
          <div v-if="replyTarget" class="reply-hint">
            回复 <strong>{{ replyTarget.authorName }}</strong>
            <button class="btn-text" @click="replyTarget = null">取消</button>
          </div>
          <textarea
            v-model="newComment"
            class="form-input"
            :placeholder="replyTarget ? `回复 ${replyTarget.authorName}...` : '写下你的评论...'"
            rows="3"
            maxlength="5000"
          ></textarea>
          <div class="comment-form-actions">
            <button class="btn btn-primary" :disabled="!newComment.trim() || submitting" @click="submitComment">发表评论</button>
          </div>
        </div>
        <div v-else class="login-hint"><router-link to="/login">登录</router-link> 后即可评论</div>

        <div v-if="commentsLoading" class="empty-state">加载评论中...</div>
        <div v-else-if="comments.length === 0" class="empty-state">暂无评论</div>
        <CommentTree
          v-else
          :comments="rootComments"
          :user-id="userStore.user?.id"
          :role="userStore.role"
          @reply="handleReply"
          @delete="handleDeleteComment"
        />
      </div>

      <!-- Tab: 版本历史 -->
      <div v-show="activeTab === 'versions'" class="version-section">
        <div class="version-header">
          <h3>版本历史</h3>
        </div>

        <div v-if="versionsLoading" class="empty-state">加载版本...</div>
        <div v-else-if="versions.length === 0" class="empty-state">暂无版本记录</div>
        <div v-else>
          <div class="version-list">
            <div v-for="v in versions" :key="v.id" class="version-item">
              <div class="version-info">
                <span class="version-number">v{{ v.version }}</span>
                <span class="version-title">{{ v.title }}</span>
                <span class="version-meta">
                  {{ v.createdByName || '未知' }} · {{ formatTime(v.createdAt) }}
                </span>
                <span v-if="v.changeSummary" class="version-summary">「{{ v.changeSummary }}」</span>
              </div>
              <div class="version-actions">
                <button class="btn btn-ghost btn-sm" @click="showDiff(v)">对比</button>
                <button
                  class="btn btn-ghost btn-sm"
                  :disabled="v.version === article.version || restoreLoading === v.version"
                  @click="confirmRestore(v)"
                >回滚</button>
              </div>
            </div>
          </div>

          <!-- Diff 视图 -->
          <div v-if="diffResult" class="diff-view">
            <div class="diff-toolbar">
              <div class="diff-toolbar-labels">
                <span class="diff-label-old">左侧 v{{ diffResult.oldVersion }}（旧）</span>
                <span class="diff-arrow">→</span>
                <span class="diff-label-new">右侧 v{{ diffResult.newVersion }}（当前）</span>
              </div>
              <div class="diff-toolbar-actions">
                <button class="btn btn-ghost btn-sm" @click="swapDiffDirection" title="交换对比方向">🔄 交换</button>
                <button class="btn btn-ghost btn-sm" @click="diffResult = null">关闭</button>
              </div>
            </div>
            <div class="diff-legend">
              <span class="legend-item legend-add">+ 新增内容</span>
              <span class="legend-item legend-remove">− 已删除内容</span>
            </div>
            <VirtualDiffList :parts="diffResult.parts" />
          </div>
        </div>
      </div>
    </div>

    <!-- 回滚确认弹窗 -->
    <div v-if="restoreTarget" class="restore-confirm-overlay" @click.self="restoreTarget = null">
      <div class="restore-confirm-card">
        <h3>确认回滚</h3>
        <p>将文章回滚到 <strong>v{{ restoreTarget.version }}</strong>「{{ restoreTarget.title }}」？</p>
        <p class="hint">当前版本 v{{ article.version }} 会保存为快照。</p>
        <div class="actions">
          <button class="btn btn-ghost" @click="restoreTarget = null">取消</button>
          <button class="btn btn-primary" :disabled="restoreLoading !== null" @click="doRestore">确认回滚</button>
        </div>
      </div>
    </div>

    <!-- 权限管理弹窗 -->
    <PermissionDialog
      :visible="showPermDialog"
      title="文章"
      resource-type="article"
      :resource-id="articleId"
      :load-fn="getArticlePermissions"
      :set-fn="setArticlePermissions"
      :remove-fn="removeArticlePermission"
      @close="showPermDialog = false"
    />
  </div>

  <div v-else-if="loading" class="empty-state">加载中...</div>
  <div v-else class="empty-state">文章不存在或无权查看</div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { canEditArticle, canDeleteArticle } from '@/utils/permission'
import type { PermissionLevel } from '@/types/api'
import MarkdownPreview from '@/components/MarkdownPreview.vue'
import CommentTree from '@/components/CommentTree.vue'
import { getArticle, updateArticleStatus, getArticleVersions, restoreArticleVersion } from '@/api/article'
import { getComments, createComment, deleteComment } from '@/api/comment'
import type { ArticleDTO, CommentDTO, ArticleVersionDTO } from '@/types/api'
import { diffLines } from 'diff'
import { useAbort } from '@/composables/useAbort'
import PermissionDialog from '@/components/PermissionDialog.vue'
import VirtualDiffList from '@/components/VirtualDiffList.vue'
import { getArticlePermissions, setArticlePermissions, removeArticlePermission, batchQueryPermissions } from '@/api/permission'

const route = useRoute()
const router = useRouter()
const userStore = useUserStore()

const article = ref<ArticleDTO | null>(null)
const loading = ref(true)
const articleId = Number(route.params.id)

// Tabs
const activeTab = ref<'content' | 'comments' | 'versions'>('content')
const tabs = [
  { key: 'content' as const, label: '正文' },
  { key: 'comments' as const, label: '评论' },
  { key: 'versions' as const, label: '版本历史' },
]

// Comments
const comments = ref<CommentDTO[]>([])
const commentsLoading = ref(false)
const newComment = ref('')
const submitting = ref(false)
const replyTarget = ref<CommentDTO | null>(null)

// Versions
const versions = ref<ArticleVersionDTO[]>([])
const versionsLoading = ref(false)
const restoreLoading = ref<number | null>(null)
const restoreTarget = ref<{ version: number; title: string } | null>(null)
const diffTargetVersion = ref<number | null>(null)
const diffDirection = ref<'forward' | 'reverse'>('forward')
const diffResult = ref<{
  oldVersion: number; newVersion: number
  parts: { value: string; added?: boolean; removed?: boolean }[]
} | null>(null)

// 当前用户对该文章的资源权限
const articlePermission = ref<PermissionLevel | undefined>(undefined)

const canEdit = computed(() => canEditArticle(userStore.role, article.value?.authorId, userStore.user?.id, articlePermission.value))
const canDelete = computed(() => canDeleteArticle(userStore.role, article.value?.authorId, userStore.user?.id, articlePermission.value))
const canManagePerm = computed(() => userStore.role === 'ADMIN' || canDeleteArticle(userStore.role, article.value?.authorId, userStore.user?.id, articlePermission.value))
const showPermDialog = ref(false)
const statusLabel = computed(() => ({ DRAFT: '草稿', PUBLISHED: '已发布', ARCHIVED: '已归档' }[article.value?.status || ''] || ''))
const statusClass = computed(() => ({ DRAFT: 'badge-gray', PUBLISHED: 'badge-green', ARCHIVED: 'badge-yellow' }[article.value?.status || ''] || 'badge-gray'))

const rootComments = computed(() => {
  const map = new Map<number, CommentDTO>()
  const roots: CommentDTO[] = []
  for (const c of comments.value) map.set(c.id, { ...c, replies: [] })
  for (const c of comments.value) {
    const node = map.get(c.id)!
    if (c.parentId && map.has(c.parentId)) map.get(c.parentId)!.replies!.push(node)
    else roots.push(node)
  }
  return roots
})

// Abort: 进入/离开文章详情时取消旧请求
useAbort(`/articles/${articleId}`)

onMounted(async () => {
  try {
    const [articleRes, commentRes] = await Promise.all([
      getArticle(articleId),
      getComments(articleId).catch(() => ({ data: { data: [] } })),
    ])
    article.value = articleRes.data.data
    comments.value = commentRes.data.data

    // 加载当前用户对该文章的资源权限
    if (userStore.isLoggedIn && userStore.role !== 'ADMIN') {
      try {
        const permRes = await batchQueryPermissions([articleId])
        const permMap = permRes.data?.data || {}
        const perm = permMap[articleId]
        if (perm) articlePermission.value = perm as PermissionLevel
      } catch (e) {
        // 非关键路径，忽略
      }
    }
  } catch (e) { console.error('加载失败:', e) }
  finally { loading.value = false }
})

async function loadVersions() {
  versionsLoading.value = true
  try {
    const res = await getArticleVersions(articleId)
    versions.value = res.data?.data || []
  } catch (e) { console.error('版本加载失败:', e) }
  finally { versionsLoading.value = false }
}

// Watch tab switch to lazy-load versions

watch(activeTab, (tab) => {
  if (tab === 'versions' && versions.value.length === 0) loadVersions()
})

function handleReply(commentId: number) {
  const target = comments.value.find(c => c.id === commentId)
  if (target) replyTarget.value = target
}

async function submitComment() {
  const content = newComment.value.trim()
  if (!content) return
  submitting.value = true
  try {
    await createComment(articleId, { content, parentId: replyTarget.value?.id || null })
    newComment.value = ''
    replyTarget.value = null
    const { data: res } = await getComments(articleId)
    comments.value = res.data
  } catch (e) { console.error('评论失败:', e) }
  finally { submitting.value = false }
}

async function handleDeleteComment(commentId: number) {
  if (!confirm('确定删除此评论？')) return
  try {
    await deleteComment(commentId)
    const { data: res } = await getComments(articleId)
    comments.value = res.data
  } catch (e) { console.error('删除评论失败:', e) }
}

async function handleDelete() {
  if (!confirm('确定删除此文章？')) return
  try {
    await updateArticleStatus(articleId, { status: 'DELETED' })
    router.push('/articles')
  } catch (e) { console.error('删除失败:', e) }
}

function showDiff(v: ArticleVersionDTO) {
  if (!article.value) return
  diffTargetVersion.value = v.version
  diffDirection.value = 'forward'
  renderDiff(v)
}

function renderDiff(version: ArticleVersionDTO) {
  if (!article.value) return
  const currentContent = article.value.content || ''
  const targetContent = version.content || ''
  const old = diffDirection.value === 'forward' ? targetContent : currentContent
  const cur = diffDirection.value === 'forward' ? currentContent : targetContent
  const parts = diffLines(old, cur)
  diffResult.value = {
    oldVersion: diffDirection.value === 'forward' ? version.version : article.value.version,
    newVersion: diffDirection.value === 'forward' ? article.value.version : version.version,
    parts,
  }
}

function swapDiffDirection() {
  diffDirection.value = diffDirection.value === 'forward' ? 'reverse' : 'forward'
  const target = versions.value.find(v => v.version === diffTargetVersion.value)
  if (target) renderDiff(target)
}

// diffClass 不再使用，VirtualDiffList 内部处理

function confirmRestore(v: ArticleVersionDTO) {
  restoreTarget.value = { version: v.version, title: v.title }
}

async function doRestore() {
  if (!restoreTarget.value) return
  restoreLoading.value = restoreTarget.value.version
  try {
    await restoreArticleVersion(articleId, restoreTarget.value.version)
    restoreTarget.value = null
    diffResult.value = null
    // Reload article & versions
    const res = await getArticle(articleId)
    article.value = res.data.data
    await loadVersions()
  } catch (e: any) {
    const msg = e?.response?.data?.message || '回滚失败'
    alert(msg)
  } finally {
    restoreLoading.value = null
  }
}

function formatTime(dateStr: string | null): string {
  if (!dateStr) return ''
  return new Date(dateStr).toLocaleString('zh-CN')
}
</script>

<style scoped>
.article-detail { max-width: 800px; margin: 0 auto; }
.page-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; }
.header-right { display: flex; gap: 8px; }

.article-card {
  background: white; padding: 32px; border-radius: 8px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.08);
}
.article-title { font-size: 28px; margin-bottom: 12px; line-height: 1.3; }
.article-meta { display: flex; flex-wrap: wrap; gap: 16px; font-size: 13px; color: #888; margin-bottom: 16px; }
.article-tags { display: flex; gap: 8px; margin-bottom: 0; }
.tag-chip { display: inline-flex; align-items: center; gap: 4px; padding: 2px 10px; background: #f0f0f5; border-radius: 12px; font-size: 12px; color: #555; }
.tag-dot { width: 8px; height: 8px; border-radius: 50%; }

/* Tabs */
.tab-bar { display: flex; border-bottom: 2px solid #f0f0f0; margin-top: 20px; }
.tab-btn {
  padding: 10px 20px; border: none; background: transparent; font-size: 14px;
  color: #666; cursor: pointer; border-bottom: 2px solid transparent; margin-bottom: -2px;
}
.tab-btn.active { color: #4361ee; border-bottom-color: #4361ee; font-weight: 600; }
.tab-content { margin-top: 20px; }

.article-content { background: white; padding: 24px; border-radius: 8px; }

/* Comments */
.comments-section h2 { font-size: 18px; margin-bottom: 16px; }
.comment-form {
  background: white; padding: 16px; border-radius: 8px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.08); margin-bottom: 16px;
}
.reply-hint {
  display: flex; align-items: center; gap: 8px; padding: 6px 10px;
  background: #f5f6fa; border-radius: 4px; margin-bottom: 8px; font-size: 13px; color: #666;
}
.reply-hint .btn-text { background: none; border: none; color: #e63946; font-size: 12px; cursor: pointer; }
.comment-form-actions { margin-top: 8px; text-align: right; }
.login-hint { font-size: 14px; color: #999; margin-bottom: 16px; }

/* Versions */
.version-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
.version-list { display: flex; flex-direction: column; gap: 8px; }
.version-item {
  display: flex; align-items: center; justify-content: space-between;
  padding: 12px 16px; background: white; border-radius: 6px; border: 1px solid #f0f0f0;
}
.version-item:hover { background: #f5f6fa; }
.version-info { display: flex; align-items: center; gap: 12px; font-size: 14px; flex: 1; min-width: 0; }
.version-number { font-weight: 600; color: #4361ee; white-space: nowrap; }
.version-title { font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.version-meta { font-size: 12px; color: #888; white-space: nowrap; }
.version-summary { font-size: 12px; color: #999; font-style: italic; }
.version-actions { display: flex; gap: 8px; flex-shrink: 0; }

/* Diff */
.diff-view {
  background: white; border-radius: 8px; padding: 16px; margin-top: 16px;
}
.diff-toolbar { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-bottom: 8px; padding-bottom: 8px; border-bottom: 1px solid #f0f0f0; }
.diff-toolbar-labels { display: flex; align-items: center; gap: 8px; font-size: 13px; }
.diff-label-old { color: #e63946; font-weight: 500; }
.diff-label-new { color: #22863a; font-weight: 500; }
.diff-arrow { color: #888; }
.diff-toolbar-actions { display: flex; gap: 6px; }
.diff-legend { display: flex; gap: 16px; font-size: 12px; color: #888; margin-bottom: 10px; padding: 4px 0; }
.legend-item { display: flex; align-items: center; gap: 4px; }
.legend-add::before { content: ''; display: inline-block; width: 12px; height: 12px; background: #e8f5e9; border-left: 2px solid #22863a; border-radius: 2px; }
.legend-remove::before { content: ''; display: inline-block; width: 12px; height: 12px; background: #fde8ec; border-left: 2px solid #e63946; border-radius: 2px; }

/* Restore confirm */
.restore-confirm-overlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; z-index: 100; }
.restore-confirm-card { background: white; padding: 32px; border-radius: 8px; text-align: center; min-width: 300px; }
.restore-confirm-card h3 { margin-bottom: 12px; }
.restore-confirm-card p { margin-bottom: 8px; color: #666; }
.restore-confirm-card .hint { font-size: 13px; color: #999; }
.restore-confirm-card .actions { display: flex; gap: 12px; justify-content: center; margin-top: 20px; }

.badge { padding: 2px 8px; border-radius: 4px; font-size: 12px; font-weight: 500; }
.badge-green { background: #e8f5e9; color: #2e7d32; }
.badge-gray { background: #f5f5f5; color: #666; }
.badge-yellow { background: #fff3e0; color: #e65100; }

.empty-state { text-align: center; color: #999; padding: 20px; font-size: 14px; }
</style>
