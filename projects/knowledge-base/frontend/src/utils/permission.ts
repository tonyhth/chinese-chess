import type { UserRole, PermissionLevel } from '@/types/api'

/**
 * 权限工具函数
 * 基于角色 + 资源权限判断操作权限
 * 并集策略：角色允许 OR 资源权限允许 → 放行
 */

export function isAdmin(role: UserRole | null): boolean {
  return role === 'ADMIN'
}

export function isEditorOrAbove(role: UserRole | null): boolean {
  return role === 'ADMIN' || role === 'EDITOR'
}

/**
 * 资源权限级别比较
 * VIEW < EDIT < MANAGE
 */
function permissionOrder(p: PermissionLevel | undefined): number {
  if (!p) return -1
  return { VIEW: 0, EDIT: 1, MANAGE: 2 }[p] ?? -1
}

function hasResourcePermission(resourcePermission: PermissionLevel | undefined, required: PermissionLevel): boolean {
  return permissionOrder(resourcePermission) >= permissionOrder(required)
}

/**
 * 是否可编辑文章（并集策略）
 */
export function canEditArticle(
  role: UserRole | null,
  authorId: number | undefined,
  currentUserId: number | undefined,
  resourcePermission?: PermissionLevel,
): boolean {
  if (!role) return false
  // 角色：ADMIN 可编辑所有，EDITOR 仅自己的
  if (role === 'ADMIN') return true
  if (role === 'EDITOR' && currentUserId != null && authorId === currentUserId) return true
  // 资源权限：EDIT 及以上
  if (hasResourcePermission(resourcePermission, 'EDIT')) return true
  return false
}

/**
 * 是否可删除文章（并集策略，需要 MANAGE 级资源权限）
 */
export function canDeleteArticle(
  role: UserRole | null,
  authorId: number | undefined,
  currentUserId: number | undefined,
  resourcePermission?: PermissionLevel,
): boolean {
  if (!role) return false
  if (role === 'ADMIN') return true
  if (role === 'EDITOR' && currentUserId != null && authorId === currentUserId) return true
  if (hasResourcePermission(resourcePermission, 'MANAGE')) return true
  return false
}

/**
 * 是否可查看草稿
 */
export function canViewDraft(
  role: UserRole | null,
  authorId: number | undefined,
  currentUserId: number | undefined,
  resourcePermission?: PermissionLevel,
): boolean {
  if (!role) return false
  if (role === 'ADMIN') return true
  if (role === 'EDITOR' && currentUserId != null && authorId === currentUserId) return true
  if (hasResourcePermission(resourcePermission, 'VIEW')) return true
  return false
}

/**
 * 是否可查看归档文章
 */
export function canViewArchived(role: UserRole | null): boolean {
  return role === 'ADMIN'
}

/**
 * 是否可变更文章状态（需要 MANAGE）
 */
export function canChangeStatus(
  role: UserRole | null,
  authorId: number | undefined,
  currentUserId: number | undefined,
  resourcePermission?: PermissionLevel,
): boolean {
  return canDeleteArticle(role, authorId, currentUserId, resourcePermission)
}

/**
 * 是否可删除评论
 */
export function canDeleteComment(
  role: UserRole | null,
  authorId: number | undefined,
  currentUserId: number | undefined,
): boolean {
  if (!role) return false
  if (role === 'ADMIN') return true
  return currentUserId != null && authorId === currentUserId
}

export function canManageCategory(role: UserRole | null): boolean {
  return isEditorOrAbove(role)
}

export function canDeleteCategory(role: UserRole | null): boolean {
  return role === 'ADMIN'
}

export function canManageTag(role: UserRole | null): boolean {
  return isEditorOrAbove(role)
}

export function canDeleteTag(role: UserRole | null): boolean {
  return role === 'ADMIN'
}
