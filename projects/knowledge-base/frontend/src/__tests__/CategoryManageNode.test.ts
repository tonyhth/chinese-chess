import { mount } from '@vue/test-utils'
import { describe, it, expect } from 'vitest'
import CategoryManageNode from '@/components/CategoryManageNode.vue'
import type { CategoryDTO } from '@/types/api'

function makeNode(overrides?: Partial<CategoryDTO>): CategoryDTO {
  return {
    id: 1, parentId: null, name: 'Root', slug: 'root',
    description: null, sortOrder: 0, createdAt: '2025-01-01',
    ...overrides,
  }
}

const tree: CategoryDTO = makeNode({
  id: 1, name: '技术', slug: 'tech',
  children: [
    makeNode({ id: 2, name: '前端', slug: 'fe', parentId: 1 }),
    makeNode({
      id: 3, name: '后端', slug: 'be', parentId: 1,
      children: [makeNode({ id: 4, name: 'Java', slug: 'java', parentId: 3 })],
    }),
  ],
})

describe('CategoryManageNode', () => {
  it('渲染分类名、slug、子分类数', () => {
    const wrapper = mount(CategoryManageNode, {
      props: { node: tree, depth: 0 },
    })
    expect(wrapper.text()).toContain('技术')
    expect(wrapper.text()).toContain('tech')
    expect(wrapper.text()).toContain('2 子分类')
  })

  it('递归渲染多层级', () => {
    const wrapper = mount(CategoryManageNode, {
      props: { node: tree, depth: 0 },
    })
    expect(wrapper.text()).toContain('Java')
  })

  it('缩进随 depth 增加', () => {
    const wrapper = mount(CategoryManageNode, {
      props: { node: tree, depth: 0 },
    })
    const rows = wrapper.findAll('.node-row')
    expect(rows[0].attributes('style')).toContain('padding-left: 12px')   // depth=0: 0*20+12
    expect(rows[1].attributes('style')).toContain('padding-left: 32px')   // depth=1: 1*20+12
    expect(rows[3].attributes('style')).toContain('padding-left: 52px')   // depth=2: 2*20+12
  })

  it('折叠/展开', async () => {
    const wrapper = mount(CategoryManageNode, {
      props: { node: tree, depth: 0 },
    })
    expect(wrapper.text()).toContain('前端')
    await wrapper.find('.toggle-arrow').trigger('click')
    expect(wrapper.text()).not.toContain('前端')
    await wrapper.find('.toggle-arrow').trigger('click')
    expect(wrapper.text()).toContain('前端')
  })

  it('点击编辑/删除按钮 emit 事件', async () => {
    const wrapper = mount(CategoryManageNode, {
      props: { node: tree, depth: 0 },
    })
    const btns = wrapper.findAll('.btn-text')
    // 编辑=0, 权限=1, 删除=2
    await btns[0].trigger('click')
    expect(wrapper.emitted('edit')![0][0].id).toBe(1)
    await btns[2].trigger('click')
    expect(wrapper.emitted('delete')![0][0].id).toBe(1)
  })

  it('子节点的 edit/delete 事件冒泡到父级', async () => {
    const wrapper = mount(CategoryManageNode, {
      props: { node: tree, depth: 0 },
    })
    // 每个节点3个按钮: 编辑, 权限, 删除
    // 技术节点: 0=edit, 1=权限, 2=delete; 前端节点: 3=edit, 4=权限, 5=delete
    const allBtns = wrapper.findAll('.btn-text')
    await allBtns[3].trigger('click')
    expect(wrapper.emitted('edit')![0][0].id).toBe(2)
    await allBtns[5].trigger('click')
    expect(wrapper.emitted('delete')![0][0].id).toBe(2)
  })
})
