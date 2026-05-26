<template>
  <div class="search-page">
    <h1 class="page-title">全文搜索</h1>

    <!-- 搜索框 -->
    <div class="search-box-wrapper">
      <input
        v-model="query"
        class="form-input search-input"
        placeholder="搜索文章标题、内容、摘要..."
        @input="onQueryInput"
        @keyup.enter="doSearch(1)"
        @focus="showSuggest = true"
      />
      <button class="btn btn-primary" @click="doSearch(1)" :disabled="!query.trim()">搜索</button>

      <!-- 搜索建议 -->
      <div v-if="showSuggest && suggestions.length > 0" class="suggest-dropdown">
        <div
          v-for="s in suggestions"
          :key="s.text"
          class="suggest-item"
          @click="applySuggestion(s.text)"
        >
          {{ s.text }}
        </div>
      </div>
    </div>

    <!-- 过滤面板 -->
    <div class="filter-panel">
      <div class="filter-row">
        <div class="filter-group">
          <label>分类</label>
          <select v-model="selectedCategoryId" class="form-select" @change="doSearch(1)">
            <option :value="undefined">全部分类</option>
            <option v-for="cat in categories" :key="cat.id" :value="cat.id">{{ cat.name }}</option>
          </select>
        </div>

        <div class="filter-group">
          <label>标签（多选 AND）</label>
          <div class="tag-filter">
            <span
              v-for="tag in tags"
              :key="tag.id"
              class="tag-chip"
              :class="{ active: selectedTagNames.includes(tag.name) }"
              @click="toggleTag(tag.name)"
            >
              <span v-if="tag.color" class="tag-dot" :style="{ background: tag.color }"></span>
              {{ tag.name }}
            </span>
          </div>
        </div>

        <div class="filter-group">
          <label>日期范围</label>
          <div class="date-row">
            <input v-model="dateFrom" type="date" class="form-input" @change="doSearch(1)" />
            <span>至</span>
            <input v-model="dateTo" type="date" class="form-input" @change="doSearch(1)" />
          </div>
        </div>

        <div class="filter-group">
          <label>排序</label>
          <select v-model="sortBy" class="form-select" @change="doSearch(1)">
            <option value="relevance">相关度</option>
            <option value="newest">最新</option>
            <option value="oldest">最早</option>
          </select>
        </div>
      </div>
    </div>

    <!-- 结果区域 -->
    <div class="result-count" v-if="total > 0">共 {{ total }} 条结果</div>

    <div v-if="loading" class="loading">搜索中...</div>
    <div v-else-if="searched && total === 0" class="empty-state">未找到相关结果</div>
    <div v-else>
      <div
        v-for="hit in hits"
        :key="hit.articleId"
        class="result-card"
        @click="goToArticle(hit.articleId)"
      >
        <div class="result-title" v-html="hit.title || ''"></div>
        <div v-if="hit.summary" class="result-summary" v-html="hit.summary"></div>
        <div v-if="hit.contentHighlights?.length" class="content-highlights">
          <div v-for="(hl, i) in hit.contentHighlights" :key="i" class="hl-text" v-html="hl"></div>
        </div>
        <div class="result-meta">
          <span v-if="hit.categoryName">📁 {{ hit.categoryName }}</span>
          <span v-if="hit.authorName">👤 {{ hit.authorName }}</span>
          <span v-if="hit.updatedAt">📅 {{ formatTime(hit.updatedAt) }}</span>
          <span v-if="hit.tagNames?.length" class="tag-list">
            <span v-for="tag in hit.tagNames" :key="tag" class="meta-tag">{{ tag }}</span>
          </span>
        </div>
      </div>
    </div>

    <!-- 分页 -->
    <div v-if="totalPages > 1" class="pagination-wrapper">
      <button class="btn btn-sm" :disabled="page <= 1" @click="doSearch(page - 1)">上一页</button>
      <span class="page-info">{{ page }} / {{ totalPages }}</span>
      <button class="btn btn-sm" :disabled="page >= totalPages" @click="doSearch(page + 1)">下一页</button>
    </div>
  </div>
</template>

<script setup lang="ts">
import DOMPurify from 'dompurify'
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { searchArticles, getSearchSuggestions } from '@/api/search'
import { getCategoryTree } from '@/api/category'
import { getTags } from '@/api/tag'
import type { CategoryDTO, TagDTO } from '@/types/api'
import { useAbort } from '@/composables/useAbort'

useAbort('/search')

const router = useRouter()

const query = ref('')
const sortBy = ref<'relevance' | 'newest' | 'oldest'>('relevance')
const selectedCategoryId = ref<number | undefined>(undefined)
const selectedTagNames = ref<string[]>([])
const dateFrom = ref('')
const dateTo = ref('')

const page = ref(1)
const size = 20
const total = ref(0)
const hits = ref<any[]>([])
const loading = ref(false)
const searched = ref(false)
const suggestions = ref<{ text: string; articleId: number | null }[]>([])
const showSuggest = ref(false)

const categories = ref<CategoryDTO[]>([])
const tags = ref<TagDTO[]>([])

const totalPages = computed(() => Math.ceil(total.value / size))

let suggestTimer: ReturnType<typeof setTimeout> | null = null

function handleDocClick(e: MouseEvent) {
  const el = document.querySelector('.search-box-wrapper')
  if (el && !el.contains(e.target as Node)) showSuggest.value = false
}

onMounted(async () => {
  document.addEventListener('mousedown', handleDocClick)
  try {
    const [catRes, tagRes] = await Promise.all([
      getCategoryTree().catch(() => ({ data: { data: [] } })),
      getTags().catch(() => ({ data: { data: [] } })),
    ])
    // Flatten category tree for select
    categories.value = flattenCategories(catRes.data?.data || [])
    tags.value = tagRes.data?.data || []
  } catch (e) {
    console.error('加载过滤条件失败:', e)
  }
})

onUnmounted(() => {
  document.removeEventListener('mousedown', handleDocClick)
  if (suggestTimer) clearTimeout(suggestTimer)
})

function onQueryInput() {
  showSuggest.value = true
  if (suggestTimer) clearTimeout(suggestTimer)
  suggestTimer = setTimeout(async () => {
    const q = query.value.trim()
    if (!q) { suggestions.value = []; return }
    try {
      const res = await getSearchSuggestions(q, 8)
      suggestions.value = res.data?.data?.suggestions || []
    } catch { suggestions.value = [] }
  }, 200)
}

function applySuggestion(text: string) {
  query.value = text
  showSuggest.value = false
  suggestions.value = []
  doSearch(1)
}

function toggleTag(name: string) {
  const idx = selectedTagNames.value.indexOf(name)
  if (idx >= 0) selectedTagNames.value.splice(idx, 1)
  else selectedTagNames.value.push(name)
  doSearch(1)
}

async function doSearch(p: number) {
  const q = query.value.trim()
  if (!q) return
  showSuggest.value = false
  loading.value = true
  page.value = p
  try {
    const res = await searchArticles({
      query: q,
      categoryId: selectedCategoryId.value,
      tagNames: selectedTagNames.value.length > 0 ? selectedTagNames.value : undefined,
      dateFrom: dateFrom.value || undefined,
      dateTo: dateTo.value || undefined,
      sort: sortBy.value === 'relevance' ? undefined : sortBy.value,
      page: p,
      size,
    })
    const data = res.data?.data
    hits.value = (data?.hits || []).map((hit: any) => ({
      ...hit,
      title: sanitizeHighlight(hit.title),
      summary: sanitizeHighlight(hit.summary),
      contentHighlights: (hit.contentHighlights || []).map(sanitizeHighlight),
    }))
    total.value = data?.total || 0
    searched.value = true
  } catch (e) {
    console.error('搜索失败:', e)
    hits.value = []
    total.value = 0
  } finally {
    loading.value = false
  }
}

function flattenCategories(tree: CategoryDTO[]): CategoryDTO[] {
  const result: CategoryDTO[] = []
  for (const c of tree) {
    result.push(c)
    if (c.children) result.push(...flattenCategories(c.children))
  }
  return result
}

function sanitizeHighlight(html: string | null): string {
  if (!html) return ''
  return DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ['em'],
    ALLOWED_ATTR: ['class'],
  })
}

function goToArticle(articleId: number) {
  router.push(`/articles/${articleId}`)
}

function formatTime(dateStr: string | null): string {
  if (!dateStr) return ''
  return new Date(dateStr).toLocaleString('zh-CN')
}
</script>

<style scoped>
.search-page { max-width: 900px; margin: 0 auto; padding: 20px; }
.page-title { font-size: 24px; margin-bottom: 20px; }

.search-box-wrapper { position: relative; display: flex; gap: 8px; margin-bottom: 16px; }
.search-input { flex: 1; }

.suggest-dropdown {
  position: absolute; top: 100%; left: 0; right: 60px;
  background: white; border: 1px solid #e0e0e0; border-radius: 0 0 6px 6px;
  max-height: 240px; overflow-y: auto; box-shadow: 0 4px 12px rgba(0,0,0,0.1); z-index: 10;
}
.suggest-item { padding: 10px 14px; cursor: pointer; font-size: 14px; }
.suggest-item:hover { background: #f0f0f5; }

.filter-panel { background: white; padding: 16px; border-radius: 8px; margin-bottom: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.06); }
.filter-row { display: flex; flex-wrap: wrap; gap: 16px; }
.filter-group { min-width: 150px; }
.filter-group label { display: block; font-size: 12px; color: #888; margin-bottom: 4px; font-weight: 600; }
.tag-filter { display: flex; flex-wrap: wrap; gap: 6px; }
.tag-chip {
  display: inline-flex; align-items: center; gap: 4px; padding: 3px 10px;
  background: #f0f0f5; border-radius: 12px; font-size: 12px; color: #555; cursor: pointer;
  transition: all 0.15s;
}
.tag-chip.active { background: #4361ee; color: white; }
.tag-dot { width: 8px; height: 8px; border-radius: 50%; }
.date-row { display: flex; align-items: center; gap: 8px; }
.date-row input { width: 140px; }

.result-count { font-size: 13px; color: #888; margin-bottom: 12px; }
.result-card {
  background: white; padding: 16px; border-radius: 8px; margin-bottom: 12px;
  cursor: pointer; transition: box-shadow 0.2s; box-shadow: 0 1px 3px rgba(0,0,0,0.06);
}
.result-card:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
.result-title { font-size: 16px; font-weight: 600; margin-bottom: 6px; color: #333; }
.result-summary { font-size: 13px; color: #666; margin-bottom: 6px; }
.content-highlights { margin-bottom: 8px; }
.hl-text { font-size: 13px; color: #888; padding: 2px 0 2px 8px; border-left: 3px solid #e6a23c; margin-bottom: 4px; }
.result-meta { display: flex; flex-wrap: wrap; gap: 12px; font-size: 12px; color: #999; }
.meta-tag { padding: 1px 6px; background: #f0f0f5; border-radius: 8px; font-size: 11px; }

.pagination-wrapper { display: flex; justify-content: center; align-items: center; gap: 12px; margin-top: 20px; }
.page-info { font-size: 13px; color: #666; }

.loading, .empty-state { text-align: center; color: #999; padding: 30px; font-size: 14px; }
</style>
