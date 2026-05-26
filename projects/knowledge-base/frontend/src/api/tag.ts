import request from './request'
import type {
  ApiResult,
  TagDTO,
  TagCreateRequest,
  TagUpdateRequest,
} from '@/types/api'

export function getTags() {
  return request.get<ApiResult<TagDTO[]>>('/tags')
}

export function createTag(data: TagCreateRequest) {
  return request.post<ApiResult<TagDTO>>('/tags', data)
}

export function updateTag(id: number, data: TagUpdateRequest) {
  return request.put<ApiResult<TagDTO>>(`/tags/${id}`, data)
}

export function deleteTag(id: number) {
  return request.delete<ApiResult<void>>(`/tags/${id}`)
}
