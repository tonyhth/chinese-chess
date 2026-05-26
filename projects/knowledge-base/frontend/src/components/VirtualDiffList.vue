<template>
  <div
    ref="containerRef"
    class="virtual-diff"
    @scroll="onScroll"
  >
    <div v-if="flatLines.length === 0" class="diff-empty">无差异内容</div>
    <div v-else class="virtual-diff-spacer" :style="{ height: `${totalHeight}px` }">
      <div
        class="virtual-diff-viewport"
        :style="{ transform: `translateY(${offsetY}px)` }"
      >
        <div
          v-for="line in visibleLines"
          :key="line.index"
          class="diff-line"
          :class="line.className"
          :title="line.title"
        >
          <span v-if="line.type === 'add'" class="diff-prefix diff-prefix-add">+ </span>
          <span v-else-if="line.type === 'remove'" class="diff-prefix diff-prefix-remove">− </span>
          <span v-else class="diff-prefix diff-prefix-neutral">&nbsp;&nbsp;</span>
          {{ line.text }}
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'

interface DiffPart {
  value: string
  added?: boolean
  removed?: boolean
}

interface FlatLine {
  index: number
  text: string
  type: 'add' | 'remove' | 'neutral'
  className: string
  title: string
}

const props = withDefaults(defineProps<{
  parts: DiffPart[]
  lineHeight?: number
  buffer?: number
}>(), {
  lineHeight: 24,
  buffer: 10,
})

const containerRef = ref<HTMLElement | null>(null)
const scrollTop = ref(0)
const containerHeight = ref(400)

// 将 parts 展平为单行数组
const flatLines = computed<FlatLine[]>(() => {
  const lines: FlatLine[] = []
  let idx = 0
  for (const part of props.parts) {
    const textLines = part.value.split('\n')
    // 末尾空行（diff 通常会产生）跳过
    for (let i = 0; i < textLines.length; i++) {
      const text = textLines[i]
      // 跳过最后一个空行（split 产物）
      if (i === textLines.length - 1 && text === '' && textLines.length > 1) continue
      const type = part.added ? 'add' : part.removed ? 'remove' : 'neutral'
      lines.push({
        index: idx++,
        text,
        type,
        className: type === 'add' ? 'diff-add' : type === 'remove' ? 'diff-remove' : 'diff-neutral',
        title: part.added ? '新增内容' : part.removed ? '已删除内容' : '',
      })
    }
  }
  return lines
})

const totalHeight = computed(() => flatLines.value.length * props.lineHeight)

const startIndex = computed(() => {
  const idx = Math.floor(scrollTop.value / props.lineHeight) - props.buffer
  return Math.max(0, idx)
})

const endIndex = computed(() => {
  const visible = Math.ceil(containerHeight.value / props.lineHeight) + 2 * props.buffer
  return Math.min(flatLines.value.length, startIndex.value + visible)
})

const offsetY = computed(() => startIndex.value * props.lineHeight)

const visibleLines = computed(() => flatLines.value.slice(startIndex.value, endIndex.value))

let rafId: number | null = null

function onScroll() {
  if (rafId !== null) return
  rafId = requestAnimationFrame(() => {
    if (containerRef.value) {
      scrollTop.value = containerRef.value.scrollTop
    }
    rafId = null
  })
}

let resizeObserver: ResizeObserver | null = null

onMounted(() => {
  if (containerRef.value) {
    containerHeight.value = containerRef.value.clientHeight
    resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        containerHeight.value = entry.contentRect.height
      }
    })
    resizeObserver.observe(containerRef.value)
  }
})

onUnmounted(() => {
  resizeObserver?.disconnect()
  if (rafId !== null) cancelAnimationFrame(rafId)
})
</script>

<style scoped>
.virtual-diff {
  max-height: 400px;
  overflow-y: auto;
  font-family: 'Menlo', 'Monaco', monospace;
  font-size: 13px;
  line-height: 24px;
  white-space: pre-wrap;
  word-break: break-all;
}

.virtual-diff-spacer {
  position: relative;
}

.virtual-diff-viewport {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
}

.diff-line {
  min-height: 24px;
  padding: 0 8px;
  overflow-x: auto;
}

.diff-add {
  color: #22863a;
  background: #e8f5e9;
}
.diff-remove {
  color: #e63946;
  background: #fde8ec;
  text-decoration: line-through;
}
.diff-neutral {
  color: #333;
}

.diff-prefix {
  font-weight: 700;
  user-select: none;
}
.diff-empty { color: #999; font-size: 14px; text-align: center; padding: 24px 0; }
.diff-prefix-add { color: #22863a; }
.diff-prefix-remove { color: #e63946; }
.diff-prefix-neutral { color: transparent; }
</style>
