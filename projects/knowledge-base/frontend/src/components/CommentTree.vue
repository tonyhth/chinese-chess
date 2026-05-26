<template>
  <div class="comment-tree">
    <div v-for="comment in comments" :key="comment.id" class="comment-item">
      <div class="comment-header">
        <span class="comment-author">{{ comment.authorName || '匿名用户' }}</span>
        <span class="comment-time">{{ formatTime(comment.createdAt) }}</span>
      </div>
      <div class="comment-body" :class="{ deleted: comment.status === 0 }">
        {{ comment.content }}
      </div>
      <div class="comment-actions">
        <button class="btn-text" @click="$emit('reply', comment.id)">回复</button>
        <button
          v-if="canDelete(comment)"
          class="btn-text btn-text-danger"
          @click="$emit('delete', comment.id)"
        >
          删除
        </button>
      </div>

      <!-- 递归子评论 -->
      <div v-if="comment.replies?.length" class="comment-children">
        <CommentTree
          :comments="comment.replies"
          :user-id="userId"
          :role="role"
          @reply="(id: number) => $emit('reply', id)"
          @delete="(id: number) => $emit('delete', id)"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { CommentDTO } from '@/types/api'

const props = defineProps<{
  comments: CommentDTO[]
  userId?: number
  role: string | null
}>()

defineEmits<{
  reply: [commentId: number]
  delete: [commentId: number]
}>()

function canDelete(comment: CommentDTO): boolean {
  if (!props.userId && !props.role) return false
  return props.role === 'ADMIN' || comment.authorId === props.userId
}

function formatTime(dateStr: string): string {
  return new Date(dateStr).toLocaleString('zh-CN')
}
</script>

<style scoped>
.comment-item {
  padding: 12px 0;
  border-bottom: 1px solid #f0f0f0;
}

.comment-item:last-child {
  border-bottom: none;
}

.comment-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 4px;
}

.comment-author {
  font-weight: 600;
  font-size: 14px;
}

.comment-time {
  font-size: 12px;
  color: #aaa;
}

.comment-body {
  font-size: 14px;
  line-height: 1.6;
  color: #333;
  white-space: pre-wrap;
  word-break: break-word;
}

.comment-body.deleted {
  color: #ccc;
  font-style: italic;
}

.comment-actions {
  margin-top: 4px;
  display: flex;
  gap: 12px;
}

.btn-text {
  background: none;
  border: none;
  color: #888;
  font-size: 12px;
  cursor: pointer;
  padding: 2px 0;
}

.btn-text:hover {
  color: #4361ee;
}

.btn-text-danger:hover {
  color: #e63946;
}

.comment-children {
  padding-left: 24px;
  border-left: 2px solid #f0f0f0;
  margin-left: 8px;
}
</style>
