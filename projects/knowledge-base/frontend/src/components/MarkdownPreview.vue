<template>
  <MdPreview :model-value="content" :style="{ fontSize: '15px' }" :sanitize="sanitizeHtml" />
</template>

<script setup lang="ts">
import { MdPreview } from 'md-editor-v3'
import 'md-editor-v3/lib/preview.css'

defineProps<{
  content: string
}>()

function sanitizeHtml(html: string): string {
  return html
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<script[^>]*\/?>/gi, '')
    .replace(/\s+on\w+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)/gi, '')
    .replace(/javascript\s*:/gi, '')
}
</script>

<style scoped>
:deep(.md-editor-preview-wrapper) {
  padding: 16px 24px;
}

:deep(.md-editor-preview) {
  line-height: 1.7;
}
</style>
