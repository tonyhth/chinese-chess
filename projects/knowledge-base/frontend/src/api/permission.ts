import request from './request'
import type { PermissionDTO, PermissionGrantRequest } from '@/types/api'

// --- 文章权限 ---

export function getArticlePermissions(articleId: number) {
  return request.get<{ code: number; message: string; data: PermissionDTO[] }>(`/articles/${articleId}/permissions`)
}

export function setArticlePermissions(articleId: number, permissions: PermissionGrantRequest[]) {
  return request.put<{ code: number; message: string; data: PermissionDTO[] }>(`/articles/${articleId}/permissions`, { permissions })
}

export function removeArticlePermission(articleId: number, userId: number) {
  return request.delete(`/articles/${articleId}/permissions/${userId}`)
}

export function batchQueryPermissions(articleIds: number[]) {
  return request.post<{ code: number; message: string; data: Record<string, string> }>('/articles/permissions/batch-query', articleIds)
}

// --- 分类权限 ---

export function getCategoryPermissions(categoryId: number) {
  return request.get<{ code: number; message: string; data: PermissionDTO[] }>(`/categories/${categoryId}/permissions`)
}

export function setCategoryPermissions(categoryId: number, permissions: PermissionGrantRequest[]) {
  return request.put<{ code: number; message: string; data: PermissionDTO[] }>(`/categories/${categoryId}/permissions`, { permissions })
}

export function removeCategoryPermission(categoryId: number, userId: number) {
  return request.delete(`/categories/${categoryId}/permissions/${userId}`)
}
