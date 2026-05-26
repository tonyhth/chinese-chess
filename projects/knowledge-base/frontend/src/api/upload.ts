import request from './request'
import type { ApiResult, UploadDTO } from '@/types/api'

export function uploadImage(file: File, clientId?: string) {
  const formData = new FormData()
  formData.append('file', file)
  if (clientId) formData.append('client_id', clientId)
  return request.post<ApiResult<UploadDTO>>('/upload/image', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
}

export function uploadFile(file: File, clientId?: string) {
  const formData = new FormData()
  formData.append('file', file)
  if (clientId) formData.append('client_id', clientId)
  return request.post<ApiResult<UploadDTO>>('/upload/file', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
}
