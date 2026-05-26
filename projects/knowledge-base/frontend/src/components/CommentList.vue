<template>
  <div class="comment-list-page">
    <div v-if="comments.length === 0" class="empty-state">暂无评论</div>
    <div v-for="comment in comments" :key="comment.id" class="comment-item">
      <div class="comment-header">
        <span class="comment-author">{{ comment.authorName || '匿名用户' }}</span>
        <span class="comment-time">{{ formatTime(comment.createdAt) }}</span>
        <span class="comment-article" @click="$router.push(`/articles/${comment.articleId}`)">
          📄 文章 #{{ comment.articleId }}
        </span>
      </div>
      <div class="comment-body" :class="{ deleted: comment.status === 0 }">
        {{ comment.content }}
      </div>
      <div class="comment-actions">
        <button class="btn-text" @click="$emit('delete', comment.id)">删除</button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { CommentDTO } from '@/types/api'

defineProps<{
  comments: CommentDTO[]
}>()

defineEmits<{
  delete: [commentId: number]
}>()

function formatTime(dateStr: string): string {
  return new Date(dateStr).toLocaleString('zh-CN')
}
</script>

<style scoped>
.comment-item {
  padding: 12px 0;
  border-bottom: 1px solid #f0f0f0;
}

.comment-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 4px;
  font-size: 13px;
}

.comment-author {
  font-weight: 600;
}

.comment-time {
  color: #aaa;
}

.comment-article {
  color: #4361ee;
  cursor: pointer;
}

.comment-body {
  font-size: 14px;
  line-height: 1.6;
}

.comment-body.deleted {
  color: #ccc;
  font-style: italic;
}

.comment-actions {
  margin-top: 4px;
}

.btn-text {
  background: none;
  border: none;
  color: #888;
  font-size: 12px;
  cursor: pointer;
}

.btn-text:hover {
  color: #e63946;
}
</style>
