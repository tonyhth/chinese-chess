# P2 实施计划

> 2026-04-09 · Alex · v2（根据 Vera 审查清单修订）
> 基于：`proposals/p1-optimization-v2.md` v2.1（Vera 审查通过）
> 项目：knowledge-base · 项目目录：`~/DevTeam/projects/knowledge-base/`

---

## 总览

| 序号 | 优化项 | 预估工时 | 风险 | 类型 |
|------|--------|---------|------|------|
| 1 | Abort Controller | 0.5d | 低 | 纯前端 |
| 2 | Diff 方向标注 | 0.5d | 低 | 纯前端 |
| 3 | 分类缩进 | 0.5d | 低 | 纯前端 |
| 4 | 大文章 Diff 虚拟滚动 | 1d | 中 | 纯前端 |
| 5 | 权限细化 | 2.5d | 中高 | 前后端+数据库 |

**依赖关系**：五项互相独立，可并行开发。但建议按顺序串行交付，降低集成风险。

---

## 1. Abort Controller

### 改动文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `frontend/src/api/request.ts` | 修改 | 添加 AbortController 管理、请求拦截器、取消逻辑 |
| `frontend/src/composables/useAbort.ts` | 新建 | 封装 `useAbort(prefix)` composable |
| `frontend/src/views/ArticleDetail.vue` | 修改 | 加 `useAbort('/articles')` |
| `frontend/src/views/ArticleList.vue` | 修改 | 加 `useAbort('/articles')` |
| `frontend/src/views/Search.vue` | 修改 | 加 `useAbort('/search')` |
| `frontend/src/views/CategoryManage.vue` | 修改 | 加 `useAbort('/categories')` |
| `frontend/src/__tests__/request-abort.test.ts` | 修改 | 更新测试覆盖新逻辑 |
| `frontend/src/__tests__/useAbort.test.ts` | 修改 | 更新测试 |

### 实施步骤

1. **修改 `api/request.ts`**
   - 在文件顶部定义 `pendingRequests: Map<string, AbortController>` 和 `MAX_PENDING = 50`
   - 实现 `createRequestKey(url, params)`：返回 `${url}?${JSON.stringify(params || '')}`
   - 实现 `cancelPending(prefix)`：遍历 Map，匹配 `k === prefix || k.startsWith(prefix + '/') || k.startsWith(prefix + '?')` 的条目，调用 `ctrl.abort()` 并删除
   - 在请求拦截器中：
     - 如果 `config.signal` 已存在（调用方自带），跳过
     - 否则创建新 `AbortController`，绑定到 `config.signal`，存入 Map
     - 超限时取最早条目 abort + 删除
   - 在响应拦截器（成功和失败分支）中清理对应 key
   - 在全局错误拦截器中：`if (axios.isCancel(error)) return Promise.reject(error)` 静默处理

2. **新建 `composables/useAbort.ts`**
   ```typescript
   import { onMounted, onUnmounted } from 'vue'
   import { cancelPending } from '@/api/request'

   export function useAbort(prefix: string) {
     onMounted(() => cancelPending(prefix))
     onUnmounted(() => cancelPending(prefix))
   }
   ```

3. **在各 View 中集成**
   - `ArticleDetail.vue`：`useAbort(`/articles/${articleId}`)` — onMounted 时取消同一文章 ID 的旧请求，onUnmounted 时取消当前请求。注意：这里用精确 ID 而非 `/articles` 前缀，避免 mounted 时误杀其他文章的请求
   - `ArticleList.vue`：`useAbort('/articles')` — onMounted 取消上一次列表请求
   - `Search.vue`：`useAbort('/search')`
   - `CategoryManage.vue`：`useAbort('/categories')`

4. **更新测试**
   - `request-abort.test.ts`：验证拦截器添加 signal、cancelPending 精确匹配、超限清理、CanceledError 静默
   - `useAbort.test.ts`：验证 composable 在 mounted/unmounted 时调用 cancelPending

### 注意事项和风险点

- ⚠️ `cancelPending` 的路径匹配必须精确：`/articles` 不能误杀 `/articles/123`。用 `/` 和 `?` 作为边界分隔符。代码中必须加注释说明为什么不用简单的 `startsWith(prefix)`，防止未来维护者"简化"掉边界判断：
  ```typescript
  // 注意：不能用 startsWith(prefix) 因为 '/articles' 会误匹配 '/articles/123'
  // 必须检查边界字符 '/' 或 '?'
  if (k === prefix || k.startsWith(prefix + '/') || k.startsWith(prefix + '?'))
  ```
- ⚠️ 调用方自带 `config.signal` 时不要覆盖，避免与第三方库冲突
- ⚠️ `pendingRequests` 是模块级单例，注意测试间需要 reset（测试中 mock 或清理 Map）
- 超限清理策略（FIFO）足够简单可靠，无需 LRU

### 验收标准

- [ ] 切换文章时，前一个文章的未完成请求被取消，不会覆盖当前文章数据
- [ ] 取消的请求不弹出 toast 错误提示
- [ ] pendingRequests Map 不会无限增长（超限自动清理）
- [ ] 调用方自带 signal 时不被覆盖
- [ ] 所有现有测试通过 + 新测试覆盖上述场景

---

## 2. Diff 方向标注

### 改动文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `frontend/src/views/ArticleDetail.vue` | 修改 | diff 工具栏 UI + showDiff 逻辑 + 方向交换 |

### 实施步骤

1. **修正 `showDiff` 参数顺序**
   - 当前 `diffLines(currentContent, targetContent)` 语义反了
   - 改为 `diffLines(targetContent, currentContent)`，使 added = 当前比历史多的内容
   - 新增 `direction` ref：`const direction = ref<'forward' | 'reverse'>('forward')`

2. **重写 `showDiff` 函数**
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

3. **重构 diff 工具栏 UI**
   - 改为双栏标题：「左侧 v{{ oldVersion }}（旧）→ 右侧 v{{ newVersion }}（当前）」
   - 工具栏右侧加"交换方向"按钮（图标用 ↔），点击后：
     - `direction.value = direction.value === 'forward' ? 'reverse' : 'forward'`
     - 重新调用 `showDiff(currentVersion)`

4. **diff 行样式优化**
   - `diff-add` 行前加 `+` 前缀，背景绿色，tooltip "新增内容"
   - `diff-remove` 行前加 `-` 前缀，背景红色，删除线，tooltip "已删除内容"
   - `+`/`-` 前缀确保色盲友好（WCAG 1.4.1），不仅仅是颜色区分

5. **空 diff 结果处理**
   - 如果 `diffLines` 返回空数组（两版本内容完全相同），diff 内容区显示空状态提示：「两个版本内容完全相同，无差异」
   - 工具栏仍显示版本号对比

6. **更新测试**
   - `diff-logic.test.ts`：验证参数顺序正确性、方向交换逻辑

### 注意事项和风险点

- ⚠️ 参数顺序修正是关键：改完后 added 内容应该是"当前版本比历史版本多的内容"
- ⚠️ 交换方向后版本号显示也要同步更新，不能只换内容不换标题
- ⚠️ 两个版本内容完全相同时，diff 结果为空，需要空状态提示
- tooltip 文案简洁即可，不需要复杂 UI

### 验收标准

- [ ] diff 工具栏清晰标注「左侧 v3（旧）→ 右侧 v5（当前）」
- [ ] `+`/`-` 前缀 + 颜色 + 删除线，色盲可辨识
- [ ] 点击交换方向按钮后，左右内容 + 版本号同步交换
- [ ] added 内容语义正确（当前比历史多的 = 绿色）
- [ ] 两版本内容相同时，显示「两个版本内容完全相同，无差异」空状态提示

---

## 3. 分类缩进

### 改动文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `frontend/src/components/CategoryTreeItem.vue` | 修改 | 改为递归组件，接受 `depth` prop |
| `frontend/src/components/CategoryTree.vue` | 修改 | 使用递归 CategoryTreeItem |
| `frontend/src/views/CategoryManage.vue` | 修改 | 如有分类管理列表，同步加缩进 |
| `frontend/src/__tests__/CategoryTreeItem.test.ts` | 修改 | 测试递归渲染 |
| `frontend/src/__tests__/CategoryTree.test.ts` | 修改 | 测试整体树渲染 |

### 实施步骤

1. **重构 `CategoryTreeItem.vue` 为递归组件**
   - Props：`node: CategoryTreeNode`、`depth: number`（默认 0）
   - 模板中：`padding-left: depth * 20px`
   - 节点前加折叠/展开箭头（▶/▼），默认展开
   - 递归渲染 `v-for child in node.children`：`<CategoryTreeItem :node="child" :depth="depth + 1" />`

2. **修改 `CategoryTree.vue`**
   - 遍历根节点列表，每个根节点渲染 `<CategoryTreeItem :node="rootNode" :depth="0" />`
   - 移除旧的硬编码 `padding-left: 24px`

3. **修改 `CategoryManage.vue`**（如有分类管理列表）
   - 同步使用缩进渲染，保持一致性

4. **性能考量**
   - 分类节点 >50 或层级 >3 时，默认折叠到第 2 层
   - 当前项目分类 <30，首期不做懒加载，预留 `lazy` prop 接口

5. **更新测试**
   - `CategoryTreeItem.test.ts`：
     - 3 层嵌套渲染正确缩进（depth=0 无缩进，depth=1 缩进 20px，depth=2 缩进 40px）
     - 折叠/展开箭头点击后 children 显隐切换
     - 无 children 的节点不渲染折叠箭头
     - depth=0 的根节点 padding-left 为 0
   - `CategoryTree.test.ts`：
     - 多根节点整体树渲染正确
     - 递归嵌套结构正确

### 注意事项和风险点

- ⚠️ 递归组件必须正确命名（Vue SFC 自引用需要 `name` 选项或文件名匹配）
- ⚠️ 无 children 的节点不渲染折叠箭头
- 折叠状态用组件内 `ref` 管理，不需要持久化

### 验收标准

- [ ] 分类树支持任意层级嵌套，每层缩进 20px
- [ ] 折叠/展开箭头正常工作，默认展开
- [ ] 当前项目分类数量下无性能问题
- [ ] 无子节点的分类不显示折叠箭头
- [ ] depth=0 的根节点无缩进（padding-left: 0）

---

## 4. 大文章 Diff 虚拟滚动

### 改动文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `frontend/src/components/VirtualDiffList.vue` | 修改 | 虚拟滚动 diff 渲染组件 |
| `frontend/src/views/ArticleDetail.vue` | 修改 | diff 渲染替换为 VirtualDiffList |
| `frontend/src/__tests__/VirtualDiffList.test.ts` | 修改 | 虚拟滚动测试 |

### 实施步骤

1. **基准测试（先于实现）**
   - 准备一篇 5000+ 行的测试文章（可用脚本生成）
   - 用 Chrome DevTools Performance 面板记录现有 diff 渲染的：DOM 节点数、首次渲染时间（FP/FCP）、滚动 FPS
   - 记录基准数据，作为优化效果对比依据

2. **实现 `VirtualDiffList.vue` 虚拟滚动**
   - Props：`parts: DiffPart[]`、`estimatedLineHeight: number`（默认 24）
   - 将 parts 展平为单行数组：
     ```typescript
     interface FlatLine { type: 'add' | 'remove' | 'unchanged'; text: string }
     const flatLines = computed(() => {
       // parts 中每个 part 可能多行，按 \n 拆分展平
     })
     ```
   - 固定行高策略：每行 `min-height: 24px` + `overflow-x: auto` + `word-break: break-all`
   - 可视区域计算：
     ```typescript
     const buffer = 5
     const startIndex = Math.floor(scrollTop / lineHeight) - buffer
     const endIndex = startIndex + Math.ceil(containerHeight / lineHeight) + 2 * buffer
     const totalHeight = totalLines * lineHeight
     ```
   - 用 `padding-top` + `padding-bottom` 模拟总滚动高度
   - 监听 `scroll` 事件（可用 `requestAnimationFrame` 节流）更新 `startIndex`/`endIndex`

3. **修改 `ArticleDetail.vue`**
   - diff 渲染区域替换为 `<VirtualDiffList :parts="diffResult.parts" />`
   - 移除旧的直接 DOM 渲染逻辑

4. **更新测试**
   - `VirtualDiffList.test.ts`：展平逻辑、可视区域计算、滚动更新、buffer 边界

> **分块 Diff 不纳入 P2**，记为 backlog item。P2 只做虚拟滚动渲染。

### 注意事项和风险点

- ⚠️ **行高一致性是关键**：必须保证每行固定高度。长 URL / 代码块通过 `word-break: break-all` 确保不撑高行
- ⚠️ scroll 事件需要节流（`requestAnimationFrame`），避免高频 re-render
- ⚠️ 虚拟滚动的总高度 = 行数 × 行高，如果行高不一致会导致滚动位置偏移
- 如需支持可变行高，改用 `vue-virtual-scroller` 的 `RecycleScroller`，但首期不建议引入新依赖
- **建议先 profile 现有方案**：已在步骤 1 中明确为必须前置步骤

### 验收标准

- [ ] 5000 行文章 diff 渲染流畅，无卡顿
- [ ] 虚拟滚动后 DOM 节点数稳定在 ~50 左右（与文章大小无关）
- [ ] 滚动位置准确，无跳动或错位
- [ ] diff 内容完整，不因虚拟滚动丢失内容
- [ ] 现有 diff 功能（着色、方向标注）不受影响

---

## 5. 权限细化

### 改动文件清单

#### 后端

| 文件 | 操作 | 说明 |
|------|------|------|
| `backend/src/main/java/com/kb/permission/entity/ArticlePermission.java` | 新建 | article_permission 实体 |
| `backend/src/main/java/com/kb/permission/entity/CategoryPermission.java` | 新建 | category_permission 实体 |
| `backend/src/main/java/com/kb/permission/mapper/ArticlePermissionMapper.java` | 新建 | MyBatis Plus Mapper |
| `backend/src/main/java/com/kb/permission/mapper/CategoryPermissionMapper.java` | 新建 | MyBatis Plus Mapper |
| `backend/src/main/java/com/kb/permission/dto/PermissionDTO.java` | 新建 | 权限返回 DTO |
| `backend/src/main/java/com/kb/permission/dto/PermissionSetRequest.java` | 新建 | 批量设置权限请求 |
| `backend/src/main/java/com/kb/permission/service/ArticlePermissionService.java` | 新建 | 权限 CRUD + 批量查询 |
| `backend/src/main/java/com/kb/permission/service/CategoryPermissionService.java` | 新建 | 分类权限 CRUD |
| `backend/src/main/java/com/kb/permission/controller/ArticlePermissionController.java` | 新建 | 文章权限 API |
| `backend/src/main/java/com/kb/permission/controller/CategoryPermissionController.java` | 新建 | 分类权限 API |
| `backend/src/main/java/com/kb/common/security/ResourcePermissionMiddleware.java` | 新建 | 资源级权限校验 |
| `backend/src/main/java/com/kb/user/controller/UserController.java` | 修改 | 新增用户搜索接口 |
| `backend/src/main/java/com/kb/user/service/UserService.java` | 修改 | 新增 searchUsers 方法 |
| `backend/src/main/java/com/kb/config/SecurityConfig.java` | 修改 | 注册新 API 路径 |
| `backend/src/main/resources/db/migration/V*.sql` | 新建 | 建表 + 索引 |
| `backend/src/test/java/com/kb/permission/service/ArticlePermissionServiceTest.java` | 修改 | 更新测试 |

#### 前端

| 文件 | 操作 | 说明 |
|------|------|------|
| `frontend/src/types/api.ts` | 修改 | 新增 PermissionDTO 类型 |
| `frontend/src/api/permission.ts` | 修改 | 新增权限 CRUD + 批量查询 API |
| `frontend/src/api/user.ts` | 修改 | 新增 searchUsers |
| `frontend/src/utils/permission.ts` | 修改 | 扩展 canViewArticle/canEditArticle |
| `frontend/src/components/PermissionDialog.vue` | 修改 | 权限管理对话框 |
| `frontend/src/views/ArticleDetail.vue` | 修改 | 加载权限列表 + 权限管理入口 |
| `frontend/src/views/ArticleList.vue` | 修改 | 批量权限查询 + 按钮显示控制 |
| `frontend/src/views/CategoryManage.vue` | 修改 | 分类权限设置入口 |
| `frontend/src/__tests__/permission-utils.test.ts` | 修改 | 测试扩展后的权限判断 |
| `frontend/src/__tests__/PermissionDialog.test.ts` | 修改 | 测试权限对话框 |

### 实施步骤

#### Phase 5A：后端数据模型 + API（1d）

1. **创建数据库迁移脚本**
   - 新建 `article_permission` 表 + `category_permission` 表（含索引）
   - 无数据迁移，新表为空

2. **新建实体和 Mapper**
   - `ArticlePermission.java`：id, articleId, userId, permission(VARCHAR(20)), grantedBy, createdAt, updatedAt
   - `CategoryPermission.java`：同结构，关联 category_id
   - 对应 MyBatis Plus Mapper

3. **新建 DTO**
   - `PermissionDTO`：articleId/categoryId, userId, username, permission, grantedBy, grantedByName, createdAt, updatedAt
   - `PermissionSetRequest`：permissions 数组 `[{userId, permission}]`

4. **实现 Service 层**
   - `ArticlePermissionService`：
     - `setPermissions(articleId, request, operatorId)` — 批量 upsert + 校验操作者权限
     - `getPermissions(articleId)` — join user 表获取 username
     - `removePermission(articleId, userId, operatorId)` — 物理删除 + 校验
     - `batchQueryPermissions(articleIds, currentUserId)` — 批量查询当前用户权限
   - `CategoryPermissionService`：同结构，关联 category
   - **鉴权逻辑**：只有 ADMIN 或对该资源拥有 MANAGE 权限的用户可授权/撤销。不能对自己授权。

5. **实现 Controller 层**
   - `ArticlePermissionController`：
     - `PUT /api/v1/articles/{id}/permissions` — 批量设置权限，鉴权：ADMIN 或该文章 MANAGE
     - `GET /api/v1/articles/{id}/permissions` — 获取权限列表，鉴权：ADMIN 或该文章 MANAGE
     - `DELETE /api/v1/articles/{id}/permissions/{userId}` — 移除权限，鉴权：ADMIN 或该文章 MANAGE
     - `POST /api/v1/articles/permissions/batch` — 批量查询当前用户权限，body `{ articleIds: number[] }`，返回 `Record<number, string>`（JSON plain object，articleId → 权限级别字符串），前端用 `Object.entries()` 解析
   - `CategoryPermissionController`：结构与文章权限完全对称
     - `PUT /api/v1/categories/{id}/permissions` — 鉴权：ADMIN 或该分类 MANAGE
     - `GET /api/v1/categories/{id}/permissions` — 鉴权：ADMIN 或该分类 MANAGE
     - `DELETE /api/v1/categories/{id}/permissions/{userId}` — 鉴权：ADMIN 或该分类 MANAGE
     - 注意：分类权限无批量查询接口（分类列表页不需要按权限控制按钮）

6. **新增用户搜索接口**
   - `UserService.searchUsers(keyword, page, size)`：LIKE 匹配 username 或 email
   - `UserController` 新增 `GET /api/v1/users/search`

7. **新建 ResourcePermissionMiddleware**
   - **实现方式**：用 Spring `HandlerInterceptor`（不是 `OncePerRequestFilter`），因为它需要在 Controller 方法解析后获取路径变量（articleId/categoryId），`OncePerRequestFilter` 太早拿不到路径参数
   - **注册方式**：新建 `WebMvcConfig implements WebMvcConfigurer`（或在现有配置类中添加），通过 `addInterceptors()` 注册，拦截路径 `/api/v1/articles/**` 和 `/api/v1/categories/**`
   - **排除路径**（不拦截）：`/api/v1/articles/*/permissions/**`、`/api/v1/categories/*/permissions/**`（权限管理接口走自己的鉴权，避免循环校验）
   - 校验顺序：先查 `article_permission`，有记录则按资源权限判断；无记录走现有角色逻辑
   - 优先级：资源权限 ∪ 角色权限（宽松策略，并集）
   - 需拦截的接口：
     - `PUT /api/v1/articles/{id}` → EDIT
     - `DELETE /api/v1/articles/{id}` → MANAGE
     - `PATCH /api/v1/articles/{id}/status` → MANAGE
     - `PUT /api/v1/categories/{id}` → 分类 EDIT
   - 错误码：403（无权）、404（资源不存在）、409（对自己授权）

#### Phase 5B：前端类型 + 权限判断 + UI（1d）

8. **扩展类型定义**
   - `types/api.ts` 新增 `PermissionDTO` 接口

9. **扩展 API 层**
   - `api/permission.ts`：新增 setPermissions, getPermissions, removePermission, batchQueryPermissions, 对应分类权限方法
   - `api/user.ts`：新增 `searchUsers(keyword, page, size)`

10. **扩展权限判断工具**
    - `utils/permission.ts`：`canViewArticle`/`canEditArticle` 增加 permission list 参数
    - 逻辑：角色权限 ∪ 资源权限 → 有任一满足即允许
    - **Fallback 策略**：如果 `batchQueryPermissions` 请求失败（网络错误），fallback 到纯角色权限判断（忽略资源权限），而不是默认无权限（全部按钮隐藏）。实现方式：调用方在请求失败时传 `undefined`（表示未获取到资源权限），函数内对 `undefined` 跳过资源权限判断，只走角色逻辑

11. **修改 PermissionDialog.vue**
    - 对话框顶部固定显示提示文案（info 样式，不可关闭）：
      > 「资源权限为补充授权，不能缩小角色已有权限。例如 EDITOR 角色用户即使只授予 VIEW 权限，仍可编辑自己的文章。」
    - 用户搜索：debounce 300ms input 触发 `searchUsers`，下拉展示搜索结果（显示 username + email）
    - 权限级别选择：VIEW / EDIT / MANAGE（单选，默认 EDIT）
    - 已授权列表：每行显示 username + 权限级别标签 + 移除按钮
    - 不允许对自己授权（搜索结果中排除自己，或提交时校验）

12. **集成到各页面**
    - `ArticleDetail.vue`：onMounted 加载权限列表，展示权限管理入口按钮
    - `ArticleList.vue`：通过批量查询 API 获取权限，控制编辑/删除按钮显示
    - `CategoryManage.vue`：分类管理页加权限设置入口

#### Phase 5C：联调 + 边界测试（0.5d）

13. **联调验证 — 文章权限**
    - ADMIN 授权/撤销 → 正常
    - EDITOR 对自己文章操作 → 走角色权限，不受资源权限影响
    - EDITOR 被授予其他文章 MANAGE → 可管理该文章
    - 未设置资源权限 → 走现有角色逻辑，行为不变
    - `batchQueryPermissions` 返回 `Record<number, string>`，前端用 `Object.entries()` 解析

14. **联调验证 — 分类权限**
    - ADMIN 设置分类权限 → 正常
    - 拥有分类 MANAGE 权限的非 ADMIN 用户设置分类权限 → 正常
    - 无权限用户尝试编辑分类 → 403
    - 分类权限不自动继承到其下文章（验证分类下文章仍走角色/文章级权限）

15. **边界测试**
    - 对自己授权 → 409
    - 无 MANAGE 权限的用户尝试授权 → 403
    - 权限级别递增验证（MANAGE 包含 EDIT 和 VIEW）
    - `batchQueryPermissions` articleIds 超长（>100）→ 后端返回 400 或截断
    - 用户搜索接口 keyword 为空 → 返回空列表（不报错）
    - 网络错误时前端权限判断 fallback 到角色权限

### 注意事项和风险点

- ⚠️ **权限策略是并集（宽松）**：资源权限只能放大不能缩小。这是设计决策，不是 bug。如果前端有人理解为"可以限制高角色用户"，参考对话框提示文案
- ⚠️ **不需要数据迁移**：新表为空，上线后行为与之前完全一致
- ⚠️ **分类权限不自动继承到文章**：分类是组织结构，文章是内容实体，权限语义不同
- ⚠️ **撤销权限是物理删除**：权限不是内容，不需要软删除
- ⚠️ **批量查询接口**：文章列表页需要批量查询权限，不能逐个请求。注意 articleIds 数组限制长度（建议上限 100）
- ⚠️ **用户搜索鉴权**：搜索接口仅 ADMIN 或当前资源 MANAGE 持有者可调用
- ⚠️ 中间件拦截要准确匹配 HTTP method + path，避免误拦截其他接口

### 验收标准

- [ ] ADMIN 可对任意文章/分类设置权限
- [ ] 拥有 MANAGE 权限的非 ADMIN 用户可授权/撤销
- [ ] 资源权限与角色权限取并集，不能缩小已有权限
- [ ] 未设置资源权限时，行为与之前完全一致（零迁移成本）
- [ ] 对自己授权返回 409
- [ ] 权限管理对话框正确显示提示文案
- [ ] 文章列表页通过批量查询控制按钮显示
- [ ] 分类权限不自动继承到文章
- [ ] 所有现有测试通过 + 新增后端/前端测试覆盖

---

## 执行时间线

```
Day 1 上午：Item 1 Abort Controller（0.5d）
Day 1 下午：Item 2 Diff 方向标注（0.5d）
Day 2 上午：Item 3 分类缩进（0.5d）
Day 2 下午：Item 4 基准测试 + 虚拟滚动实现 开始
Day 3 上午：Item 4 完成（累计 1d）
Day 3 下午 ~ Day 5 中午：Item 5 权限细化（2.5d）
```

## Backlog（不纳入 P2）

- **分块 Diff**（方案 5.2）：对超长文章按段落分块精细 diff + 未变更区折叠
