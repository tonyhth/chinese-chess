import request from './request'
import type {
  ApiResult,
  CommentDTO,
  CommentCreateRequest,
} from '@/types/api'

export function getComments(articleId: number) {
  return request.get<ApiResult<CommentDTO[]>>(
    `/articles/${articleId}/comments`,
  )
}

export function createComment(articleId: number, data: CommentCreateRequest) {
  return request.post<ApiResult<CommentDTO>>(
    `/articles/${articleId}/comments`,
    data,
  )
}

export function deleteComment(commentId: number) {
  return request.delete<ApiResult<void>>(`/comments/${commentId}`)
}
