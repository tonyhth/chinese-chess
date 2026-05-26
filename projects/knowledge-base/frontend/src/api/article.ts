import request from './request'
import type {
  ApiResult,
  ArticleDTO,
  ArticleCreateRequest,
  ArticleUpdateRequest,
  ArticleQueryRequest,
  ArticleVersionDTO,
  StatusUpdateRequest,
  ArticleBatchResult,
  ArticleBatchDeleteRequest,
  ArticleBatchMoveRequest,
  ArticleBatchTagRequest,
  PageResult,
} from '@/types/api'

// --- 文章 CRUD ---

export function getArticles(params?: ArticleQueryRequest) {
  return request.get<ApiResult<PageResult<ArticleDTO>>>('/articles', { params })
}

export function getArticle(id: number) {
  return request.get<ApiResult<ArticleDTO>>(`/articles/${id}`)
}

export function createArticle(data: ArticleCreateRequest) {
  return request.post<ApiResult<ArticleDTO>>('/articles', data)
}

export function updateArticle(id: number, data: ArticleUpdateRequest) {
  return request.put<ApiResult<ArticleDTO>>(`/articles/${id}`, data)
}

export function updateArticleStatus(id: number, data: StatusUpdateRequest) {
  return request.patch<ApiResult<ArticleDTO>>(`/articles/${id}/status`, data)
}

// --- 版本管理 ---

export function getArticleVersions(articleId: number) {
  return request.get<ApiResult<ArticleVersionDTO[]>>(`/articles/${articleId}/versions`)
}

export function getArticleVersion(articleId: number, version: number) {
  return request.get<ApiResult<ArticleVersionDTO>>(
    `/articles/${articleId}/versions/${version}`,
  )
}

export function restoreArticleVersion(articleId: number, version: number) {
  return request.post<ApiResult<ArticleVersionDTO>>(
    `/articles/${articleId}/versions/${version}/restore`,
  )
}

// --- 批量操作 ---

export function batchDeleteArticles(data: ArticleBatchDeleteRequest) {
  return request.post<ApiResult<ArticleBatchResult>>('/articles/batch/delete', data)
}

export function batchMoveArticles(data: ArticleBatchMoveRequest) {
  return request.post<ApiResult<ArticleBatchResult>>('/articles/batch/move', data)
}

export function batchTagArticles(data: ArticleBatchTagRequest) {
  return request.post<ApiResult<ArticleBatchResult>>('/articles/batch/tag', data)
}
