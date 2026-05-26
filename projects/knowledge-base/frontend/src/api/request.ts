import axios from 'axios'
import type { TokenResponse } from '@/types/api'

const API_BASE = '/api/v1'

const request = axios.create({
  baseURL: API_BASE,
  timeout: 10000,
  headers: { 'Content-Type': 'application/json' },
})

let isRefreshing = false
let refreshPending: Array<{ resolve: (token: string) => void; reject: (err: any) => void }> = []

// --- AbortController 管理 ---
const MAX_PENDING_REQUESTS = 50
const pendingRequests = new Map<string, AbortController>()

function normalizeUrl(rawUrl: string | undefined): string {
  if (!rawUrl) return '__unknown__'
  let url = rawUrl
  // 剥离 origin（http://...）
  try {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      const u = new URL(url)
      url = u.pathname + u.search
    }
  } catch { /* not a valid URL, keep as-is */ }
  // 剥离 baseURL 前缀
  if (API_BASE && url.startsWith(API_BASE)) {
    url = url.slice(API_BASE.length)
  }
  return url || '/'
}

export function createRequestKey(method: string | undefined, url: string | undefined, params?: any): string {
  const safeMethod = (method || 'get').toUpperCase()
  const normalizedUrl = normalizeUrl(url)
  return `req:${safeMethod}:${normalizedUrl}?${JSON.stringify(params || '')}`
}

/**
 * 取消匹配 prefix 的所有 pending 请求。
 * key 格式: req:METHOD:NORMALIZED_URL?PARAMS
 * 匹配时跳过 METHOD 段，用规范化后的 URL 路径做前缀安全匹配。
 */
export function cancelPending(prefix: string) {
  for (const [key, controller] of pendingRequests) {
    // key: req:METHOD:/path?params → 跳过 req: 和 METHOD:
    const afterReq = key.startsWith('req:') ? key.slice(4) : key
    const colonIdx = afterReq.indexOf(':')
    const urlPart = colonIdx >= 0 ? afterReq.slice(colonIdx + 1) : afterReq
    // urlPart 现在是规范化后的路径，如 /articles?{"page":1}
    // 路径安全匹配
    if (urlPart === prefix || urlPart.startsWith(prefix + '/') || urlPart.startsWith(prefix + '?')) {
      controller.abort()
      pendingRequests.delete(key)
    }
  }
}

function setToken(token: string) {
  localStorage.setItem('access_token', token)
  localStorage.setItem('token_time', String(Date.now()))
}

function getToken(): string | null {
  return localStorage.getItem('access_token')
}

function getRefreshToken(): string | null {
  return localStorage.getItem('refresh_token')
}

function clearTokens() {
  localStorage.removeItem('access_token')
  localStorage.removeItem('refresh_token')
  localStorage.removeItem('token_time')
}

// 请求拦截器：自动带 Bearer token + AbortController
request.interceptors.request.use((config) => {
  const token = getToken()
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }

  // AbortController: 如果调用方自带 signal，不接管
  if (!config.signal) {
    const key = createRequestKey(config.method || 'get', config.url, config.params)
    const controller = new AbortController()
    config.signal = controller.signal

    // 超限清理最早的请求
    if (pendingRequests.size >= MAX_PENDING_REQUESTS) {
      const firstEntry = pendingRequests.entries().next().value
      if (firstEntry) {
        const [oldestKey, oldestCtrl] = firstEntry
        oldestCtrl.abort()
        pendingRequests.delete(oldestKey)
      }
    }
    pendingRequests.set(key, controller)
  }

  return config
})

// 响应拦截器：401 自动 refresh + 清理 pending
request.interceptors.response.use(
  (response) => {
    // 成功响应，清理 pending map
    const key = createRequestKey(response.config.method || 'get', response.config.url, response.config.params)
    pendingRequests.delete(key)
    return response
  },
  async (error) => {
    // 取消的请求静默处理，不弹 toast，也无需清理（cancelPending 已清理）
    if (axios.isCancel(error)) {
      return Promise.reject(error)
    }

    // 非取消的失败请求，清理 pending map
    if (error.config?.url) {
      const key = createRequestKey(error.config.method || 'get', error.config.url, error.config.params)
      pendingRequests.delete(key)
    }

    const originalRequest = error.config

    if (error.response?.status === 401 && !originalRequest._retry) {
      // 刷新接口本身 401 → 跳登录
      if (originalRequest.url?.includes('/auth/refresh')) {
        clearTokens()
        window.location.href = '/login'
        return Promise.reject(error)
      }

      // 登录接口 401 → 直接报错
      if (originalRequest.url?.includes('/auth/login')) {
        return Promise.reject(error)
      }

      if (isRefreshing) {
        // 排队等待 refresh 完成
        return new Promise((resolve, reject) => {
          refreshPending.push({ resolve, reject })
        }).then((token) => {
          originalRequest.headers.Authorization = `Bearer ${token}`
          return request(originalRequest)
        })
      }

      originalRequest._retry = true
      isRefreshing = true

      try {
        const refreshToken = getRefreshToken()
        if (!refreshToken) throw new Error('No refresh token')

        const { data } = await axios.post<TokenResponse>(`${API_BASE}/auth/refresh`, {
          refreshToken,
        })

        setToken(data.data.accessToken)
        localStorage.setItem('refresh_token', data.data.refreshToken)

        // 重放排队的请求
        refreshPending.forEach(({ resolve }) => resolve(data.data.accessToken))
        refreshPending = []

        originalRequest.headers.Authorization = `Bearer ${data.data.accessToken}`
        return request(originalRequest)
      } catch (refreshError) {
        refreshPending.forEach(({ reject }) => reject(refreshError))
        refreshPending = []
        clearTokens()
        window.location.href = '/login'
        return Promise.reject(refreshError)
      } finally {
        isRefreshing = false
      }
    }

    return Promise.reject(error)
  }
)

export { request, setToken, getToken, getRefreshToken, clearTokens }
export default request
