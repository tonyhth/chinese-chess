# 团队知识库系统 — P1 详细实施方案

> 作者：Alex | 日期：2026-04-07 | 状态：v2（审查修订后）
> 审查记录：v1 → Vera 审查 4P0/6P1/4P2 → v2 逐条修订
> 基于：P0 已交付代码（Spring Boot 3.2 + Vue 3 + PostgreSQL 16 + Redis 7 + ES 8）

---

## 1. P1 概述

P1 聚焦**搜索能力**，辅以版本管理、评论系统、文件上传，让系统从"能写文章"升级到"能搜、能协作"。

### 交付清单（13 项）

| # | 任务 | 模块 | 负责人 | 工时 | 前置依赖 |
|---|------|------|--------|------|---------|
| T1 | ES 集成 + IK 分词配置 | 后端 | Cody | 2d | — |
| T2 | 全文搜索 API（POST /search） | 后端 | Cody | 2d | T1 |
| T3 | 双写同步 + 失败重试 | 后端 | Cody | 1.5d | T1 |
| T4 | 搜索结果 Redis 缓存 | 后端 | Cody | 1d | T2 |
| T5 | 搜索建议（completion suggester） | 后端 | Cody | 1d | T1 |
| T6 | 搜索页面前端 | 前端 | Cody | 3d | T2, T4 |
| T7 | 文章版本管理 API | 后端 | Cody | 2d | — |
| T8 | 版本对比/回滚 UI | 前端 | Cody | 2d | T7 |
| T9 | 评论系统 API（楼中楼） | 后端 | Cody | 2d | — |
| T10 | 评论组件 + UI | 前端 | Cody | 2d | T9 |
| T11 | 图片上传 + Markdown 粘贴上传 | 全栈 | Cody | 1.5d | — |
| T12 | 附件上传/管理 | 全栈 | Cody | 1.5d | T11 |
| T13 | SpringDoc 接口文档 | 后端 | Cody | 0.5d | T1-T12 |

### 任务依赖图

```
T1 (ES+IK)
├── T2 (搜索API) ──→ T4 (Redis缓存) ──→ T6 (搜索前端)
├── T3 (双写同步)
└── T5 (搜索建议) ────────────────→ T6

T7 (版本管理API) ──→ T8 (版本UI)

T9 (评论API) ──→ T10 (评论UI)

T11 (图片上传) ──→ T12 (附件管理)

T13 (SpringDoc) ← T1~T12 全部完成后
```

### 工期预估

- **关键路径**：T1 → T2 → T4 → T6，共 8d
- **并行线**：T7/T8（4d）、T9/T10（4d）、T11/T12（3d）可与关键路径并行
- **总工期**：约 10 个工作日（2 周），前后端穿插进行

---

## 2. 技术方案详细设计

### 2.1 Elasticsearch 集成 + IK 分词（T1）

**目标**：ES 8 运行就绪，IK 插件安装，自定义词典加载，索引 mapping 创建。

#### 2.1.1 增量改动

P0 已有 `elasticsearch/Dockerfile` 和 `docker-compose.yml` 中的 ES 服务定义。P1 需要：

1. **验证并补全 Dockerfile**：确认 IK 插件版本与 ES 8.12.0 匹配
2. **自定义词典**：创建 `elasticsearch/config/kb_custom.dic`，初始内容为团队常用术语
3. **IK 配置扩展**：在 `IKAnalyzer.cfg.xml` 中注册自定义词典路径
4. **Spring Boot 集成**：`ElasticsearchConfig.java` 已存在，补全 `RestHighLevelClient` Bean（注：ES 8 官方推荐 `ElasticsearchClient`，但 P0 用的是 `RestHighLevelClient`，保持一致，P2 升级）

#### 2.1.2 索引 Mapping

沿用 proposal-v1.md 中的 `kb_article` mapping，**新增 completion suggester 字段**：

```json
PUT /kb_article
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "analysis": {
      "analyzer": {
        "ik_index_analyzer": {
          "type": "custom",
          "tokenizer": "ik_max_word",
          "filter": ["lowercase"]
        },
        "ik_search_analyzer": {
          "type": "custom",
          "tokenizer": "ik_smart",
          "filter": ["lowercase"]
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "articleId":    { "type": "long" },
      "title": {
        "type": "text",
        "analyzer": "ik_index_analyzer",
        "search_analyzer": "ik_search_analyzer",
        "boost": 2.0,
        "fields": {
          "keyword": { "type": "keyword" },
          "suggest": { "type": "completion", "analyzer": "ik_index_analyzer" }
        }
      },
      "content": {
        "type": "text",
        "analyzer": "ik_index_analyzer",
        "search_analyzer": "ik_search_analyzer"
      },
      "summary": {
        "type": "text",
        "analyzer": "ik_index_analyzer",
        "search_analyzer": "ik_search_analyzer"
      },
      "tagNameList":   { "type": "keyword" },
      "categoryPath":  { "type": "keyword" },
      "categoryId":    { "type": "long" },
      "authorName":    { "type": "keyword" },
      "authorId":      { "type": "long" },
      "status":        { "type": "keyword" },
      "createdAt":     { "type": "date" },
      "updatedAt":     { "type": "date" }
    }
  }
}
```

**P0 → P1 变更点**：`title` 字段新增 `suggest` 子字段（completion 类型），支持搜索建议。

#### 2.1.3 索引初始化策略

应用启动时自动检查索引是否存在，不存在则创建：

```java
@Component
public class EsIndexInitializer implements ApplicationRunner {
    @Override
    public void run(ApplicationArguments args) {
        if (!restHighLevelClient.indices().exists(
                new GetIndexRequest("kb_article"), RequestOptions.DEFAULT)) {
            // 读 classpath:es/mapping.json 创建索引
        }
    }
}
```

映射 JSON 放在 `resources/es/mapping.json`，避免硬编码。

#### 2.1.4 自定义词典

`elasticsearch/config/kb_custom.dic`（初始内容）：

```
Spring Boot
MyBatis-Plus
Vue 3
Docker Compose
RESTful
Flyway
MinIO
IK分词器
前后端分离
软删除
楼中楼
```

IK 配置 `analysis-ik/IKAnalyzer.cfg.xml` 中增加：
```xml
<entry key="ext_dict">kb_custom.dic</entry>
```

#### 2.1.5 全量同步

P0 阶段没有 ES 数据。P1 需要一个全量同步入口：

```java
@PostMapping("/api/v1/search/sync-all")
// Admin 权限
// 1. 分布式锁：Redis SETNX search:sync-all:lock TTL 30min，防并发
// 2. 断点续传：记录最后同步的 articleId 到 Redis key search:sync-all:cursor
//    中断后重调，从 cursor 继续
// 3. 批次大小 500，BulkRequest
// 4. 进度反馈：Redis key search:sync-all:progress 存 {total, synced, percent}
//    前端可轮询 GET /search/sync-all/progress
```

**幂等设计**：每次全量同步前先检查锁，已加锁则返回 409。同步完成或失败后释放锁。cursor 在同步完成后清除。

只在部署后手动调一次，后续靠双写。

---

### 2.2 全文搜索 API（T2）

**目标**：实现 `POST /api/v1/search`，支持全文搜索 + 过滤 + 高亮 + 分页。

#### 2.2.1 请求/响应定义

**请求体** `SearchRequest`：

```java
public class SearchRequest {
    @NotBlank
    private String query;          // 搜索关键词
    private Long categoryId;       // 分类过滤
    private List<Long> tagIds;     // 标签过滤（AND 关系）
    private String dateFrom;       // 起始日期 yyyy-MM-dd
    private String dateTo;         // 结束日期
    @DefaultValue("relevance") 
    private String sort;           // relevance | newest | oldest
    @DefaultValue("1")
    private Integer page;          // 从 1 开始
    @DefaultValue("20")
    private Integer size;          // 每页条数，max 50
}
```

**响应体** `SearchResponse`：

```java
public class SearchResponse {
    private Long total;                    // 总命中数
    private Integer page;
    private Integer size;
    private List<SearchHit> hits;

    @Data
    public static class SearchHit {
        private Long articleId;
        private String title;              // 含高亮 tag
        private String summary;            // 含高亮 tag
        private List<String> contentHighlights; // 高亮片段列表
        private String categoryName;
        private List<String> tagNameList;
        private String authorName;
        private LocalDateTime updatedAt;
    }
}
```

#### 2.2.2 ES 查询模板

```
bool:
  must:
    - multi_match:
        query: {query}
        fields: [title^2, content, summary]
        type: best_fields
        # P1 不加 fuzziness：IK 分词 + 中文场景下 fuzziness 行为不可预测，
        # 可能产生意外的模糊匹配。英文拼写容错放 P2 评估。
  filter:
    - term: { status: "PUBLISHED" }
    - term: { categoryId: X }       # 可选
    - terms: { tagNameList: [...] }  # 可选，AND 用 terms_set + minimum_should_match
    - range: { createdAt: { gte, lte } }  # 可选
highlight:
  pre_tags: ["<em class='hl'>"]
  post_tags: ["</em>"]
  fields:
    title:    { number_of_fragments: 0 }
    content:  { fragment_size: 150, number_of_fragments: 3 }
    summary:  { fragment_size: 100, number_of_fragments: 1 }
sort:
  - _score (relevance) | updatedAt (newest/oldest)
```

**标签 AND 过滤**：不能用简单的 `terms`（那是 OR），需要 `terms_set` + `minimum_should_match` = tagIds.size，或用 `bool.filter` 内嵌多个 `term`（标签少时更简单）。P1 用多 `term` 方案：

```json
"filter": [
  { "term": { "status": "PUBLISHED" } },
  { "term": { "tagNameList": "Java" } },
  { "term": { "tagNameList": "Spring" } }
]
```

每个 tag 一个 term，AND 语义自然成立。

#### 2.2.3 实现位置

- Controller：`search/controller/SearchController.java`（P0 已存在）
- Service：`search/service/SearchService.java`（P0 已存在，补全逻辑）
- Document：`search/document/ArticleDocument.java`（P0 已存在）

---

### 2.3 双写同步 + 失败重试（T3）

**目标**：文章 CRUD 时同步写 ES，失败记录到 `es_sync_fail_log`，定时重试。

#### 2.3.1 同步流程

```
文章 CRUD 操作
    │
    ├── 1. 写 PostgreSQL（主库事务）
    │
    └── 2. 写 ES（事务提交后）
         │
         ├── 成功 → 结束
         │
         └── 失败 → 记录 es_sync_fail_log
                    │
                    └── 定时任务（每 5 分钟）扫描 status=0 且 next_retry_at <= now()
                        │
                        ├── 重试成功 → status=1
                        ├── retry_count >= 5 → status=2（放弃）+ 日志告警
                        └── 重试失败 → retry_count++, next_retry_at = now() + 5min * retry_count（退避）
```

#### 2.3.2 实现方式

在 `ArticleService` 中，事务提交后触发 ES 同步：

```java
@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
public void onArticleEvent(ArticleChangeEvent event) {
    esSyncService.sync(event);
}
```

`EsSyncService.sync()`：

```java
public void sync(ArticleChangeEvent event) {
    try {
        // 构建 ES IndexRequest / DeleteRequest / UpdateRequest
        // 执行 ES 操作
    } catch (Exception e) {
        // 【关键】任何异常绝不向上抛，只落 es_sync_fail_log
        log.warn("[ES-SYNC] failed: entityType={}, entityId={}, op={}",
                event.getEntityType(), event.getEntityId(), event.getOperation(), e);
        try {
            saveFailLog(event, e);
        } catch (Exception logEx) {
            log.error("[ES-SYNC] fail-log write also failed!", logEx);
        }
    }
}
```

**原则**：sync 方法内部完整 try-catch，任何异常只写 `es_sync_fail_log`，绝不向上传播。落日志本身失败时只打 error 日志，不影响主流程。

#### 2.3.3 定时重试

```java
@Scheduled(fixedDelay = 5 * 60 * 1000) // 5 分钟
public void retryFailedSyncs() {
    List<EsSyncFailLog> pending = syncFailLogMapper.selectPending();
    for (EsSyncFailLog log : pending) {
        try {
            // 重试 ES 操作
            syncFailLogMapper.updateStatus(log.getId(), 1); // 成功
        } catch (Exception e) {
            log.setRetryCount(log.getRetryCount() + 1);
            if (log.getRetryCount() >= 5) {
                log.setStatus(2); // 放弃
                log.warn("ES sync abandoned after 5 retries: {}", log);
            } else {
                log.setNextRetryAt(Instant.now().plus(5 * log.getRetryCount(), ChronoUnit.MINUTES));
            }
            syncFailLogMapper.updateById(log);
        }
    }
}
```

#### 2.3.4 ES 文档构建

`ArticleDocument` 需要组装完整数据（标题、正文、摘要、标签名列表、分类路径、作者名）。写 ES 前需要：

1. 从 `kb_article` 取文章基本信息
2. 从 `kb_article_tag` + `kb_tag` 取标签名列表
3. 从 `kb_category` 递归拼接 `categoryPath`（如 `技术/后端开发`）
4. `content` 字段存纯文本（去除 Markdown 标记），用 `commonmark-java` AST 解析器遍历文本节点，**禁止用正则**

#### 2.3.5 已有表 `es_sync_fail_log`

P0 DDL（`V1__init.sql`）已建此表。如需新增 Flyway 迁移文件：

- `V3__p1_add_title_suggest_field.sql`：无 DDL 变更（mapping 变更在 ES 侧，不在 PG）
- 如果后续需要加字段，走新迁移文件

---

### 2.4 搜索结果 Redis 缓存（T4）

**目标**：减少重复搜索对 ES 的压力，TTL 5min，文章更新时主动清除。

#### 2.4.1 缓存策略

| 项目 | 设计 |
|------|------|
| Key | `search:{MD5(query + filters + page + size + sort)}` |
| Value | 序列化的 `SearchResponse` JSON（Jackson） |
| TTL | 5 分钟 |
| 清除时机 | 文章 create/update/delete 时清除以该文章分类+标签为前缀的所有缓存 key |

#### 2.4.2 清除策略

文章更新时无法精确知道哪些缓存 key 包含该文章（因为搜索词不可预知），因此：

**方案：文章更新时清除全部搜索缓存（简单可靠）**

```java
public void evictAllSearchCache() {
    Set<String> keys = new HashSet<>();
    try (Cursor<String> cursor = redisTemplate.scan(
            ScanOptions.scanOptions().match("search:*").count(200).build())) {
        cursor.forEachRemaining(keys::add);
    }
    if (!keys.isEmpty()) {
        redisTemplate.delete(keys);
    }
}
```

> **为什么不用精准清除**：搜索条件组合不可穷举，精准清除成本远高于全清。搜索缓存 TTL 只有 5 分钟，全清对性能影响可忽略。使用 `SCAN` 代替 `KEYS`，避免 O(N) 全库阻塞。

#### 2.4.3 实现方式

```java
@Service
public class SearchService {
    @Cacheable(value = "search", key = "#request.cacheKey()", unless = "#result.total == 0")
    public SearchResponse search(SearchRequest request) {
        // ES 查询
    }
}
```

或手动用 `RedisTemplate`，更灵活（可控制序列化、可做穿透保护）。P1 推荐手动方式。

#### 2.4.4 缓存穿透保护

- 查询结果为空时**不缓存**（`unless = "#result.total == 0"`），避免恶意搜索词占满缓存
- 如果担心 ES 被反复打空查询，可加一层空结果短 TTL 缓存（30s），P1 暂不加，观察实际流量

---

### 2.5 搜索建议（T5）

**目标**：用户输入时实时返回搜索建议（标题补全）。

#### 2.5.1 API

```
GET /api/v1/search/suggest?q={prefix}&size=10
```

响应：
```json
{
  "suggestions": [
    { "text": "Spring Boot 配置指南", "articleId": 42 },
    { "text": "Spring Security 入门", "articleId": 17 }
  ]
}
```

#### 2.5.2 ES 查询

```json
GET /kb_article/_search
{
  "suggest": {
    "title-suggest": {
      "prefix": "spring",
      "completion": {
        "field": "title.suggest",
        "size": 10,
        "skip_duplicates": true
      }
    }
  }
}
```

#### 2.5.3 索引写入

文章写入 ES 时，`title.suggest` 字段填入标题的权重输入：

```json
{
  "title": {
    "suggest": {
      "input": ["Spring Boot 配置指南", "配置指南"],
      "weight": 10
    }
  }
}
```

`weight` 可按文章浏览量动态调整（浏览量越高建议优先级越高）。关键短语拆分等高级策略放 P2。

---

### 2.6 搜索页面前端（T6）

**目标**：搜索页面，包含搜索框 + 建议下拉 + 过滤面板 + 高亮结果 + 分页。

#### 2.6.1 页面结构

```
Search.vue
├── 搜索栏（带 suggest 下拉）
├── 过滤面板（左侧或顶部）
│   ├── 分类选择（下拉/树形）
│   ├── 标签多选
│   └── 日期范围选择器
├── 搜索结果列表
│   ├── 标题（高亮）
│   ├── 摘要/内容片段（高亮）
│   ├── 标签 + 分类 + 作者 + 时间
│   └── 分页
```

#### 2.6.2 增量文件

- **新增**：`views/Search.vue`（P0 已有，补全逻辑）
- **已有**：`api/search.ts`（P0 已有，补全接口调用）
- **新增组件**：`components/SearchFilter.vue`、`components/SearchSuggest.vue`（可选，也可内联在 Search.vue）

#### 2.6.3 高亮渲染

ES 返回的高亮标记 `<em class='hl'>` 直接用 `v-html` 渲染（内容来自服务端，已 escape 过 Markdown 标记，XSS 风险可控）。CSS：

```css
em.hl {
    color: #e6a23c;
    font-style: normal;
    background: #fdf6ec;
    padding: 0 2px;
    border-radius: 2px;
}
```

#### 2.6.4 搜索防抖

搜索框输入后 300ms 防抖发请求，suggest 用 200ms 防抖。

---

### 2.7 文章版本管理 API（T7）

**目标**：版本快照、版本列表、版本回滚。P0 已有 `kb_article_version` 表。

#### 2.7.1 API 端点

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/articles/{id}/versions` | 版本列表（按版本号倒序） |
| GET | `/articles/{id}/versions/{version}` | 指定版本详情 |
| POST | `/articles/{id}/versions/{version}/restore` | 回滚到指定版本 |

#### 2.7.2 版本快照策略

**自动快照**：文章每次 update 时自动创建版本快照（`ArticleService.update()` 中）

```java
@Transactional
public ArticleDTO update(Long id, ArticleUpdateRequest req) {
    // 乐观锁：version 字段作为 WHERE 条件，防并发覆盖
    Article article = articleMapper.selectById(id);
    int currentVersion = article.getVersion();
    
    // 保存当前版本快照
    ArticleVersion snapshot = new ArticleVersion();
    snapshot.setArticleId(id);
    snapshot.setTitle(article.getTitle());
    snapshot.setContent(article.getContent());
    snapshot.setVersion(currentVersion);
    snapshot.setChangeSummary(req.getChangeSummary());
    snapshot.setCreatedBy(currentUserId());
    versionMapper.insert(snapshot);
    
    // 乐观锁更新：WHERE id=? AND version=?
    int updated = articleMapper.updateVersionAndContent(
        id, currentVersion, req.getTitle(), req.getContent(), currentVersion + 1);
    if (updated == 0) {
        throw new BusinessException(ErrorCode.ARTICLE_VERSION_CONFLICT,
            "文章已被其他人修改，请刷新后重试");
    }
    return getArticleDTO(id);
}
```

Mapper SQL：
```sql
UPDATE kb_article SET title=#{title}, content=#{content}, version=#{newVersion}, updated_at=NOW()
WHERE id=#{id} AND version=#{oldVersion}
```

**手动快照**（P2 考虑）：P1 只做自动快照，不提供手动创建版本的入口。

#### 2.7.3 版本回滚

回滚操作 = 将指定版本的 content/title 复制回 kb_article，version +1，同时创建一条新版本快照记录回滚操作。

```java
@Transactional
public void restore(Long articleId, Integer targetVersion) {
    ArticleVersion target = versionMapper.findByArticleIdAndVersion(articleId, targetVersion);
    Article article = articleMapper.selectById(articleId);
    int currentVersion = article.getVersion();
    
    // 先快照当前版本
    ArticleVersion snapshot = new ArticleVersion();
    snapshot.setArticleId(articleId);
    snapshot.setTitle(article.getTitle());
    snapshot.setContent(article.getContent());
    snapshot.setVersion(currentVersion);
    snapshot.setChangeSummary("回滚到版本 " + targetVersion);
    snapshot.setCreatedBy(currentUserId());
    versionMapper.insert(snapshot);
    
    // 乐观锁更新
    int updated = articleMapper.updateVersionAndContent(
        articleId, currentVersion, target.getTitle(), target.getContent(), currentVersion + 1);
    if (updated == 0) {
        throw new BusinessException(ErrorCode.ARTICLE_VERSION_CONFLICT,
            "文章已被其他人修改，回滚冲突，请刷新后重试");
    }
}
```

**并发控制**：update 和 restore 共用同一个乐观锁机制（version 字段 WHERE 条件），两个用户同时回滚时只有一个成功，另一个收到版本冲突提示。

#### 2.7.4 版本保留策略

- 不自动清理版本，全量保留
- 单篇文章版本数预期 < 100，不做分页优化，一次返回全部
- P2 可考虑版本清理策略（如保留最近 50 个）

#### 2.7.5 实现位置

- Service：`article/service/ArticleVersionService.java`（P0 已存在）
- Controller：在 `ArticleController` 中增加版本相关端点

---

### 2.8 版本对比/回滚 UI（T8）

**目标**：可视化展示版本列表、版本差异对比、一键回滚。

#### 2.8.1 页面结构

在 `ArticleDetail.vue` 或新页面 `ArticleVersions.vue` 中：

```
版本管理 Tab
├── 版本列表（时间线形式）
│   ├── 版本号 + 变更说明 + 操作人 + 时间
│   └── 操作：查看 | 对比 | 回滚
├── 版本对比面板（左右或 inline diff）
│   ├── 左：当前版本
│   └── 右：选中版本
│   └── 差异高亮（新增绿色、删除红色）
└── 回滚确认弹窗
```

#### 2.8.2 Diff 算法

前端用 `diff-match-patch` 或 `jsdiff` 库进行文本对比。对比结果以 inline diff 形式展示（Markdown 内容）。

```bash
npm install diff
```

```typescript
import { diffLines } from 'diff';
const diffs = diffLines(currentContent, previousContent);
```

#### 2.8.3 路由

在 `router/index.ts` 中添加：

```
/articles/:id/versions       → ArticleVersions.vue
```

或在 ArticleDetail 页内用 Tab 切换，不需要新路由。P1 推荐页内 Tab 方案，减少路由复杂度。

---

### 2.9 评论系统 API — 楼中楼（T9）

**目标**：支持 3 层嵌套评论，软删除保持结构，`WITH RECURSIVE` CTE 一次查出。

#### 2.9.1 API 端点

P0 已有基础结构，P1 补全逻辑：

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/articles/{id}/comments` | 评论列表（平铺 + parent_id，前端组树） |
| POST | `/articles/{id}/comments` | 发表评论 |
| DELETE | `/comments/{id}` | 软删除评论 |

#### 2.9.2 评论树查询（CTE）

```sql
WITH RECURSIVE comment_tree AS (
    -- 基础：指定文章的所有顶级评论
    SELECT c.*, u.username AS author_name, u.avatar_url,
           0 AS depth
    FROM kb_comment c
    JOIN sys_user u ON c.author_id = u.id
    WHERE c.article_id = #{articleId}
      AND c.parent_id IS NULL

    UNION ALL

    -- 递归：所有子评论（最多 3 层）
    SELECT c.*, u.username AS author_name, u.avatar_url,
           ct.depth + 1 AS depth
    FROM kb_comment c
    JOIN sys_user u ON c.author_id = u.id
    JOIN comment_tree ct ON c.parent_id = ct.id
    WHERE ct.depth < 3
)
SELECT * FROM comment_tree
ORDER BY created_at ASC
```

#### 2.9.3 3 层嵌套限制

- 后端：创建评论时检查嵌套层级，第 3 层不允许再回复（返回 400）
- 或：第 3 层的回复统一挂在第 2 层父评论下（类似掘金策略），前端显示为对某人的回复

**P1 方案**：`kb_comment` 表新增 `depth` 冗余字段（TINYINT，默认 0），创建评论时直接读父评论 depth + 1，无需递归查询。

DDL 变更（`V3__p1_comment_depth.sql`）：
```sql
ALTER TABLE kb_comment ADD COLUMN depth SMALLINT NOT NULL DEFAULT 0;
COMMENT ON COLUMN kb_comment.depth IS '嵌套层级：0=顶级，1/2/3=回复';
CREATE INDEX idx_comment_parent_depth ON kb_comment(parent_id, depth);
```

```java
public void createComment(Long articleId, CommentCreateRequest req) {
    int depth = 0;
    if (req.getParentId() != null) {
        Comment parent = commentMapper.selectById(req.getParentId());
        depth = parent.getDepth() + 1;
        if (depth > 3) {
            throw new BusinessException(ErrorCode.COMMENT_DEPTH_EXCEEDED);
        }
    }
    Comment comment = new Comment();
    comment.setDepth(depth);
    // ... 其余字段
    commentMapper.insert(comment);
}
```

**优势**：O(1) 深度判断，无需递归查 parent 链。CTE 中的 `depth` 也可直接用表字段，无需计算。

#### 2.9.4 软删除展示

软删除的评论（`status=0`）在列表中保留，前端渲染为：

```
[该评论已被删除]
  └── 子评论正常显示
```

CTE 查询中不过滤 `status`，在 Service 层标记 `deleted=true`，前端根据标记渲染。

#### 2.9.5 实现位置

- Service：`comment/service/CommentService.java`（P0 已存在）
- Mapper：`comment/mapper/CommentMapper.java`（P0 已存在，新增 CTE 查询）

---

### 2.10 评论组件 + UI（T10）

**目标**：楼中楼评论组件，支持发表、删除、嵌套展示。

#### 2.10.1 组件结构

P0 已有 `CommentList.vue` 和 `CommentTree.vue`，P1 补全逻辑。

```
CommentList.vue
├── 评论输入框（顶部）
├── CommentTree.vue（递归组件）
│   ├── 评论内容 + 作者 + 时间
│   ├── 回复按钮
│   ├── 删除按钮（仅自己的/管理员）
│   └── 子评论列表（递归）
└── 分页（按顶级评论分页）
```

#### 2.10.2 前端组树逻辑

后端返回平铺列表（带 `parentId` + `depth`），前端组树：

```typescript
function buildTree(comments: Comment[]): CommentNode[] {
    const map = new Map<number, CommentNode>();
    const roots: CommentNode[] = [];
    
    comments.forEach(c => {
        map.set(c.id, { ...c, children: [] });
    });
    
    comments.forEach(c => {
        const node = map.get(c.id)!;
        if (c.parentId && map.has(c.parentId)) {
            map.get(c.parentId)!.children.push(node);
        } else {
            roots.push(node);
        }
    });
    
    return roots;
}
```

#### 2.10.3 回复交互

- 点"回复"按钮，在当前评论下方展开输入框，自动填入 `@用户名`
- 提交时 `parentId` 指向当前评论 id

---

### 2.11 图片上传 + Markdown 粘贴上传（T11）

**目标**：支持图片上传，Markdown 编辑器内粘贴/拖拽图片自动上传并插入链接。

#### 2.11.1 后端 API

P0 已有 `upload/controller/UploadController.java`。

```
POST /api/v1/upload/image
Content-Type: multipart/form-data

参数：file（图片文件）
限制：单文件最大 5MB，仅接受 image/jpeg|png|gif|webp

响应：
{
  "url": "http://minio:9000/kb-images/2026/04/uuid.jpg",
  "fileName": "uuid.jpg"
}
```

#### 2.11.2 MinIO 存储路径

```
kb-images/{yyyy}/{MM}/{uuid}.{ext}
kb-files/{yyyy}/{MM}/{uuid}.{ext}
```

Bucket 名称：`kb-images`（图片）、`kb-files`（附件）。应用启动时检查并创建 bucket。

#### 2.11.3 Markdown 编辑器集成

`MarkdownEditor.vue`（P0 已有，基于 md-editor-v3 或类似库）：

- **粘贴上传**：监听 `paste` 事件，检测 clipboard 中的图片，自动调 `/upload/image`，返回 URL 后插入 Markdown `![](url)`
- **拖拽上传**：监听 `drop` 事件，同理
- **工具栏上传按钮**：点击后弹出文件选择器

```typescript
// 伪代码
editor.on('paste', async (event) => {
    const files = event.clipboardData?.files;
    if (files?.length && files[0].type.startsWith('image/')) {
        event.preventDefault();
        const { url } = await uploadImage(files[0]);
        editor.insertText(`![image](${url})`);
    }
});
```

---

### 2.12 附件上传/管理（T12）

**目标**：文章关联附件的上传、列表、删除。

#### 2.12.1 后端 API

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/upload/file` | 上传附件（可选传 `article_id` 关联） |
| GET | `/articles/{id}/attachments` | 文章附件列表 |
| DELETE | `/attachments/{id}` | 删除附件（先删 MinIO 再删 DB） |

#### 2.12.2 附件删除策略

**删除顺序**：先删 MinIO 文件，再删数据库记录。

```java
@Transactional
public void deleteAttachment(Long id) {
    Attachment attachment = attachmentMapper.selectById(id);
    // 1. 先删 MinIO
    try {
        minioClient.removeObject(
            RemoveObjectArgs.builder()
                .bucket(attachment.getFilePath().split("/")[0])
                .object(attachment.getFilePath().split("/", 2)[1])
                .build());
    } catch (Exception e) {
        log.error("[ATTACHMENT] MinIO delete failed, abort DB delete. id={}", id, e);
        throw new BusinessException(ErrorCode.FILE_DELETE_FAILED);
    }
    // 2. MinIO 删除成功后才删 DB
    attachmentMapper.deleteById(id);
}
```

**原则**：MinIO 删除失败时不删数据库记录，保证数据可追溯。孤儿清理同理。

#### 2.12.3 未关联附件清理

定时任务每天清理 `article_id IS NULL AND created_at < NOW() - INTERVAL '24 hours'` 的附件：

```java
@Scheduled(cron = "0 0 3 * * ?") // 每天凌晨 3 点
public void cleanOrphanAttachments() {
    List<Attachment> orphans = attachmentMapper.selectOrphans();
    for (Attachment a : orphans) {
        minioClient.removeObject(a.getFilePath());
        attachmentMapper.deleteById(a.getId());
    }
}
```

#### 2.12.3 文件大小限制

- 图片：5MB
- 附件：50MB
- Nginx 已配置 `client_max_body_size 50M`
- Spring Boot 配置：`spring.servlet.multipart.max-file-size=50MB`

---

### 2.13 SpringDoc 接口文档（T13）

**目标**：所有 P1 新增/变更 API 自动生成 Swagger 文档。

#### 2.13.1 配置

P0 已引入 `springdoc-openapi-starter-webmvc-ui` 依赖。P1 确保所有 Controller 方法有 `@Operation` 注解：

```java
@Operation(summary = "全文搜索", description = "支持关键词、分类、标签、日期过滤，结果高亮")
@PostMapping("/search")
public Result<SearchResponse> search(@RequestBody @Valid SearchRequest request) {
    // ...
}
```

#### 2.13.2 访问地址

```
http://localhost:8080/swagger-ui.html    → Swagger UI
http://localhost:8080/v3/api-docs        → OpenAPI JSON
```

---

## 3. 数据库变更（Flyway 迁移）

P1 **不需要新增数据库表**。P0 的 `V1__init.sql` 已包含所有 P1 需要的表：

- `kb_article_version` ✅
- `kb_comment` ✅
- `kb_attachment` ✅
- `es_sync_fail_log` ✅

如需变更：

| 文件 | 内容 | 说明 |
|------|------|------|
| `V3__p1_comment_depth.sql` | 评论表加 depth 字段 + 索引 | P1 必需 |
| `V4__p1_indexes.sql` | 附件孤儿清理索引 | 可选 |

```sql
-- V3__p1_comment_depth.sql
ALTER TABLE kb_comment ADD COLUMN depth SMALLINT NOT NULL DEFAULT 0;
COMMENT ON COLUMN kb_comment.depth IS '嵌套层级：0=顶级，1/2/3=回复';
CREATE INDEX idx_comment_parent_depth ON kb_comment(parent_id, depth);

-- V4__p1_indexes.sql（可选）
CREATE INDEX IF NOT EXISTS idx_attachment_orphan ON kb_attachment(created_at) 
    WHERE article_id IS NULL;
```

---

## 4. 错误处理策略

### 4.1 ES 相关错误

| 场景 | 处理 |
|------|------|
| ES 不可用 | 搜索 API 返回 503 + 友好提示"搜索服务暂时不可用"；文章 CRUD 不受影响 |
| 双写失败 | 写入 `es_sync_fail_log`，不阻塞主流程 |
| 重试 5 次仍失败 | 标记 status=2，日志 WARN，可配告警 |
| 索引不存在 | 应用启动时自动创建，运行时如果被删返回 503 |

### 4.2 评论相关

| 场景 | 处理 |
|------|------|
| 嵌套超过 3 层 | 返回 400 + "评论最多支持 3 层嵌套" |
| 回复已删除评论 | 允许（保持结构），前端显示为回复"已删除用户" |
| 评论内容为空 | 返回 400 |

### 4.3 文件上传

| 场景 | 处理 |
|------|------|
| 文件超限 | 返回 413 + "文件大小超过限制" |
| 类型不允许 | 返回 400 + "不支持的文件类型" |
| MinIO 不可用 | 返回 503 + "文件服务暂时不可用" |

---

## 5. 日志方案

### 5.1 关键日志点

| 模块 | 日志内容 | 级别 |
|------|---------|------|
| ES 同步 | 同步成功/失败/重试 | INFO / WARN |
| 搜索 | 搜索关键词 + 耗时 + 命中数 | INFO |
| 版本回滚 | 回滚操作（谁、哪个文章、从哪版到哪版） | INFO（审计） |
| 文件上传 | 上传成功/失败 | INFO / WARN |
| 缓存清除 | 清除原因 + 数量 | DEBUG |

### 5.2 日志格式

```
[ES-SYNC] articleId=42 op=index status=success
[SEARCH] query="Spring Boot" filters={categoryId:1} hits=15 took=23ms cached=false
[VERSION] articleId=42 restore v5→v2 by userId=1
```

---

## 6. 前端路由变更

P1 新增/变更路由：

| 路径 | 组件 | 说明 |
|------|------|------|
| `/search` | `Search.vue`（已有，补全） | 搜索页面 |
| `/articles/:id` | `ArticleDetail.vue`（已有，增加版本 Tab） | 文章详情 + 版本管理 |

无新增页面路由。搜索页 P0 已有骨架，版本对比在详情页内 Tab 实现。

---

## 7. 开发顺序建议

按依赖关系和风险优先级排列：

### Week 1（Day 1-5）

| 天 | 后端 | 前端 |
|----|------|------|
| D1 | T1 ES 集成 + IK 配置 + mapping 创建 + 全量同步接口 | T11 图片上传后端 API |
| D2 | T2 搜索 API | T11 前端 Markdown 粘贴上传 |
| D3 | T3 双写同步 + T5 搜索建议 | T12 附件上传/管理 |
| D4 | T7 版本管理 API | T10 评论组件 UI（mock 数据） |
| D5 | T9 评论 API（CTE + 嵌套限制） | T6 搜索页面（过滤面板 + 结果列表） |

### Week 2（Day 6-10）

| 天 | 后端 | 前端 |
|----|------|------|
| D6 | T4 搜索缓存 + 缓存清除 | T6 搜索页面（高亮 + 分页 + suggest） |
| D7 | 联调：搜索全链路 | 联调：搜索全链路 |
| D8 | T13 SpringDoc | T8 版本对比/回滚 UI |
| D9 | 联调：版本 + 评论 + 上传 | 联调：版本 + 评论 + 上传 |
| D10 | bug 修复 + 补充测试 | bug 修复 + 样式打磨 |

---

## 8. 测试要点

### 8.1 后端单元测试

| 模块 | 测试项 |
|------|--------|
| SearchService | 正常搜索、空结果、过滤条件组合、分页边界、高亮 |
| EsSyncService | 双写成功/失败、重试逻辑、放弃阈值 |
| ArticleVersionService | 快照创建、版本列表、回滚逻辑、版本号递增 |
| CommentService | 创建评论、嵌套层级限制（正常 + 超限）、软删除展示 |
| UploadService | 图片上传（类型/大小校验）、附件上传、孤儿清理 |

### 8.2 集成测试

| 场景 | 验证点 |
|------|--------|
| 搜索全链路 | 创建文章 → 同步到 ES → 搜索能找到 → 高亮正确 |
| 缓存 | 首次搜索走 ES → 二次走缓存 → 更新文章后缓存被清除 |
| 版本回滚 | 编辑 3 次 → 回滚到 v1 → 内容正确 → 版本号递增 |
| 评论嵌套 | 创建 3 层评论 → 第 4 层被拒 → 软删除第 2 层 → 结构不断裂 |

---

## 9. 性能考量

| 关注点 | 预期 | 措施 |
|--------|------|------|
| ES 搜索延迟 | < 100ms（单节点，万级文档） | 缓存兜底 |
| 双写延迟 | < 50ms（不影响 CRUD 响应） | 事务提交后异步执行 |
| 评论 CTE 查询 | < 50ms（单文章评论 < 500） | depth 限制 3 层，无需深递归 |
| 版本列表 | < 30ms（单文章版本 < 100） | 不分页，全量返回 |
| 文件上传 | 取决于文件大小和网络 | Nginx 50M 限制，MinIO 内网传输 |

---

## 10. 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| IK 分词效果不理想 | 中 | 搜索召回率低 | 提前准备领域词典，迭代补充 |
| ES 双写数据不一致 | 低 | 搜索结果过期 | 重试机制兜底，P2 引入 Canal |
| Markdown 转纯文本丢失信息 | 低 | 索引内容不完整 | 用成熟库（commonmark-java），保留原文在 PG |
| 评论嵌套性能问题 | 低 | 深层评论加载慢 | 3 层硬限制 + 前端懒加载 |

---

## 附录：审查修订记录（v1 → v2）

| # | 级别 | 问题 | 处理方案 |
|---|------|------|---------|
| 1 | P0 | 缓存清除用 `KEYS` 命令（O(N) 全库扫描） | 改为 `SCAN` + `DEL`，代码量几乎不变 |
| 2 | P0 | 全量同步接口缺幂等/安全设计 | 新增分布式锁（Redis SETNX）+ 断点续传（cursor）+ 进度反馈 |
| 3 | P0 | `@TransactionalEventListener` 异常处理未明确 | sync 方法完整 try-catch，异常只落 `es_sync_fail_log`，绝不向上抛；落日志失败也 try-catch |
| 4 | P0 | 评论 `calculateDepth()` 递归查 parent 效率低 | `kb_comment` 新增 `depth` 冗余字段，DDL 走 `V3__p1_comment_depth.sql` |
| 5 | P1 | 搜索建议 input 拆分策略未定义 | P1 只用标题全称，关键短语拆分放 P2 |
| 6 | P1 | `fuzziness: AUTO` 在中文 IK 场景不可预测 | P1 移除 fuzziness，英文拼写容错放 P2 |
| 7 | P1 | 附件删除 MinIO 失败未处理 | 明确删除顺序：先 MinIO 后 DB，MinIO 失败则不删 DB |
| 8 | P1 | 版本回滚缺并发控制 | update 和 restore 均加乐观锁（version WHERE 条件），冲突时抛 VERSION_CONFLICT |
| 9 | P1 | Markdown 转纯文本说 CommonMark 或正则 | 锁定用 `commonmark-java` AST 解析，明确禁止正则 |
| 10 | P1 | 13 个任务全 Cody 负责工期风险高 | 已标注，由 Luke 根据实际人力安排 |
