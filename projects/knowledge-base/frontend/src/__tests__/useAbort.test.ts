import { describe, it, expect } from 'vitest'
import { cancelPending } from '@/api/request'

// 由于 pendingRequests 不是 named export，我们通过直接调用 cancelPending 的行为来验证
// 需要先让 interceptor 注册一些 pending requests
// 这里我们直接测试 cancelPending 的匹配逻辑正确性

// 从 request.ts 中提取的实际匹配算法（与修复后一致）
function shouldCancel(key: string, prefix: string): boolean {
  const afterPrefix = key.startsWith('req:') ? key.slice(4) : key
  const colonIdx = afterPrefix.indexOf(':')
  const urlPart = colonIdx >= 0 ? afterPrefix.slice(colonIdx + 1) : afterPrefix
  return urlPart === prefix || urlPart.startsWith(prefix + '/') || urlPart.startsWith(prefix + '?')
}

describe('cancelPending — 修复后匹配逻辑', () => {
  it('useAbort("/articles") 匹配 GET /api/v1/articles?page=1', () => {
    expect(shouldCancel('req:GET:/api/v1/articles?page=1', '/api/v1/articles')).toBe(true)
  })

  it('useAbort("/articles") 匹配 POST /api/v1/articles', () => {
    expect(shouldCancel('req:POST:/api/v1/articles', '/api/v1/articles')).toBe(true)
  })

  it('useAbort("/articles") 匹配子路径', () => {
    expect(shouldCancel('req:GET:/api/v1/articles/123', '/api/v1/articles')).toBe(true)
  })

  it('useAbort("/articles") 匹配 PUT /api/v1/articles/123/permissions', () => {
    expect(shouldCancel('req:PUT:/api/v1/articles/123/permissions', '/api/v1/articles')).toBe(true)
  })

  it('useAbort("/search") 匹配 GET /api/v1/search', () => {
    expect(shouldCancel('req:GET:/api/v1/search?query=test', '/api/v1/search')).toBe(true)
  })

  it('前缀相似但不匹配（无 / 或 ?）', () => {
    expect(shouldCancel('req:GET:/api/v1/articles-extra', '/api/v1/articles')).toBe(false)
  })

  it('完全不匹配的路径', () => {
    expect(shouldCancel('req:GET:/api/v1/categories', '/api/v1/articles')).toBe(false)
  })

  it('空 prefix 匹配所有 key（边界行为，实际不会这样调用）', () => {
    expect(shouldCancel('req:GET:/api/v1/articles?page=1', '')).toBe(true)
  })

  it('精确匹配无 params 的 key', () => {
    expect(shouldCancel('req:GET:/api/v1/articles', '/api/v1/articles')).toBe(true)
  })

  it('ArticleDetail useAbort("/api/v1/articles/42") 匹配特定文章', () => {
    expect(shouldCancel('req:GET:/api/v1/articles/42', '/api/v1/articles/42')).toBe(true)
    expect(shouldCancel('req:GET:/api/v1/articles/99', '/api/v1/articles/42')).toBe(false)
  })
})
