<template>
  <div class="article-edit">
    <div class="page-header">
      <h2>{{ isEdit ? '编辑文章' : '创建文章' }}</h2>
      <div class="header-actions">
        <button class="btn btn-ghost" @click="$router.back()">返回</button>
        <button v-if="isEdit" class="btn btn-ghost" @click="showVersions = !showVersions">
          📋 版本历史
        </button>
      </div>
    </div>

    <!-- 版本历史面板 -->
    <div v-if="showVersions" class="version-panel">
      <h3>版本历史</h3>
      <div v-if="versionsLoading" class="loading">加载中...</div>
      <div v-else-if="versions.length === 0" class="empty-state">暂无版本记录</div>
      <ul v-else class="version-list">
        <li v-for="v in versions" :key="v.id" class="version-item">
          <div class="version-meta">
            <span class="version-num">v{{ v.version }}</span>
            <span class="version-author">{{ v.createdByName || '未知' }}</span>
            <span class="version-time">{{ formatTime(v.createdAt) }}</span>
          </div>
          <div v-if="v.changeSummary" class="version-summary">{{ v.changeSummary }}</div>
          <button class="btn btn-ghost btn-sm" @click="restoreVersion(v.version)">
            ↩ 回滚到此版本
          </button>
        </li>
      </ul>
    </div>

    <!-- 编辑表单 -->
    <div v-if="loading" class="loading">加载中...</div>
    <form v-else class="edit-form" @submit.prevent="handleSave">
      <div class="form-group">
        <label>标题</label>
        <input
          v-model="form.title"
          class="form-input"
          placeholder="文章标题"
          required
          maxlength="256"
        />
      </div>

      <div class="form-row">
        <div class="form-group" style="flex:1">
          <label>分类</label>
          <CategoryTree v-model="form.categoryId" />
        </div>
        <div class="form-group" style="flex:1">
          <label>标签</label>
          <TagSelect v-model="selectedTags" />
        </div>
      </div>

      <div class="form-group">
        <label>摘要（可选）</label>
        <textarea
          v-model="form.summary"
          class="form-input"
          placeholder="简要描述文章内容"
          rows="2"
          maxlength="512"
        ></textarea>
      </div>

      <div class="form-group">
        <label>内容</label>
        <MarkdownEditor v-model="form.content" />
      </div>

      <div class="form-actions">
        <button
          type="button"
          class="btn btn-ghost"
          @click="handleSave('DRAFT')"
          :disabled="saving"
        >
          💾 保存草稿
        </button>
        <button
          type="button"
          class="btn btn-primary"
          @click="handleSave('PUBLISHED')"
          :disabled="saving"
        >
          🚀 发布
        </button>
      </div>
    </form>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import MarkdownEditor from '@/components/MarkdownEditor.vue'
import CategoryTree from '@/components/CategoryTree.vue'
import TagSelect from '@/components/TagSelect.vue'
import {
  getArticle,
  createArticle,
  updateArticle,
  getArticleVersions,
  restoreArticleVersion,
} from '@/api/article'
import type { TagDTO, ArticleVersionDTO } from '@/types/api'

const route = useRoute()
const router = useRouter()

const articleId = computed(() => route.params.id ? Number(route.params.id) : null)
const isEdit = computed(() => !!articleId.value)

const saving = ref(false)
const loading = ref(false)
const showVersions = ref(false)
const versionsLoading = ref(false)
const versions = ref<ArticleVersionDTO[]>([])
const selectedTags = ref<TagDTO[]>([])

const form = reactive({
  title: '',
  content: '',
  summary: '',
  categoryId: null as number | null,
})

onMounted(async () => {
  if (!isEdit.value) return
  loading.value = true
  try {
    const { data: res } = await getArticle(articleId.value!)
    const article = res.data
    form.title = article.title
    form.content = article.content || ''
    form.summary = article.summary || ''
    form.categoryId = article.categoryId
    selectedTags.value = article.tags || []
  } catch (e) {
    console.error('加载文章失败:', e)
  } finally {
    loading.value = false
  }
})

async function loadVersions() {
  if (!articleId.value) return
  versionsLoading.value = true
  try {
    const { data: res } = await getArticleVersions(articleId.value)
    versions.value = res.data
  } catch (e) {
    console.error('加载版本失败:', e)
  } finally {
    versionsLoading.value = false
  }
}

// 点击版本历史时加载
import { watch } from 'vue'
watch(showVersions, (val) => {
  if (val && versions.value.length === 0) loadVersions()
})

async function handleSave(status: 'DRAFT' | 'PUBLISHED') {
  if (!form.title.trim() || !form.content.trim()) return
  saving.value = true
  try {
    const payload = {
      title: form.title,
      content: form.content,
      summary: form.summary || null,
      categoryId: form.categoryId,
      tagIds: selectedTags.value.map(t => t.id),
      status,
    }
    if (isEdit.value) {
      await updateArticle(articleId.value!, payload)
    } else {
      const { data: res } = await createArticle(payload as any)
      router.replace(`/articles/${res.data.id}`)
      return
    }
    router.push(`/articles/${articleId.value}`)
  } catch (e) {
    console.error('保存失败:', e)
  } finally {
    saving.value = false
  }
}

async function restoreVersion(version: number) {
  if (!articleId.value || !confirm(`确定回滚到版本 ${version}？`)) return
  try {
    await restoreArticleVersion(articleId.value, version)
    // 重新加载文章内容
    const { data: res } = await getArticle(articleId.value)
    form.title = res.data.title
    form.content = res.data.content || ''
    form.summary = res.data.summary || ''
    loadVersions()
  } catch (e) {
    console.error('回滚失败:', e)
  }
}

function formatTime(dateStr: string): string {
  return new Date(dateStr).toLocaleString('zh-CN')
}
</script>

<style scoped>
.article-edit {
  max-width: 960px;
  margin: 0 auto;
}

.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
}

.header-actions {
  display: flex;
  gap: 8px;
}

.edit-form {
  background: white;
  padding: 24px;
  border-radius: 8px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.08);
}

.form-row {
  display: flex;
  gap: 16px;
}

.form-actions {
  display: flex;
  gap: 12px;
  margin-top: 20px;
  justify-content: flex-end;
}

.version-panel {
  background: white;
  padding: 20px;
  border-radius: 8px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.08);
  margin-bottom: 16px;
}

.version-panel h3 {
  font-size: 16px;
  margin-bottom: 12px;
}

.version-list {
  list-style: none;
}

.version-item {
  padding: 10px 0;
  border-bottom: 1px solid #f0f0f0;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.version-item:last-child {
  border-bottom: none;
}

.version-meta {
  display: flex;
  gap: 12px;
  font-size: 13px;
  color: #666;
}

.version-num {
  font-weight: 600;
  color: #4361ee;
}

.version-summary {
  font-size: 12px;
  color: #999;
  margin-top: 2px;
}

.btn-sm {
  padding: 4px 10px;
  font-size: 12px;
}

.loading, .empty-state {
  color: #999;
  font-size: 14px;
  text-align: center;
  padding: 20px;
}
</style>
