import { describe, it, expect } from 'vitest'
import { diffLines } from 'diff'

describe('Diff 逻辑（ArticleDetail 中 renderDiff 的核心）', () => {
  const oldContent = '# Title\nHello World\nGoodbye World'
  const newContent = '# Title\nHello World\nGoodbye Moon\nNew Line'

  function computeDiff(oldText: string, newText: string, direction: 'forward' | 'reverse') {
    const old = direction === 'forward' ? oldText : newText
    const cur = direction === 'forward' ? newText : oldText
    return diffLines(old, cur)
  }

  it('forward 方向正确标记 added/removed', () => {
    const parts = computeDiff(oldContent, newContent, 'forward')
    const added = parts.filter(p => p.added)
    const removed = parts.filter(p => p.removed)

    expect(added.length).toBeGreaterThan(0)
    expect(removed.length).toBeGreaterThan(0)
    expect(added.some(p => p.value.includes('Moon'))).toBe(true)
    expect(removed.some(p => p.value.includes('World') && !p.value.includes('Moon'))).toBe(true)
  })

  it('reverse 方向交换 old/new', () => {
    const fwd = computeDiff(oldContent, newContent, 'forward')
    const rev = computeDiff(oldContent, newContent, 'reverse')

    // reverse 的 added 应该是 forward 的 removed
    const fwdAddedTexts = fwd.filter(p => p.added).map(p => p.value)
    const revRemovedTexts = rev.filter(p => p.removed).map(p => p.value)
    expect(revRemovedTexts).toEqual(fwdAddedTexts)
  })

  it('相同内容没有 added/removed', () => {
    const parts = computeDiff('same content', 'same content', 'forward')
    expect(parts.filter(p => p.added || p.removed).length).toBe(0)
  })

  it('空旧内容全部标记为 added', () => {
    const parts = computeDiff('', 'new content\n', 'forward')
    expect(parts.filter(p => p.added).length).toBe(parts.length)
  })

  it('空新内容全部标记为 removed', () => {
    const parts = computeDiff('old content\n', '', 'forward')
    expect(parts.filter(p => p.removed).length).toBe(parts.length)
  })
})
