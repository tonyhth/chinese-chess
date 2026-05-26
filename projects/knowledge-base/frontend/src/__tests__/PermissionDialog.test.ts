import { mount } from '@vue/test-utils'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import PermissionDialog from '@/components/PermissionDialog.vue'
import type { PermissionDTO } from '@/types/api'

const mockLoadFn = vi.fn()
const mockSetFn = vi.fn()
const mockRemoveFn = vi.fn()

const samplePerms: PermissionDTO[] = [
  { id: 1, resourceId: 100, userId: 5, username: 'bob', permission: 'VIEW', grantedBy: 1, grantedByName: 'admin', createdAt: '', updatedAt: '' },
  { id: 2, resourceId: 100, userId: 6, username: 'alice', permission: 'EDIT', grantedBy: 1, grantedByName: 'admin', createdAt: '', updatedAt: '' },
]

function mountDialog(props?: Record<string, any>) {
  setActivePinia(createPinia())
  return mount(PermissionDialog, {
    props: {
      visible: false,
      title: '文章',
      resourceType: 'article',
      resourceId: 100,
      loadFn: mockLoadFn,
      setFn: mockSetFn,
      removeFn: mockRemoveFn,
      ...props,
    },
  })
}

async function openDialog(wrapper: ReturnType<typeof mountDialog>, perms = samplePerms) {
  mockLoadFn.mockResolvedValue({ data: { data: perms } })
  mockSetFn.mockResolvedValue({ data: { data: [] } })
  mockRemoveFn.mockResolvedValue({})
  await wrapper.setProps({ visible: true })
  await new Promise(r => setTimeout(r, 0))
}

describe('PermissionDialog', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('visible 变化时加载权限列表', async () => {
    const wrapper = mountDialog()
    mockLoadFn.mockResolvedValue({ data: { data: samplePerms } })
    await wrapper.setProps({ visible: true })
    await new Promise(r => setTimeout(r, 0))
    expect(mockLoadFn).toHaveBeenCalledWith(100)
  })

  it('渲染权限列表', async () => {
    const wrapper = mountDialog()
    await openDialog(wrapper)
    expect(wrapper.text()).toContain('bob')
    expect(wrapper.text()).toContain('alice')
  })

  it('空权限列表显示占位', async () => {
    const wrapper = mountDialog()
    await openDialog(wrapper, [])
    expect(wrapper.text()).toContain('暂未设置资源权限')
  })

  it('visible=false 时不渲染', () => {
    const wrapper = mountDialog({ visible: false })
    expect(wrapper.find('.modal-overlay').exists()).toBe(false)
  })

  it('点击关闭 emit close', async () => {
    const wrapper = mountDialog()
    await openDialog(wrapper)
    await wrapper.find('.modal-actions .btn-ghost').trigger('click')
    expect(wrapper.emitted('close')).toBeTruthy()
  })

  it('输入用户名添加权限', async () => {
    const wrapper = mountDialog()
    await openDialog(wrapper)
    const input = wrapper.find('.perm-input')
    await input.setValue('charlie')
    await wrapper.find('.btn-primary').trigger('click')
    await new Promise(r => setTimeout(r, 0))
    expect(mockSetFn).toHaveBeenCalledWith(100, [{ username: 'charlie', permission: 'VIEW' }])
  })

  it('用户名为空时添加按钮 disabled', async () => {
    const wrapper = mountDialog()
    await openDialog(wrapper)
    const btn = wrapper.find('.btn-primary')
    expect((btn.element as HTMLButtonElement).disabled).toBe(true)
  })

  it('权限级别选择', async () => {
    const wrapper = mountDialog()
    await openDialog(wrapper)
    // 最后一个 select 是添加区域的
    const selects = wrapper.findAll('.perm-select')
    const addSelect = selects[selects.length - 1]
    await addSelect.setValue('EDIT')
    const input = wrapper.find('.perm-input')
    await input.setValue('charlie')
    await wrapper.find('.btn-primary').trigger('click')
    await new Promise(r => setTimeout(r, 0))
    expect(mockSetFn).toHaveBeenCalledWith(100, [{ username: 'charlie', permission: 'EDIT' }])
  })
})
