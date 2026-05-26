# P1 后续优化方案 v2.1

> 2026-04-07 · Alex · v1.1（根据 Vera 审查清单修订）
> 项目：知识库（knowledge-base）

---

## 概述

P0+P1 已交付。本方案覆盖 5 项优化，均为前端改动为主、后端小改为辅，无破坏性变更。按实现难度从低到高排列。

---

## 1. 分类缩进

**现状**：`CategoryTree.vue` 用 `padding-left: 24px` 硬编码一层缩进，`CategoryTreeItem` 内联组件只渲染一级子节点，递归不完整。

**方案**：

- 将 `CategoryTreeItem` 改为递归组件（独立 `.vue` 文件），支持任意层级嵌套
- 每层通过 `depth` prop 动态计算 `padding-left: depth * 20px`
- 树节点前加折叠/展开箭头（▶/▼），默认展开
- 后端无改动，`CategoryDTO.children` 已是递归结构

**深层级性能**：分类节点 >50 个或层级 >3 时，改为默认折叠到第 2 层，用户手动展开。避免一次性渲染大量 DOM。当前项目分类数量有限（<30），首期不做懒加载，预留 `lazy` prop 接口。

**数据模型**：无变更。`CategoryDTO.parentId + children` 已支持树形。

**改动范围**：
- `components/CategoryTree.vue` — 重构为递归渲染
- 新建 `components/CategoryTreeItem.vue` — 独立递归子组件
- `views/CategoryManage.vue` — 如有分类管理列表，同步加缩进

---

## 2. Diff 方向标注

**现状**：`ArticleDetail.vue` 的 `showDiff()` 调用 `diffLines(currentContent, targetContent)`，diff 结果用 `diff-add` / `diff-remove` 着色，但工具栏只显示 `v{{ oldVersion }} → v{{ newVersion }}`，不标注哪边是新增、哪边是删除，用户容易混淆方向。

**方案**：

- Diff 工具栏改为双栏标题：「左侧 v3（旧）→ 右侧 v{{ current }}（当前）」
- `diff-add` 行前加 `+` 前缀，背景绿色，tooltip "新增内容"
- `diff-remove` 行前加 `-` 前缀，背景红色，删除线，tooltip "已删除内容"
- 工具栏加"交换方向"按钮，点击后反转 oldContent/newContent 参数重新调用 `diffLines`，同步更新工具栏的版本号显示
- `+`/`-` 前缀是色盲友好设计（WCAG 1.4.1），不仅仅是装饰
- 修正 `showDiff` 参数顺序：当前 `diffLines(current, target)` 语义是"把 current 变成 target"，但 `diffResult.oldVersion` 取的是 `v.version`（历史），`newVersion` 取的是 `article.version`（当前）。参数顺序应改为 `diffLines(targetContent, currentContent)`，使 added = 当前比历史多的内容。

**交换方向逻辑**：
```typescript
function showDiff(v: ArticleVersionDTO) {
  const old = direction.value === 'forward' ? v.content : article.value!.content
  const cur = direction.value === 'forward' ? article.value!.content : v.content
  const parts = diffLines(old || '', cur || '')
  diffResult.value = {
    oldVersion: direction.value === 'forward' ? v.version : article.value!.version,
    newVersion: direction.value === 'forward' ? article.value!.version : v.version,
    parts,
  }
}
```

**改动范围**：
- `views/ArticleDetail.vue` — diff 工具栏 UI + showDiff 逻辑

---

## 3. 权限细化

**现状**：权限完全基于用户角色（ADMIN/EDITOR/READER），无资源级控制。例如 EDITOR 只能编辑自己的文章，但不能授权其他 EDITOR 协作编辑。

**方案**：

### 3.1 数据模型

新增 `article_permission` 表：

```sql
CREATE TABLE article_permission (
  id          BIGSERIAL PRIMARY KEY,
  article_id  BIGINT NOT NULL REFERENCES article(id),
  user_id     BIGINT NOT NULL REFERENCES user(id),
  permission  VARCHAR(20) NOT NULL,  -- 'VIEW' | 'EDIT' | 'MANAGE'
  granted_by  BIGINT NOT NULL REFERENCES user(id),
  created_at  TIMESTAMP DEFAULT NOW(),
  updated_at  TIMESTAMP DEFAULT NOW(),
  UNIQUE(article_id, user_id)
);

CREATE INDEX idx_ap_article ON article_permission(article_id);
CREATE INDEX idx_ap_user ON article_permission(user_id);
```

**权限语义**：层级递增，`VIEW < EDIT < MANAGE`。拥有高级权限自动包含低级权限。每用户每文章只存最高权限级别（UNIQUE 约束），不需要多行。

**分类权限**：

```sql
CREATE TABLE category_permission (
  id           BIGSERIAL PRIMARY KEY,
  category_id  BIGINT NOT NULL REFERENCES category(id),
  user_id      BIGINT NOT NULL REFERENCES user(id),
  permission   VARCHAR(20) NOT NULL,  -- 'VIEW' | 'EDIT' | 'MANAGE'
  granted_by   BIGINT NOT NULL REFERENCES user(id),
  created_at   TIMESTAMP DEFAULT NOW(),
  updated_at   TIMESTAMP DEFAULT NOW(),
  UNIQUE(category_id, user_id)
);

CREATE INDEX idx_cp_category ON category_permission(category_id);
CREATE INDEX idx_cp_user ON category_permission(user_id);
```

**继承规则**：分类权限**不**自动继承到文章。原因：分类是组织结构，文章是内容实体，权限语义不同。分类 EDIT 权限仅控制分类本身的编辑（名称、排序），不等于对分类下所有文章有 EDIT。文章级权限需显式授权。

**删除策略**：撤销权限时物理删除记录。权限变更通过 `updated_at` 和应用层审计日志记录，不需要 `deleted_at` 软删除——权限不是内容，不需要恢复能力。

### 3.2 API

#### 设置权限
``
PUT /api/v1/articles/{id}/permissions
Request:
{
  "permissions": [
    { "userId": 3, "permission": "EDIT" },
    { "userId": 5, "permission": "VIEW" }
  ]
}
Response: ApiResult<PermissionDTO[]>
```

#### 获取权限列表
```
GET /api/v1/articles/{id}/permissions
Response: ApiResult<PermissionDTO[]>
```

#### 移除权限
```
DELETE /api/v1/articles/{id}/permissions/{userId}
Response: ApiResult<void>
```

#### 批量查询当前用户权限（文章列表页使用）
```
POST /api/v1/articles/permissions/batch
Request: { "articleIds": [1, 2, 3] }
Response: ApiResult<Record<number, string>>  // articleId → permission
```

#### 鉴权规则
- 只有 ADMIN 或对该文章拥有 MANAGE 权限的用户可以授权/撤销
- 不能对自己授权（防止权限提升）
- ADMIN 不受资源权限限制，始终拥有所有权限
- 错误码：403（无授权资格）、404（文章不存在）、409（对自己授权）

#### 用户搜索（权限对话框使用）

授权对话框需要搜索用户，不能拉全量用户列表。新增用户搜索接口：

```
GET /api/v1/users/search?keyword={keyword}&page=1&size=20
```

- `keyword`：匹配 username 或 email（模糊，LIKE '%keyword%'）
- `page` / `size`：分页，默认 size=20
- 鉴权：仅 ADMIN 或当前文章 MANAGE 权限持有者可调用

```
Response: ApiResult<PageResult<UserDTO>>
```

返回现有 `UserDTO`（id, username, email, avatarUrl, role），无需新增类型。

**前端集成**：`api/user.ts` 新增 `searchUsers(keyword, page, size)`，PermissionDialog 内用 debounce 300ms 的 input 触发搜索，下拉展示搜索结果。

#### 分类权限 API 结构相同，路径为 `/api/v1/categories/{id}/permissions`

### 3.3 前端

- `utils/permission.ts` 新增 `canViewArticle`、`canEditArticle` 增加 permission list 参数
- **明确：前端权限判断仅为 UX 优化（隐藏/禁用按钮），不是安全边界。所有写操作由后端中间件校验。**
- 文章详情页加载时同时获取权限列表
- 文章列表页通过批量查询 API 获取权限，控制操作按钮显示
- 分类管理页加权限设置入口（对话框）
- **权限管理 UI 须在对话框顶部显示提示：「资源权限为补充授权，不能缩小角色已有权限。例如 EDITOR 角色用户即使只授予 VIEW 权限，仍可编辑自己的文章。」** 使用者需要明确理解并集策略的语义，避免误以为资源权限可以限制高角色用户。如果未来需要限制能力（黑名单模式），单独迭代。

- 新增 `ResourcePermissionMiddleware`，在以下接口中加入资源级权限校验：
  - `PUT /api/v1/articles/{id}` → 需要 EDIT 权限
  - `DELETE /api/v1/articles/{id}` → 需要 MANAGE 权限（或 ADMIN）
  - `PATCH /api/v1/articles/{id}/status` → 需要 MANAGE 权限
  - `PUT /api/v1/categories/{id}` → 分类 EDIT 权限
- 校验顺序：先查 `article_permission`，有记录则按资源权限判断；无记录则走现有角色逻辑
- 优先级：资源权限与角色权限**取并集**（宽松策略）。即：角色允许 OR 资源允许 → 放行。这样资源权限只能放大不能缩小，确保不会因误配权限导致原本可操作的用户被锁。

### 3.4 兼容性与数据迁移

- 现有角色权限作为默认策略，资源权限为补充
- 未设置资源权限时走现有逻辑，零迁移成本
- **不需要迁移脚本**：现有文章权限完全由角色 + 作者关系决定，新表为空白。上线后权限行为与之前完全一致，管理员按需手动添加资源级权限即可
- `PermissionDTO` 类型定义：
```typescript
interface PermissionDTO {
  articleId: number
  userId: number
  username: string
  permission: 'VIEW' | 'EDIT' | 'MANAGE'
  grantedBy: number
  grantedByName: string
  createdAt: string
  updatedAt: string
}
```

**改动范围**：
- 后端：新增 2 张表 + Permission CRUD API + 查询时 join 权限
- 前端：`permission.ts` 扩展 + 权限管理 UI
- `types/api.ts` 新增 `PermissionDTO`

---

## 4. Abort Controller

**现状**：`request.ts` 基于 axios，无请求取消机制。页面切换时未完成的请求继续运行，可能造成状态污染（切到文章 B，文章 A 的请求回来覆盖数据）。

**方案**：

### 4.1 封装

在 `api/request.ts` 中添加请求取消支持：

```typescript
const MAX_PENDING = 50  // 上限，防止泄漏
const pendingRequests = new Map<string, AbortController>()

export function createRequestKey(url: string, params?: any): string {
  return `${url}?${JSON.stringify(params || '')}`
}

export function cancelPending(prefix: string) {
  // 精确匹配 + 路径前缀匹配（含末尾斜杠分隔）
  for (const [k, ctrl] of pendingRequests) {
    if (k === prefix || k.startsWith(prefix + '/') || k.startsWith(prefix + '?')) {
      ctrl.abort()
      pendingRequests.delete(k)
    }
  }
}

// 请求拦截器
request.interceptors.request.use((config) => {
  const token = getToken()
  if (token) config.headers.Authorization = `Bearer ${token}`

  // AbortController
  if (config.signal) return config  // 调用方自带 signal，不接管
  const key = createRequestKey(config.url!, config.params)
  const controller = new AbortController()
  config.signal = controller.signal

  // 超限清理最早的请求
  if (pendingRequests.size >= MAX_PENDING) {
    const [oldestKey, oldestCtrl] = pendingRequests.entries().next().value
    oldestCtrl.abort()
    pendingRequests.delete(oldestKey)
  }
  pendingRequests.set(key, controller)
  return config
})
```

- 响应拦截器中无论成功/失败都清理对应 key
- `cancelPending` 改为路径安全匹配：`/articles` 不会误杀 `/articles/123`（需匹配 `/` 或 `?` 边界）
- 全局错误拦截器过滤 `CanceledError`，不弹 toast：
```typescript
if (axios.isCancel(error)) return Promise.reject(error)  // 静默
```

### 4.2 使用方式

```typescript
// ArticleDetail.vue
onMounted(() => {
  cancelPending('/articles')  // 取消前一个文章的请求
  getArticle(articleId)       // 发起新请求
})

onUnmounted(() => {
  cancelPending(`/articles/${articleId}`)
})
```

### 4.3 封装 composable

新建 `composables/useAbort.ts`：

```typescript
export function useAbort(prefix: string) {
  onMounted(() => cancelPending(prefix))
  onUnmounted(() => cancelPending(prefix))
}
```

组件只需 `useAbort('/articles')` 即可。

**改动范围**：
- `api/request.ts` — 加 AbortController 管理
- 新建 `composables/useAbort.ts`
- 各 View 组件加 `useAbort` 调用（ArticleDetail、ArticleList、Search 等）

---

## 5. 大文章 Diff 性能优化

**现状**：`diffLines` 对整篇文章做 diff，结果直接渲染为 DOM。长文章（>5000 行）diff 产物可达上万 DOM 节点，页面卡顿。`diff-view` 容器限制 `max-height: 400px` 但 DOM 节点数不减。

**方案**：分两步，可独立实施。

### 5.1 虚拟滚动渲染（核心）

将 diff 结果渲染改为虚拟滚动：

- 新建 `components/VirtualDiffList.vue`
- Props：`parts: DiffPart[]`、`estimatedLineHeight: number`（默认 24px）
- **行高策略**：diff 输出按行切分，每个 part 可能为多行。渲染时将 parts 展平为单行数组，每行用 `<div>` 包裹并设置固定 `min-height: 24px` + `overflow-x: auto`。长 URL / 代码块通过 `word-break: break-all` + `overflow-x: auto` 确保不撑高行。**不使用等宽字体外的多行内容**，保证行高一致
- 如果未来需要支持真正的可变行高，改用 `vue-virtual-scroller`（`RecycleScroller` 支持 dynamic size），但首期用固定行高 + CSS 控制即可
- 可视区域计算：
```
startIndex = Math.floor(scrollTop / lineHeight) - buffer
endIndex = startIndex + Math.ceil(containerHeight / lineHeight) + 2 * buffer
总滚动高度 = totalLines * lineHeight
```
- 滚动条高度用 `padding-top` / `padding-bottom` 占位模拟
- 估计代码量：组件主体 ~120 行，比之前预估的 100 行略多（含滚动条同步和 buffer 逻辑），但仍可控

### 5.2 分块 Diff（可选增强）

对超长文章（> 10000 字符）先按段落分块，只对变更块做精细 diff：

```typescript
// 先做 diffLines 拿到 coarse parts
// 对 added/removed 连续段做 diffWords 精细对比
// 未变更段折叠显示 "… (未变更的 120 行) …"
```

- 未变更区域折叠为一行摘要，大幅减少渲染节点
- 提供开关：用户可选择"显示全部"或"仅显示变更"

**性能评估**：`diffLines` 对 20000 字符文章耗时通常 < 50ms（纯字符串操作）。`diffWords` 只对变更段执行（通常 < 5% 的内容），额外开销 < 10ms。两次 diff 的总耗时远小于 DOM 渲染瓶颈，不是瓶颈所在。

### 5.3 指标

| 文章大小 | 现有方案 DOM 节点 | 优化后 DOM 节点 |
|---------|-----------------|---------------|
| 500 行 | ~800 | ~50 |
| 5000 行 | ~8000 | ~50 |
| 20000 行 | ~30000+（卡死） | ~50 |

> 注：以上 DOM 节点数为虚拟滚动的理论值（可视区域行数 × 每行 DOM 节点）。实施前应先 profile 现有方案的实际数据，建立基准后再验证优化效果。

**改动范围**：
- 新建 `components/VirtualDiffList.vue`
- `views/ArticleDetail.vue` — diff 渲染替换为虚拟滚动组件
- 可选：`api/article.ts` 无改动

---

## 实施分期建议

| 优先级 | 优化项 | 预估工时 | 风险 |
|-------|-------|---------|------|
| P1-1 | Abort Controller | 0.5d | 低，纯前端 |
| P1-2 | Diff 方向标注 | 0.5d | 低，纯前端 |
| P1-3 | 分类缩进 | 0.5d | 低，纯前端 |
| P1-4 | 大文章 Diff | 1d | 中，需虚拟滚动 |
| P1-5 | 权限细化 | 2.5d | 中高，前后端 + 数据库 |

建议先做 1-3（纯前端小改动），再做 4（性能），最后做 5（架构性改动）。

**P1-5 工期拆分**：
- 后端数据模型 + 迁移 + 4 个 API + 中间件改造：1d
- 前端类型定义 + permission.ts 扩展 + 权限管理 UI + 批量查询集成：1d
- 联调 + 边界测试：0.5d

**所有工期均含 0.5d 联调缓冲**（已摊入上表）。

---

## 附录：相关文件清单

| 文件 | 涉及优化项 |
|------|----------|
| `frontend/src/api/request.ts` | Abort Controller |
| `frontend/src/components/CategoryTree.vue` | 分类缩进 |
| `frontend/src/views/ArticleDetail.vue` | Diff 方向、大文章 Diff |
| `frontend/src/utils/permission.ts` | 权限细化 |
| `frontend/src/types/api.ts` | 权限细化 |
