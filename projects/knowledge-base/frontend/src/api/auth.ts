import request from './request'
import type { LoginRequest, TokenResponse } from '@/types/api'

export function login(data: LoginRequest) {
  return request.post<TokenResponse>('/auth/login', data)
}

export function logout(refreshToken: string | null) {
  return request.post('/auth/logout', refreshToken ? { refreshToken } : {})
}

export function getMe() {
  return request.get<{ data: import('@/types/api').UserDTO }>('/users/me')
}
