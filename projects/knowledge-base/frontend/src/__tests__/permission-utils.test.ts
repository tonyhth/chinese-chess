import { describe, it, expect } from 'vitest'
import {
  canEditArticle, canDeleteArticle, canViewDraft, canViewArchived,
  canChangeStatus, canDeleteComment, canManageCategory, canDeleteCategory,
  isAdmin, isEditorOrAbove,
} from '@/utils/permission'
import type { UserRole, PermissionLevel } from '@/types/api'

describe('permission.ts — 权限工具函数', () => {
  describe('isAdmin / isEditorOrAbove', () => {
    it('ADMIN', () => { expect(isAdmin('ADMIN')).toBe(true); expect(isEditorOrAbove('ADMIN')).toBe(true) })
    it('EDITOR', () => { expect(isAdmin('EDITOR')).toBe(false); expect(isEditorOrAbove('EDITOR')).toBe(true) })
    it('READER', () => { expect(isAdmin('READER')).toBe(false); expect(isEditorOrAbove('READER')).toBe(false) })
    it('null', () => { expect(isAdmin(null)).toBe(false); expect(isEditorOrAbove(null)).toBe(false) })
  })

  describe('canEditArticle — 并集策略', () => {
    const authorId = 10
    const currentUserId = 10

    it('ADMIN 可编辑所有文章', () => {
      expect(canEditArticle('ADMIN', authorId, currentUserId)).toBe(true)
      expect(canEditArticle('ADMIN', 999, currentUserId)).toBe(true)
    })

    it('EDITOR 可编辑自己的文章', () => {
      expect(canEditArticle('EDITOR', authorId, currentUserId)).toBe(true)
    })

    it('EDITOR 不能编辑他人文章（无资源权限）', () => {
      expect(canEditArticle('EDITOR', 999, currentUserId)).toBe(false)
    })

    it('READER + EDIT 资源权限可编辑他人文章', () => {
      expect(canEditArticle('READER', 999, currentUserId, 'EDIT')).toBe(true)
    })

    it('READER + MANAGE 资源权限可编辑他人文章', () => {
      expect(canEditArticle('READER', 999, currentUserId, 'MANAGE')).toBe(true)
    })

    it('READER + VIEW 资源权限不可编辑', () => {
      expect(canEditArticle('READER', 999, currentUserId, 'VIEW')).toBe(false)
    })

    it('READER 无资源权限不可编辑', () => {
      expect(canEditArticle('READER', 999, currentUserId)).toBe(false)
    })

    it('null role 不可编辑', () => {
      expect(canEditArticle(null, authorId, currentUserId, 'MANAGE')).toBe(false)
    })
  })

  describe('canDeleteArticle — 需要 MANAGE', () => {
    it('ADMIN 可删除', () => {
      expect(canDeleteArticle('ADMIN', 999, 10)).toBe(true)
    })

    it('EDITOR 可删除自己的', () => {
      expect(canDeleteArticle('EDITOR', 10, 10)).toBe(true)
    })

    it('READER + MANAGE 可删除', () => {
      expect(canDeleteArticle('READER', 999, 10, 'MANAGE')).toBe(true)
    })

    it('READER + EDIT 不可删除', () => {
      expect(canDeleteArticle('READER', 999, 10, 'EDIT')).toBe(false)
    })
  })

  describe('canViewDraft — 并集', () => {
    it('ADMIN 可查看', () => {
      expect(canViewDraft('ADMIN', 999, 10)).toBe(true)
    })

    it('EDITOR 可查看自己的草稿', () => {
      expect(canViewDraft('EDITOR', 10, 10)).toBe(true)
    })

    it('READER + VIEW 可查看他人草稿', () => {
      expect(canViewDraft('READER', 999, 10, 'VIEW')).toBe(true)
    })

    it('READER 无权限不可查看', () => {
      expect(canViewDraft('READER', 999, 10)).toBe(false)
    })
  })

  describe('canViewArchived', () => {
    it('ADMIN 可查看归档', () => { expect(canViewArchived('ADMIN')).toBe(true) })
    it('EDITOR 不可查看归档', () => { expect(canViewArchived('EDITOR')).toBe(false) })
    it('null 不可', () => { expect(canViewArchived(null)).toBe(false) })
  })

  describe('canChangeStatus', () => {
    it('需要 MANAGE 级别', () => {
      expect(canChangeStatus('READER', 999, 10, 'MANAGE')).toBe(true)
      expect(canChangeStatus('READER', 999, 10, 'EDIT')).toBe(false)
    })
  })

  describe('canDeleteComment', () => {
    it('ADMIN 可删除任何评论', () => { expect(canDeleteComment('ADMIN', 999, 10)).toBe(true) })
    it('用户可删除自己的评论', () => { expect(canDeleteComment('READER', 10, 10)).toBe(true) })
    it('用户不能删除他人评论', () => { expect(canDeleteComment('READER', 999, 10)).toBe(false) })
  })

  describe('canManageCategory / canDeleteCategory', () => {
    it('EDITOR+ 可管理分类', () => { expect(canManageCategory('EDITOR')).toBe(true) })
    it('READER 不可管理', () => { expect(canManageCategory('READER')).toBe(false) })
    it('仅 ADMIN 可删除分类', () => {
      expect(canDeleteCategory('ADMIN')).toBe(true)
      expect(canDeleteCategory('EDITOR')).toBe(false)
    })
  })
})
