import { mount } from '@vue/test-utils'
import { describe, it, expect, vi } from 'vitest'
import CategoryTreeItem from '@/components/CategoryTreeItem.vue'
import type { CategoryDTO } from '@/types/api'

function makeNode(overrides?: Partial<CategoryDTO>): CategoryDTO {
  return {
    id: 1,
    parentId: null,
    name: 'Root',
    slug: 'root',
    description: null,
    sortOrder: 0,
    createdAt: '2025-01-01',
    ...overrides,
  }
}

const tree: CategoryDTO = makeNode({
  id: 1,
  name: '技术',
  slug: 'tech',
  children: [
    makeNode({ id: 2, name: '前端', slug: 'fe', parentId: 1 }),
    makeNode({
      id: 3, name: '后端', slug: 'be', parentId: 1,
      children: [
        makeNode({ id: 4, name: 'Java', slug: 'java', parentId: 3 }),
        makeNode({ id: 5, name: 'Python', slug: 'python', parentId: 3 }),
      ],
    }),
  ],
})

describe('CategoryTreeItem', () => {
  it('渲染分类名称', () => {
    const wrapper = mount(CategoryTreeItem, {
      props: { node: tree, depth: 0, modelValue: null },
    })
    expect(wrapper.text()).toContain('技术')
  })

  it('递归渲染子节点', () => {
    const wrapper = mount(CategoryTreeItem, {
      props: { node: tree, depth: 0, modelValue: null },
    })
    expect(wrapper.text()).toContain('前端')
    expect(wrapper.text()).toContain('后端')
    expect(wrapper.text()).toContain('Java')
    expect(wrapper.text()).toContain('Python')
  })

  it('多层级缩进：depth 越大 paddingLeft 越大', () => {
    const wrapper = mount(CategoryTreeItem, {
      props: { node: tree, depth: 0, modelValue: null },
    })
    const rows = wrapper.findAll('.tree-row')
    // depth=0 → 0*20+8=8px, depth=1 → 28px, depth=2 → 48px
    expect(rows[0].attributes('style')).toContain('padding-left: 8px')
    expect(rows[1].attributes('style')).toContain('padding-left: 28px')
    expect(rows[3].attributes('style')).toContain('padding-left: 48px')
  })

  it('有子节点的显示折叠箭头和 📂，无子节点显示 📄', () => {
    const wrapper = mount(CategoryTreeItem, {
      props: { node: tree, depth: 0, modelValue: null },
    })
    const arrows = wrapper.findAll('.toggle-arrow')
    const icons = wrapper.findAll('.tree-icon')

    // 技术(有子) → ▼; 前端(无子) → placeholder; 后端(有子) → ▼; Java(无子) → placeholder; Python(无子) → placeholder
    expect(arrows[0].text()).toBe('▼')
    expect(arrows[1].classes()).toContain('placeholder')
    expect(icons[0].text()).toBe('📂')
    expect(icons[1].text()).toBe('📄')
  })

  it('默认展开，点击箭头可折叠/展开', async () => {
    const wrapper = mount(CategoryTreeItem, {
      props: { node: tree, depth: 0, modelValue: null },
    })
    // 默认展开，子节点可见
    expect(wrapper.text()).toContain('前端')

    // 点击折叠
    await wrapper.find('.toggle-arrow').trigger('click')
    expect(wrapper.text()).not.toContain('前端')

    // 再次点击展开
    await wrapper.find('.toggle-arrow').trigger('click')
    expect(wrapper.text()).toContain('前端')
  })

  it('选中分类 emit update:modelValue', async () => {
    const wrapper = mount(CategoryTreeItem, {
      props: { node: tree, depth: 0, modelValue: null },
    })
    const radios = wrapper.findAll('input[type="radio"]')
    await radios[1].trigger('change') // 选中 "前端" id=2
    expect(wrapper.emitted('update:modelValue')!.flat()).toContain(2)
  })

  it('modelValue 匹配时 radio checked', () => {
    const wrapper = mount(CategoryTreeItem, {
      props: { node: tree, depth: 0, modelValue: 2 },
    })
    const radios = wrapper.findAll('input[type="radio"]')
    expect(radios[1].element.checked).toBe(true) // id=2
    expect(radios[0].element.checked).toBe(false) // id=1
  })
})
