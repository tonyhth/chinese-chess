import request from './request'
import type {
  ApiResult,
  CategoryDTO,
  CategoryCreateRequest,
  CategoryUpdateRequest,
} from '@/types/api'

export function getCategoryTree() {
  return request.get<ApiResult<CategoryDTO[]>>('/categories')
}

export function createCategory(data: CategoryCreateRequest) {
  return request.post<ApiResult<CategoryDTO>>('/categories', data)
}

export function updateCategory(id: number, data: CategoryUpdateRequest) {
  return request.put<ApiResult<CategoryDTO>>(`/categories/${id}`, data)
}

export function deleteCategory(id: number) {
  return request.delete<ApiResult<void>>(`/categories/${id}`)
}
