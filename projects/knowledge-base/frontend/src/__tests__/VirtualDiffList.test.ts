import { mount } from '@vue/test-utils'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import VirtualDiffList from '@/components/VirtualDiffList.vue'

const sampleParts = [
  { value: 'unchanged line\n', removed: false, added: false },
  { value: 'removed line\n', removed: true },
  { value: 'added line\n', added: true },
  { value: 'another unchanged\n', removed: false, added: false },
]

describe('VirtualDiffList', () => {
  it('空 parts 显示"无差异内容"', () => {
    const wrapper = mount(VirtualDiffList, { props: { parts: [] } })
    expect(wrapper.text()).toContain('无差异内容')
  })

  it('展平 parts 为单行数组', async () => {
    const wrapper = mount(VirtualDiffList, { props: { parts: sampleParts } })
    await new Promise(r => setTimeout(r, 0))
    const lines = wrapper.findAll('.diff-line')
    // unchanged + removed + added + another unchanged = 4
    expect(lines).toHaveLength(4)
  })

  it('正确标记 add/remove/neutral CSS 类', async () => {
    const wrapper = mount(VirtualDiffList, { props: { parts: sampleParts } })
    await new Promise(r => setTimeout(r, 0))
    const lines = wrapper.findAll('.diff-line')
    expect(lines[0].classes()).toContain('diff-neutral')
    expect(lines[1].classes()).toContain('diff-remove')
    expect(lines[2].classes()).toContain('diff-add')
    expect(lines[3].classes()).toContain('diff-neutral')
  })

  it('add 行显示 + 前缀', async () => {
    const wrapper = mount(VirtualDiffList, { props: { parts: sampleParts } })
    await new Promise(r => setTimeout(r, 0))
    const lines = wrapper.findAll('.diff-line')
    expect(lines[2].find('.diff-prefix-add').exists()).toBe(true)
    expect(lines[2].text()).toContain('added line')
  })

  it('remove 行显示 − 前缀', async () => {
    const wrapper = mount(VirtualDiffList, { props: { parts: sampleParts } })
    await new Promise(r => setTimeout(r, 0))
    const lines = wrapper.findAll('.diff-line')
    expect(lines[1].find('.diff-prefix-remove').exists()).toBe(true)
    expect(lines[1].text()).toContain('removed line')
  })

  it('neutral 行显示空白前缀', async () => {
    const wrapper = mount(VirtualDiffList, { props: { parts: sampleParts } })
    await new Promise(r => setTimeout(r, 0))
    const lines = wrapper.findAll('.diff-line')
    expect(lines[0].find('.diff-prefix-neutral').exists()).toBe(true)
  })

  it('虚拟滚动：只渲染可见行', async () => {
    // 生成 1000 行的 parts
    const bigParts = Array.from({ length: 500 }, (_, i) => ({
      value: `line ${i}\n`,
      removed: false, added: false,
    }))
    const wrapper = mount(VirtualDiffList, {
      props: { parts: bigParts, lineHeight: 24, buffer: 5 },
      attachTo: document.body,
    })
    await new Promise(r => setTimeout(r, 0))
    const visibleLines = wrapper.findAll('.diff-line')
    // 容器默认 400px，400/24 ≈ 17 行 + buffer 10*2 = 37，远少于 500
    expect(visibleLines.length).toBeLessThan(100)
    expect(visibleLines.length).toBeGreaterThan(0)
    wrapper.unmount()
  })

  it('title 属性正确设置', async () => {
    const wrapper = mount(VirtualDiffList, { props: { parts: sampleParts } })
    await new Promise(r => setTimeout(r, 0))
    const lines = wrapper.findAll('.diff-line')
    expect(lines[1].attributes('title')).toBe('已删除内容')
    expect(lines[2].attributes('title')).toBe('新增内容')
    expect(lines[0].attributes('title')).toBe('')
  })

  it('跳过末尾空行（split 产物）', async () => {
    const parts = [{ value: 'hello\n', added: true }]
    const wrapper = mount(VirtualDiffList, { props: { parts } })
    await new Promise(r => setTimeout(r, 0))
    expect(wrapper.findAll('.diff-line')).toHaveLength(1)
  })
})
