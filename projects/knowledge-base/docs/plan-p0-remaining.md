# P0 阶段剩余工作 — 实施计划（v2）

> 作者：Alex | 日期：2026-04-07 | 基于 proposal-v1.md 定稿
> v2：根据 Vera 审查清单修订

---

## ⚠️ 范围说明

本计划的范围来自 Luke 的任务指令，包含部分 proposal v1 中归为 P1/P2 的模块（版本管理、评论、文件上传、仪表盘）。这些模块在 proposal 分期中属 P1/P2，但 Luke 明确要求纳入本次 P0 剩余交付。

**这意味着 P0 实际范围大于 proposal 原定义的 MVP。**

**推荐方案：维持扩大范围（7 人天 / 4 天并行）。**
理由：文件上传（图片）与 Markdown 编辑器紧耦合——没有图片上传的编辑器实际不可用；版本管理是编辑流程的自然延伸，缺少则编辑体验不完整；评论影响详情页交付。这三个模块拆到 P1 会导致 P0 交付时核心编辑链路残缺。唯一可安全延后的是 Dashboard（仪表盘），如需压缩工期建议先砍 Dashboard，其余维持。

---

## 分批原则

- 每批有明确的可验证交付物
- 后端先行，前端跟进，联调收尾
- 每批 1-2 个工作日，Cody 可逐步交付
- 基础设施穿插在功能批次之间

---

## Batch 1：基础设施 + 种子数据

**目标**：开发环境完整可用，SpringDoc 可访问。

| 文件 | 说明 |
|------|------|
| `backend/src/main/resources/db/migration/V2__seed_data.sql` | 默认管理员 + 默认分类（当前最大版本号为 V1，如有变更需调整编号） |
| `elasticsearch/Dockerfile` | 预装 IK 插件 |
| `elasticsearch/config/kb_custom.dic` | 自定义词典（初始可空） |
| `nginx/Dockerfile` | 基于 nginx:alpine |
| `nginx/default.conf` | 反向代理 + SPA fallback |
| `.env.example` | 环境变量模板 |
| `docker-compose.dev.yml` | 开发环境覆盖（暴露 DB/Redis/ES 端口） |
| `backend/src/main/java/com/kb/config/SpringDocConfig.java` | SpringDoc 配置（如需） |

**依赖**：无（Docker Compose 基础版已有）
**验证**：`docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d`，所有服务 healthy，访问 `/swagger-ui.html` 可用

---

## Batch 2：后端 — 文章版本管理 API

**目标**：文章版本列表、版本详情、回滚功能完整可用。

| 文件 | 说明 |
|------|------|
| `article/service/ArticleVersionService.java` | 版本列表、版本详情、回滚逻辑 |
| `article/controller/ArticleVersionController.java`（或在 ArticleController 中新增） | `GET /articles/{id}/versions`、`GET /articles/{id}/versions/{version}`、`POST /articles/{id}/versions/{version}/restore` |

**说明**：
- Entity + Mapper 已有，本批补 Service + Controller
- 回滚逻辑：读取目标版本内容 → 创建新版本快照 → 更新文章主表
- 修改文章时自动创建版本快照（在 ArticleService.update 中补充）

**依赖**：无新依赖
**说明**：后端权限控制（SecurityConfig、PermissionService）已在更早批次完成（属已完成工作），Batch 2 不涉及权限文件变更。
**验证**：创建文章 → 编辑（触发版本快照） → 查看版本列表 → 回滚 → 验证内容恢复

---

## Batch 3：后端 — 批量操作 + 评论 API + 文件上传

**目标**：文章批量操作、评论 CRUD、MinIO 文件上传全部就绪。

| 文件 | 说明 |
|------|------|
| `article/service/ArticleBatchService.java` | 批量删除/移动/打标签 |
| `article/controller/ArticleController.java`（新增 batch 端点） | `POST /articles/batch/delete`、`batch/move`、`batch/tag` |
| `comment/service/CommentService.java` | 评论列表（递归查询）、发表、软删除 |
| `comment/controller/CommentController.java` | `GET /articles/{id}/comments`、`POST /articles/{id}/comments`、`DELETE /comments/{id}` |
| `comment/mapper/CommentMapper.java` | 补充查询方法（如需） |
| `config/MinioConfig.java` | MinIO 连接配置 + Bucket 初始化 |
| `upload/service/UploadService.java` | 图片/附件上传，返回 URL |
| `upload/controller/UploadController.java` | `POST /upload/image`、`POST /upload/file` |
| `upload/mapper/AttachmentMapper.java` | 附件记录持久化 |

**依赖**：MinIO 服务（Batch 1 已就绪）

**评论树查询方案**：
- 采用 PostgreSQL `WITH RECURSIVE` CTE 一次性查出指定文章全部评论（平铺 + parent_id），前端递归组装树形
- 嵌套深度上限 3 层，第 3 层回复统一挂在第 2 层下（proposal 约定）
- 评论列表不分页（单篇文章评论量有限），如超过 200 条加 `LIMIT 200`

**文件上传安全策略**：
- 文件类型白名单：图片（jpg/png/gif/webp/svg）、附件（pdf/doc/xlsx/pptx/zip/tar.gz）
- 文件大小限制：图片 10MB、附件 50MB（Spring Boot `multipart.max-file-size` + MinIO policy）
- 文件名冲突：使用 `{uuid}.{ext}` 重命名，保留原始文件名到 `kb_attachment.file_name`
- Bucket 访问策略：公开读（图片需要直接在 Markdown 中引用），附件用签名 URL（有效期 1 小时）
- 幂等性：前端重试时使用同一 `client_id` 参数，后端做去重

**验证**：Postman 测试批量操作、评论树查询、文件上传返回可访问 URL

---

## Batch 4：前端 — 核心 API 封装 + 权限工具

**目标**：所有前端 API 层就绪，为页面开发铺路。

| 文件 | 说明 |
|------|------|
| `src/api/article.ts` | 文章 CRUD + 版本 + 批量操作 |
| `src/api/category.ts` | 分类树 CRUD |
| `src/api/tag.ts` | 标签 CRUD |
| `src/api/comment.ts` | 评论列表 + 发表 + 删除 |
| `src/api/search.ts` | 搜索（P1 用，先封接口） |
| `src/utils/permission.ts` | 角色判断工具（isAdmin、canEdit、canDelete 等） |

**依赖**：无（基于 proposal API 定义封装，不需要后端就绪即可编码）
**说明**：前端 API 封装仅依赖 proposal 中的 API 设计，与 Batch 2/3 无实现依赖。依赖图中的箭头已修正。
**验证**：TypeScript 编译通过，类型定义正确

---

## Batch 5：前端 — 文章编辑 + 详情页

**目标**：核心内容创作链路跑通（编辑器 + 预览 + 图片上传）。

| 文件 | 说明 |
|------|------|
| `src/components/MarkdownEditor.vue` | Markdown 编辑器（推荐 md-editor-v3 或 bytemd） |
| `src/components/MarkdownPreview.vue` | Markdown 预览组件 |
| `src/components/TagSelect.vue` | 标签多选 |
| `src/components/CategoryTree.vue` | 分类树选择 |
| `src/views/ArticleEdit.vue` | 文章创建/编辑页（含版本回滚入口） |
| `src/views/ArticleDetail.vue` | 文章详情页（Markdown 渲染 + 评论展示） |

**依赖**：Batch 4 API 封装
**说明**：ArticleEdit.vue 中的权限控制（草稿可见性、编辑按钮显隐）使用 `permission.ts`（Batch 4 已就绪），不依赖 Batch 6 的路由守卫。路由守卫是锦上添花，不阻塞功能。
**验证**：创建文章 → 编辑 → 上传图片 → 预览 → 发布 → 查看详情页

---

## Batch 6：前端 — 管理页 + 通用组件

**目标**：管理功能页面全部完成。

| 文件 | 说明 |
|------|------|
| `src/views/CategoryManage.vue` | 分类管理（树形 CRUD） |
| `src/views/TagManage.vue` | 标签管理（列表 CRUD） |
| `src/views/UserManage.vue` | 用户管理（Admin 专用） |
| `src/views/Dashboard.vue` | 首页仪表盘（基础统计） |
| `src/components/CommentList.vue` | 评论列表（楼中楼展示） |
| `src/components/Pagination.vue` | 通用分页组件 |
| `src/router/index.ts` | 补充路由和权限守卫 |

**依赖**：Batch 4 API 封装
**说明**：Dashboard 仅做基础统计（文章数、用户数、分类数），纯 SQL 聚合查询，不做复杂图表。
**验证**：分类树增删改、标签管理、用户管理（角色切换）、仪表盘数据展示

---

## Batch 7：联调 + 收尾

**目标**：端到端全链路验证，修复集成问题。

| 工作项 | 说明 |
|--------|------|
| 前后端联调 | 所有页面与 API 对齐 |
| 权限边界测试 | Admin/Editor/Reader 各角色的操作边界 |
| SpringDoc 确认 | 确保 API 文档完整可访问 |
| docker-compose 全栈启动 | 一键部署验证 |
| 补充后端测试 | ArticleVersionServiceTest、CommentServiceTest、UploadServiceTest |

**补充测试清单**（不仅限于新增 3 个 Service）：
- ArticleVersionServiceTest（版本创建、列表、回滚）
- CommentServiceTest（评论树查询、楼中楼、软删除占位）
- UploadServiceTest（类型白名单、大小限制、重命名）
- ArticleBatchServiceTest（批量删除/移动/打标签）
- BatchIntegrationTest（批量操作事务一致性）
- PermissionEdgeTest（Admin/Editor/Reader 边界场景）

**错误处理约定**（P0 统一标准）：
- API 统一错误响应格式：`{ "code": "ERROR_CODE", "message": "描述", "data": null }`（沿用现有 Result.java）
- BusinessException 携带 ErrorCode 枚举
- 关键操作日志（版本回滚、批量删除、用户角色变更）通过 SLF4J INFO 级别记录

**验证**：docker-compose up → 登录 → 创建文章 → 编辑 → 上传图片 → 发布 → 评论 → 版本回滚 → 管理分类/标签/用户 → 全链路通过

---

## 前后端依赖关系总览

```
Batch 1 (基础设施) ──→ Batch 2 (版本API) ──→ Batch 3 (批量/评论/上传)

Batch 4 (前端API封装)     ← 基于 proposal API 定义，与 Batch 2/3 无实现依赖，可并行
    │
    ├──→ Batch 5 (编辑/详情) ←── Batch 3 就绪后联调
    ├──→ Batch 6 (管理页)
    │
    └──→ Batch 7 (联调收尾) ←── Batch 5 + Batch 6
```

**并行机会**：Batch 2-3（后端）与 Batch 4（前端 API 封装）完全并行，互不阻塞。

---

## 已完成 vs 剩余工作量

**已完成（约占 P0 原定义的 60%）**：
- DB Schema（V1__init.sql）
- Docker Compose 基础版
- Auth 完整链路 + 权限控制（JWT、SecurityConfig、PermissionService）
- 文章基础 CRUD + 分类/标签 CRUD + User Controller
- 前端：Login、ArticleList、Layout、路由、auth API、request 封装
- 后端测试：AuthIntegrationTest、RbacIntegrationTest、PermissionServiceTest

**剩余工作（本次计划覆盖）**：约 40% 原始 P0 + Luke 指定追加的 P1/P2 模块

## 建议开发顺序

| 天数 | 后端 | 前端 |
|------|------|------|
| Day 1 | Batch 1 | — |
| Day 2 | Batch 2 | Batch 4 |
| Day 3 | Batch 3 | Batch 4（续） |
| Day 4 | — | Batch 5 |
| Day 5 | — | Batch 5（续）+ Batch 6 |
| Day 6 | Batch 6（续） | Batch 7（联调） |
| Day 7 | Batch 7（修复+测试） | Batch 7（修复） |

总计约 7 个工作日（1 人全职），或 4 天（前后端各 1 人并行）。

> ⚠️ 此工期基于扩大后的 P0 范围。如果回归 proposal 原定义（去掉版本/评论/上传/仪表盘），工期可压缩至 3-4 人天。
