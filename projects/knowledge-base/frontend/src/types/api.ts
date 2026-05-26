// ============================================================
// 通用类型
// ============================================================

export interface PageResult<T> {
  records: T[]
  total: number
  page: number
  size: number
}

export interface ApiResult<T> {
  code: number
  message: string
  data: T
}

// ============================================================
// 认证
// ============================================================

export interface LoginRequest {
  username: string
  password: string
}

export interface TokenResponse {
  accessToken: string
  refreshToken: string
  expiresIn: number
}

// ============================================================
// 用户
// ============================================================

export type UserRole = 'ADMIN' | 'EDITOR' | 'READER'

export interface UserDTO {
  id: number
  username: string
  email: string | null
  avatarUrl: string | null
  role: UserRole
}

// ============================================================
// 分类
// ============================================================

export interface CategoryDTO {
  id: number
  parentId: number | null
  name: string
  slug: string
  description: string | null
  sortOrder: number
  children?: CategoryDTO[]
  createdAt: string
}

export interface CategoryCreateRequest {
  parentId?: number | null
  name: string
  slug: string
  description?: string | null
  sortOrder?: number
}

export interface CategoryUpdateRequest {
  name?: string
  slug?: string
  description?: string | null
  sortOrder?: number
  parentId?: number | null
}

// ============================================================
// 标签
// ============================================================

export interface TagDTO {
  id: number
  name: string
  color: string | null
}

export interface TagCreateRequest {
  name: string
  color?: string | null
}

export interface TagUpdateRequest {
  name?: string
  color?: string | null
}

// ============================================================
// 文章
// ============================================================

export type ArticleStatus = 'DRAFT' | 'PUBLISHED' | 'ARCHIVED'

export interface TagRef {
  id: number
  name: string
  color: string | null
}

export interface ArticleDTO {
  id: number
  title: string
  slug: string | null
  summary: string | null
  content?: string
  contentHtml?: string
  categoryId: number | null
  categoryName?: string
  authorId: number
  authorName?: string
  status: ArticleStatus
  viewCount: number
  version: number
  tags?: TagRef[]
  createdAt: string
  updatedAt: string
}

export interface ArticleQueryRequest {
  page?: number
  size?: number
  categoryId?: number
  tagId?: number
  status?: ArticleStatus
  keyword?: string
  sort?: 'updated_at' | 'created_at'
  order?: 'asc' | 'desc'
}

export interface ArticleCreateRequest {
  title: string
  slug?: string
  content: string
  summary?: string
  categoryId?: number | null
  tagIds?: number[]
  status?: ArticleStatus
}

export interface ArticleUpdateRequest {
  title?: string
  slug?: string | null
  content?: string
  summary?: string | null
  categoryId?: number | null
  tagIds?: number[]
}

export interface StatusUpdateRequest {
  status: ArticleStatus | 'DELETED'
}

// ============================================================
// 文章版本
// ============================================================

export interface ArticleVersionDTO {
  id: number
  articleId: number
  title: string
  content: string
  version: number
  changeSummary: string | null
  createdBy: number
  createdByName: string | null
  createdAt: string
}

// ============================================================
// 批量操作
// ============================================================

export interface ArticleBatchResult {
  successCount: number
  failCount: number
  failedIds: number[]
}

export interface ArticleBatchDeleteRequest {
  ids: number[]
}

export interface ArticleBatchMoveRequest {
  ids: number[]
  categoryId: number
}

export interface ArticleBatchTagRequest {
  ids: number[]
  tagIds: number[]
}

export interface UserCreateRequest {
  username: string
  password: string
  email?: string
  role?: string
}

export interface UserUpdateRequest {
  username?: string
  email?: string
  avatarUrl?: string
}

export interface RoleUpdateRequest {
  role: string
}

// ============================================================
// 评论
// ============================================================

export interface CommentDTO {
  id: number
  articleId: number
  parentId: number | null
  content: string
  authorId: number
  authorName: string | null
  authorAvatar: string | null
  status: number
  depth: number
  createdAt: string
  updatedAt: string
  replies?: CommentDTO[]
}

export interface CommentCreateRequest {
  content: string
  parentId?: number | null
}

// ============================================================
// 搜索
// ============================================================

export interface SearchRequest {
  query?: string
  categoryId?: number
  tagNames?: string[]
  dateFrom?: string
  dateTo?: string
  sort?: 'relevance' | 'newest' | 'oldest'
  page?: number
  size?: number
}

export interface SearchSuggestParams {
  q: string
}

// ============================================================
// 文件上传
// ============================================================

export interface UploadDTO {
  id: number
  url: string
  fileName: string
  filePath: string
  fileSize: number
  mimeType: string
  createdAt: string
}

// ============================================================
// Dashboard
// ============================================================

export interface DashboardStats {
  articleCount: number
  userCount: number
  categoryCount: number
  tagCount: number
}

// ============================================================
// P1 搜索响应
// ============================================================

export interface SearchResponseDTO {
  total: number
  page: number
  size: number
  hits: SearchHitDTO[]
  cached?: boolean
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

export interface SearchSuggestDTO {
  suggestions: SearchSuggestItemDTO[]
}

export interface SearchSuggestItemDTO {
  text: string
  articleId: number | null
}

// ============================================================
// 权限
// ============================================================

export type PermissionLevel = 'VIEW' | 'EDIT' | 'MANAGE'

export interface PermissionDTO {
  id: number
  resourceId: number
  userId: number
  username: string
  permission: PermissionLevel
  grantedBy: number
  grantedByName: string
  createdAt: string
  updatedAt: string
}

export interface PermissionGrantRequest {
  userId?: number
  username?: string
  permission: PermissionLevel
}
