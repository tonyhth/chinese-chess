import request from './request'
import type { ApiResult, DashboardStats } from '@/types/api'

export function getDashboardStats() {
  return request.get<ApiResult<DashboardStats>>('/dashboard/stats')
}
