<template>
  <MdEditor
    v-model="content"
    :style="{ height: '500px' }"
    :preview="true"
    :toolbars="toolbars"
    :sanitize="sanitizeHtml"
    @on-upload-img="handleUploadImage"
  />
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { MdEditor } from 'md-editor-v3'
import 'md-editor-v3/lib/style.css'
import request from '@/api/request'

const props = defineProps<{
  modelValue: string
}>()

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

const content = ref(props.modelValue)

watch(() => props.modelValue, (val) => {
  content.value = val
})

watch(content, (val) => {
  emit('update:modelValue', val)
})

const toolbars = [
  'bold', 'italic', 'strikeThrough', '|',
  'title', 'quote', 'unorderedList', 'orderedList', '|',
  'codeRow', 'code', 'link', 'image', '|',
  'revoke', 'redo', '|',
  'preview', 'fullscreen',
] as any[]

async function handleUploadImage(files: File[], callback: (urls: string[]) => void) {
  const promises = files.map(async (file) => {
    const formData = new FormData()
    formData.append('file', file)
    const { data: res } = await request.post('/upload/image', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    return res.data.url
  })
  const urls = await Promise.all(promises)
  callback(urls)
}

function sanitizeHtml(html: string): string {
  return html
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<script[^>]*\/?>/gi, '')
    .replace(/\s+on\w+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)/gi, '')
    .replace(/javascript\s*:/gi, '')
}
</script>
