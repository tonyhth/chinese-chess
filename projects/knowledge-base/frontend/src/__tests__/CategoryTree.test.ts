import { mount } from '@vue/test-utils'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import CategoryTree from '@/components/CategoryTree.vue'
import { getCategoryTree } from '@/api/category'

vi.mock('@/api/category', () => ({
  getCategoryTree: vi.fn(),
}))

const mockTree = [
  {
    id: 1, parentId: null, name: '技术', slug: 'tech',
    description: null, sortOrder: 0, createdAt: '2025-01-01',
    children: [
      {
        id: 2, parentId: 1, name: '前端', slug: 'fe',
        description: null, sortOrder: 0, createdAt: '2025-01-01',
      },
    ],
  },
]

describe('CategoryTree', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('加载分类树并渲染', async () => {
    vi.mocked(getCategoryTree).mockResolvedValue({ data: { data: mockTree } } as any)
    const wrapper = mount(CategoryTree, { props: { modelValue: null } })
    await vi.dynamicImportSettled()
    // vi.waitFor or tick
    await new Promise(r => setTimeout(r, 0))
    expect(wrapper.text()).toContain('技术')
    expect(wrapper.text()).toContain('前端')
  })

  it('选中分类触发 v-model 更新', async () => {
    vi.mocked(getCategoryTree).mockResolvedValue({ data: { data: mockTree } } as any)
    const wrapper = mount(CategoryTree, { props: { modelValue: null } })
    await new Promise(r => setTimeout(r, 0))
    const radio = wrapper.find('input[type="radio"]')
    await radio.trigger('change')
    expect(wrapper.emitted('update:modelValue')!.flat()).toContain(1)
  })
})
