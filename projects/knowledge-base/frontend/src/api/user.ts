import request from './request'
import type {
  ApiResult,
  UserDTO,
  UserCreateRequest,
  UserUpdateRequest,
  RoleUpdateRequest,
  PageResult,
} from '@/types/api'

export function getUsers(page?: number, size?: number) {
  return request.get<ApiResult<PageResult<UserDTO>>>('/users', { params: { page, size } })
}

export function createUser(data: UserCreateRequest) {
  return request.post<ApiResult<UserDTO>>('/users', data)
}

export function updateUser(id: number, data: UserUpdateRequest) {
  return request.put<ApiResult<UserDTO>>(`/users/${id}`, data)
}

export function deleteUser(id: number) {
  return request.delete<ApiResult<void>>(`/users/${id}`)
}

export function updateUserRole(id: number, data: RoleUpdateRequest) {
  return request.put<ApiResult<UserDTO>>(`/users/${id}/role`, data)
}

export function searchUsers(keyword: string, page = 1, size = 20, resourceType?: string, resourceId?: number) {
  return request.get<ApiResult<PageResult<UserDTO>>>('/users/search', {
    params: { keyword, page, size, resourceType, resourceId },
  })
}
