import request from './request'
import type { ApiResult } from '@/types/api'

export interface SearchRequestDTO {
  query: string
  categoryId?: number
  tagNames?: string[]
  dateFrom?: string
  dateTo?: string
  sort?: 'relevance' | 'newest' | 'oldest'
  page?: number
  size?: number
}

export interface SearchHitDTO {
  articleId: number
  title: string | null
  summary: string | null
  contentHighlights: string[] | null
  categoryName: string | null
  tagNames: string[] | null
  authorName: string | null
  updatedAt: string | null
}

export interface SearchResponseDTO {
  total: number
  page: number
  size: number
  hits: SearchHitDTO[]
  cached: boolean
}

export interface SuggestItemDTO {
  text: string
  articleId: number | null
}

export interface SuggestResponseDTO {
  suggestions: SuggestItemDTO[]
}

export function searchArticles(data: SearchRequestDTO) {
  return request.post<ApiResult<SearchResponseDTO>>('/search', data)
}

export function getSearchSuggestions(q: string, size = 10) {
  return request.get<ApiResult<SuggestResponseDTO>>('/search/suggest', { params: { q, size } })
}
