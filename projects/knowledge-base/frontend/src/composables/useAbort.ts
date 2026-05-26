import { onMounted, onUnmounted } from 'vue'
import { cancelPending } from '@/api/request'

/**
 * 组件级请求取消 composable。
 * onMounted 时取消同一前缀的旧请求，onUnmounted 时取消当前组件的 pending 请求，防止状态污染。
 */
export function useAbort(prefix: string) {
  onMounted(() => cancelPending(prefix))
  onUnmounted(() => cancelPending(prefix))
}
