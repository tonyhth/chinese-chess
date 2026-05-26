<template>
  <div class="dashboard">
    <h2>仪表盘</h2>

    <div v-if="loading" class="loading">加载中...</div>
    <div v-else class="stats-grid">
      <div class="stat-card">
        <div class="stat-icon">📝</div>
        <div class="stat-info">
          <span class="stat-value">{{ stats.articleCount }}</span>
          <span class="stat-label">文章数</span>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon">👥</div>
        <div class="stat-info">
          <span class="stat-value">{{ stats.userCount }}</span>
          <span class="stat-label">用户数</span>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon">📂</div>
        <div class="stat-info">
          <span class="stat-value">{{ stats.categoryCount }}</span>
          <span class="stat-label">分类数</span>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon">🏷️</div>
        <div class="stat-info">
          <span class="stat-value">{{ stats.tagCount }}</span>
          <span class="stat-label">标签数</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import type { DashboardStats } from '@/types/api'
import { getDashboardStats } from '@/api/dashboard'

const stats = ref<DashboardStats>({ articleCount: 0, userCount: 0, categoryCount: 0, tagCount: 0 })
const loading = ref(true)

onMounted(async () => {
  try {
    const { data: res } = await getDashboardStats()
    stats.value = res.data
  } catch (e) {
    console.error('加载统计失败:', e)
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.dashboard h2 {
  margin-bottom: 20px;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 16px;
}

.stat-card {
  background: white;
  padding: 20px;
  border-radius: 8px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.08);
  display: flex;
  align-items: center;
  gap: 16px;
}

.stat-icon {
  font-size: 28px;
}

.stat-info {
  display: flex;
  flex-direction: column;
}

.stat-value {
  font-size: 28px;
  font-weight: 700;
  color: #1a1a2e;
  line-height: 1.2;
}

.stat-label {
  font-size: 13px;
  color: #888;
  margin-top: 2px;
}

.loading {
  color: #999;
  font-size: 14px;
  text-align: center;
  padding: 20px;
}
</style>
