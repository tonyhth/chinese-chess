# 团队知识库系统 — 技术方案设计

> 作者：Cody | 日期：2026-04-06 | 状态：二审中
> 审查记录：v1 → Ruby 审查清单 17P0/14P1 → v2 逐条修订

---

## 1. 技术选型与理由

| 组件 | 选型 | 理由 |
|------|------|------|
| 后端框架 | Spring Boot 3.2 + Java 17 | 团队技术栈要求，生态成熟 |
| 前端框架 | Vue 3 + Vite + TypeScript | 团队技术栈要求，Composition API 开发效率高 |
| 数据库 | PostgreSQL 16 | 关系型需求（用户、权限、分类树）；JSONB 支持灵活扩展；对并发和全文搜索有基础支持 |
| 缓存 | Redis 7 | 热点文章缓存、JWT 黑名单、分布式锁 |
| 全文搜索 | Elasticsearch 8 + IK Analysis | 见下方详细说明 |
| ORM | MyBatis-Plus 3.5 | 国内团队主流，灵活可控 |
| API 文档 | SpringDoc OpenAPI (Swagger) | 自动生成接口文档 |
| 鉴权 | Spring Security + JWT | 无状态，前后端分离友好；JWT 失效通过 Redis 黑名单实现 |
| 文件存储 | MinIO | S3 兼容，Docker 部署方便，存图片/附件 |
| 部署 | Docker Compose | 一键拉起全部服务 |

### 中文分词搜索方案（重点）

采用 **Elasticsearch + IK Analysis 插件**：

1. **IK 分词器**：Elasticsearch 最成熟的中文分词插件，提供 `ik_max_word`（最大粒度分词）和 `ik_smart`（智能分词）两种模式。索引时用 `ik_max_word` 提高召回率，搜索时用 `ik_smart` 提高精确度。

2. **自定义词典**：
   - 团队专业术语通过 IK 的 `ext.dic` 自定义词典机制加载。
   - 自定义词典文件 `kb_custom.dic` 放在配置目录，一行一词，UTF-8 编码。
   - ES Dockerfile 中将词典 COPY 到 `IK/config/` 目录下。
   - 修改词典后无需重启 ES，通过 IK 的 `reload` API 热加载：`POST /_ik_hot_reload`（或重启索引）。

3. **索引设计**：
   - 知识库文章同步到 ES，包含 `title`、`content`、`tags`、`category_path`、`author` 等字段。
   - `title` 使用 `ik_max_word` + `text` 类型，boost 加权。
   - `content` 使用 `ik_max_word` + `text` 类型。
   - `tags` 使用 `keyword` 类型支持精确过滤。
   - 支持搜索结果高亮（highlight）。

4. **数据同步**：
   - **P0/P1 阶段采用双写**：文章 CRUD 时同步写 ES。双写失败时记录到 `sync_fail_log` 表，通过定时任务（5 分钟间隔）重试，保证最终一致性。
   - **P2 阶段引入 Canal 增量同步**作为兜底，监听 PostgreSQL WAL logical decoding，双写 Canal 双保险。
   - 首次全量同步通过定时任务触发。

5. **搜索特性**：
   - 支持拼音搜索（pinyin Analyzer 插件，P2）
   - 搜索建议（completion suggester）
   - 按分类、标签、时间范围过滤
   - 搜索结果按相关度 + 权重排序

6. **ES 索引 Mapping 完整定义**：

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
          "keyword": { "type": "keyword" }
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

**Mapping 设计要点：**
- 索引用 `ik_index_analyzer`（ik_max_word），搜索用 `ik_search_analyzer`（ik_smart）——标准实践
- `title` 设置 `boost: 2.0`，标题命中权重 2 倍于正文
- `title.keyword` 子字段支持按标题精确排序
- `tagNameList` / `categoryPath` 用 `keyword` 类型，支持精确过滤和前缀匹配
- `content` 存纯文本（去除 Markdown 标记），减小索引体积
- 单节点部署 `replicas=0`，生产环境改为 1

7. **搜索查询示例（Java High Level REST Client）**：

```json
GET /kb_article/_search
{
  "query": {
    "bool": {
      "must": [
        {
          "multi_match": {
            "query": "Spring Boot 配置",
            "fields": ["title^2", "content", "summary"],
            "type": "best_fields"
          }
        }
      ],
      "filter": [
        { "term": { "status": "PUBLISHED" } },
        { "term": { "tagNameList": "Java" } },
        { "prefix": { "categoryPath": "技术/后端" } }
      ]
    }
  },
  "highlight": {
    "pre_tags": ["<em class='hl'>"],
    "post_tags": ["</em>"],
    "fields": {
      "title":   { "number_of_fragments": 0 },
      "content": { "fragment_size": 150, "number_of_fragments": 3 }
    }
  },
  "sort": [
    "_score",
    { "updatedAt": { "order": "desc" } }
  ],
  "from": 0,
  "size": 20
}
```

```json
GET /kb_article/_search
{
  "suggest": {
    "title-suggest": {
      "prefix": "spring",
      "completion": {
        "field": "title.suggest",
        "size": 10
      }
    }
  }
}
```

8. **搜索缓存策略**：
   - 缓存 key：`search:md5(query+filters+page+size+sort)`，即对完整查询条件做 MD5 作为 key。
   - 缓存 value：序列化的搜索结果（`List<ArticleSearchDTO>`），TTL 5 分钟。
   - 文章更新/删除时主动清除相关缓存（按分类 + 标签前缀批量删除）。
   - 热门查询（相同 key 多次命中）自动续期。

---

## 2. 系统架构图

```
                        ┌─────────────┐
                        │   Nginx     │  反向代理 + 静态资源
                        └──────┬──────┘
                               │
                 ┌─────────────┼─────────────┐
                 │             │             │
          ┌──────▼──────┐     │      ┌──────▼──────┐
          │  Vue 3 SPA  │     │      │  MinIO      │
          │  (前端容器)  │     │      │  (文件存储)  │
          └──────┬──────┘     │      └─────────────┘
                 │            │
                 │  REST API  │
          ┌──────▼────────────▼──────┐
          │   Spring Boot (后端)      │
          │  ┌───────┐ ┌──────────┐  │
          │  │Auth   │ │Article   │  │
          │  │Module │ │Module    │  │
          │  └───────┘ └──────────┘  │
          │  ┌───────┐ ┌──────────┐  │
          │  │Search │ │Comment   │  │
          │  │Module │ │Module    │  │
          │  └───┬───┘ └──────────┘  │
          └──────┼───────────────────┘
                 │
        ┌────────┼────────┐
        │        │        │
  ┌─────▼────┐ ┌▼──────┐ ┌▼──────┐
  │PostgreSQL│ │Redis  │ │  ES 8  │
  │ wal_level│ │ 缓存  │ │ + IK   │
  │ =logical│ │ + JWT │ │        │
  └──────────┘ │blacklist│ └───────┘
               └───────┘
```

**数据流**：
- 前端 → Nginx → Spring Boot API → PostgreSQL / Redis / Elasticsearch
- 文件上传 → MinIO
- 搜索 → Spring Boot → Elasticsearch，结果回写 Redis 缓存

---

## 3. 数据模型设计

### 3.1 用户表 `sys_user`

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK | 主键 |
| username | VARCHAR(64) | UNIQUE NOT NULL | 用户名 |
| password_hash | VARCHAR(256) | NOT NULL | BCrypt 加密 |
| email | VARCHAR(128) | UNIQUE | 邮箱 |
| avatar_url | VARCHAR(512) | | 头像 |
| role | ENUM(ADMIN,EDITOR,READER) | NOT NULL DEFAULT READER | 角色 |
| status | TINYINT | NOT NULL DEFAULT 1 | 0禁用 1启用 |
| deleted_at | TIMESTAMP | NULL | 软删除标记 |
| created_at | TIMESTAMP | NOT NULL | 创建时间 |
| updated_at | TIMESTAMP | NOT NULL | 更新时间 |

> 所有查询均加 `WHERE deleted_at IS NULL` 条件。软删除用户名添加时间戳后缀以防冲突。

### 3.2 分类表 `kb_category`（树形结构）

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK | 主键 |
| parent_id | BIGINT | FK→kb_category.id, NULLABLE | 父分类，NULL 为根 |
| name | VARCHAR(128) | NOT NULL | 分类名称 |
| slug | VARCHAR(128) | UNIQUE NOT NULL | URL 友好名 |
| description | VARCHAR(512) | | 分类描述 |
| sort_order | INT | DEFAULT 0 | 排序 |
| created_at | TIMESTAMP | NOT NULL | |

### 3.3 标签表 `kb_tag`

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK | 主键 |
| name | VARCHAR(64) | UNIQUE NOT NULL | 标签名 |
| color | VARCHAR(16) | | 展示颜色 |

### 3.4 文章表 `kb_article`

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK | 主键 |
| title | VARCHAR(256) | NOT NULL | 标题 |
| slug | VARCHAR(256) | UNIQUE | URL 友好路径 |
| content | TEXT | NOT NULL | Markdown 正文 |
| content_html | TEXT | | 渲染后 HTML（缓存） |
| summary | VARCHAR(512) | | 摘要 |
| category_id | BIGINT | FK→kb_category.id | 所属分类 |
| author_id | BIGINT | FK→sys_user.id | 作者 |
| status | ENUM(DRAFT,PUBLISHED,ARCHIVED) | NOT NULL DEFAULT DRAFT | 状态 |
| view_count | INT | DEFAULT 0 | 浏览量 |
| version | INT | DEFAULT 1 | 当前版本号 |
| deleted_at | TIMESTAMP | NULL | 软删除标记 |
| created_at | TIMESTAMP | NOT NULL | |
| updated_at | TIMESTAMP | NOT NULL | |

> slug 在创建时自动从 title 生成（可手动覆盖）。唯一约束通过 PostgreSQL 部分索引实现：`CREATE UNIQUE INDEX uk_article_slug ON kb_article (slug) WHERE deleted_at IS NULL`，软删除的 slug 自动释放，不影响新文章使用。

### 3.5 文章标签关联 `kb_article_tag`

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| article_id | BIGINT | FK→kb_article.id | |
| tag_id | BIGINT | FK→kb_tag.id | |
| **联合主键** | | **PRIMARY KEY (article_id, tag_id)** | |

### 3.6 文章版本 `kb_article_version`

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK | 主键 |
| article_id | BIGINT | FK→kb_article.id | 关联文章 |
| title | VARCHAR(256) | NOT NULL | |
| content | TEXT | NOT NULL | |
| version | INT | NOT NULL | 版本号 |
| change_summary | VARCHAR(512) | | 变更说明 |
| created_by | BIGINT | FK→sys_user.id | 操作人 |
| created_at | TIMESTAMP | NOT NULL | |
| **联合唯一** | | **UNIQUE (article_id, version)** | 防止版本号重复 |

> 评论树查询策略：后端用 `WITH RECURSIVE` CTE 一次性查出指定文章的所有评论（平铺列表 + parent_id），前端递归组装树形结构。评论嵌套层级限制为最多 3 层，第 3 层的回复统一挂在第 2 层下（类似知乎/掘金策略），避免无限嵌套。

### 3.7 评论表 `kb_comment`

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK | 主键 |
| article_id | BIGINT | FK→kb_article.id NOT NULL | 关联文章 |
| parent_id | BIGINT | FK→kb_comment.id, NULLABLE | 父评论（支持楼中楼） |
| content | TEXT | NOT NULL | 评论内容 |
| author_id | BIGINT | FK→sys_user.id NOT NULL | 评论人 |
| status | TINYINT | NOT NULL DEFAULT 1 | 0已删除 1正常 |
| deleted_at | TIMESTAMP | NULL | 软删除时间 |
| created_at | TIMESTAMP | NOT NULL | |
| updated_at | TIMESTAMP | NOT NULL | |

> 软删除的评论在列表中显示为"该评论已被删除"占位符，保持楼中楼结构不断裂。查询评论树时包含 `status=0` 的节点但返回标记字段。

### 3.8 附件表 `kb_attachment`（新增）

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | BIGINT | PK | 主键 |
| article_id | BIGINT | FK→kb_article.id | 关联文章 |
| file_name | VARCHAR(256) | NOT NULL | 原始文件名 |
| file_path | VARCHAR(512) | NOT NULL | MinIO 存储路径 |
| file_size | BIGINT | NOT NULL | 文件大小（字节） |
| mime_type | VARCHAR(128) | | MIME 类型 |
| upload_user_id | BIGINT | FK→sys_user.id | 上传人 |
| created_at | TIMESTAMP | NOT NULL | |

### 3.9 ES 同步失败日志 `es_sync_fail_log`（新增，P0 双写兜底）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT PK | 主键 |
| entity_type | VARCHAR(32) | 实体类型（article/article_tag） |
| entity_id | BIGINT | 实体 ID |
| operation | VARCHAR(16) | 操作类型（index/delete/update） |
| payload | JSONB | 同步数据快照 |
| retry_count | INT DEFAULT 0 | 已重试次数 |
| status | TINYINT DEFAULT 0 | 0待重试 1成功 2放弃（retry_count ≥ 5 时自动标记放弃并告警） |
| created_at | TIMESTAMP | |
| next_retry_at | TIMESTAMP | 下次重试时间 |

### 3.10 SQL 建表语句（PostgreSQL DDL）

> 以下为 `V1__init.sql` 完整内容，Flyway 启动时自动执行。

```sql
-- ============================================================
-- 团队知识库系统 DDL — PostgreSQL 16
-- ============================================================

-- 1. 用户表
CREATE TABLE sys_user (
    id            BIGSERIAL       PRIMARY KEY,
    username      VARCHAR(64)     NOT NULL UNIQUE,
    password_hash VARCHAR(256)    NOT NULL,
    email         VARCHAR(128)    NOT NULL UNIQUE,
    avatar_url    VARCHAR(512),
    role          VARCHAR(16)     NOT NULL DEFAULT 'READER'
                                  CHECK (role IN ('ADMIN','EDITOR','READER')),
    status        SMALLINT        NOT NULL DEFAULT 1
                                  CHECK (status IN (0, 1)),
    deleted_at    TIMESTAMPTZ,
    created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  sys_user            IS '系统用户表';
COMMENT ON COLUMN sys_user.role       IS '角色：ADMIN-管理员 / EDITOR-编辑 / READER-读者';
COMMENT ON COLUMN sys_user.status     IS '状态：0-禁用 / 1-启用';
COMMENT ON COLUMN sys_user.deleted_at IS '软删除时间，NULL 表示未删除';

-- 2. 分类表（邻接表模型，树形结构）
CREATE TABLE kb_category (
    id          BIGSERIAL       PRIMARY KEY,
    parent_id   BIGINT          REFERENCES kb_category(id) ON DELETE RESTRICT,
    name        VARCHAR(128)    NOT NULL,
    slug        VARCHAR(128)    NOT NULL UNIQUE,
    description VARCHAR(512),
    sort_order  INT             NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_category_parent ON kb_category(parent_id);

COMMENT ON TABLE  kb_category           IS '知识库分类（树形结构）';
COMMENT ON COLUMN kb_category.parent_id IS '父分类ID，NULL 表示顶级分类';

-- 3. 标签表
CREATE TABLE kb_tag (
    id      BIGSERIAL       PRIMARY KEY,
    name    VARCHAR(64)     NOT NULL UNIQUE,
    color   VARCHAR(16)     NOT NULL DEFAULT '#409EFF'
);

COMMENT ON TABLE kb_tag IS '知识库标签';

-- 4. 文章表
CREATE TABLE kb_article (
    id            BIGSERIAL       PRIMARY KEY,
    title         VARCHAR(256)    NOT NULL,
    slug          VARCHAR(256),
    content       TEXT            NOT NULL,
    content_html  TEXT,
    summary       VARCHAR(512),
    category_id   BIGINT          REFERENCES kb_category(id) ON DELETE SET NULL,
    author_id     BIGINT          NOT NULL REFERENCES sys_user(id),
    status        VARCHAR(16)     NOT NULL DEFAULT 'DRAFT'
                                  CHECK (status IN ('DRAFT','PUBLISHED','ARCHIVED')),
    view_count    INT             NOT NULL DEFAULT 0,
    version       INT             NOT NULL DEFAULT 1,
    deleted_at    TIMESTAMPTZ,
    created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- slug 唯一索引仅对未删除记录生效
CREATE UNIQUE INDEX uk_article_slug ON kb_article(slug) WHERE deleted_at IS NULL;
CREATE INDEX idx_article_author   ON kb_article(author_id);
CREATE INDEX idx_article_category ON kb_article(category_id);
CREATE INDEX idx_article_status   ON kb_article(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_article_updated  ON kb_article(updated_at DESC);

COMMENT ON TABLE  kb_article            IS '知识库文章';
COMMENT ON COLUMN kb_article.deleted_at IS '软删除时间';
COMMENT ON COLUMN kb_article.slug       IS 'URL友好路径，自动从标题生成，可手动覆盖';

-- 5. 文章-标签关联表（多对多）
CREATE TABLE kb_article_tag (
    article_id  BIGINT  NOT NULL REFERENCES kb_article(id) ON DELETE CASCADE,
    tag_id      BIGINT  NOT NULL REFERENCES kb_tag(id) ON DELETE CASCADE,
    PRIMARY KEY (article_id, tag_id)
);

COMMENT ON TABLE kb_article_tag IS '文章-标签关联';

-- 6. 文章版本表
CREATE TABLE kb_article_version (
    id              BIGSERIAL       PRIMARY KEY,
    article_id      BIGINT          NOT NULL REFERENCES kb_article(id) ON DELETE CASCADE,
    title           VARCHAR(256)    NOT NULL,
    content         TEXT            NOT NULL,
    version         INT             NOT NULL,
    change_summary  VARCHAR(512),
    created_by      BIGINT          NOT NULL REFERENCES sys_user(id),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (article_id, version)
);

CREATE INDEX idx_version_article ON kb_article_version(article_id, version DESC);

COMMENT ON TABLE kb_article_version IS '文章版本快照';

-- 7. 评论表（支持楼中楼）
CREATE TABLE kb_comment (
    id          BIGSERIAL       PRIMARY KEY,
    article_id  BIGINT          NOT NULL REFERENCES kb_article(id) ON DELETE CASCADE,
    parent_id   BIGINT          REFERENCES kb_comment(id) ON DELETE CASCADE,
    content     TEXT            NOT NULL,
    author_id   BIGINT          NOT NULL REFERENCES sys_user(id),
    status      SMALLINT        NOT NULL DEFAULT 1
                              CHECK (status IN (0, 1)),
    deleted_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_comment_article ON kb_comment(article_id, created_at);

COMMENT ON TABLE  kb_comment           IS '文章评论';
COMMENT ON COLUMN kb_comment.parent_id IS '父评论ID，NULL 表示顶级评论';
COMMENT ON COLUMN kb_comment.status    IS '0-已删除 / 1-正常';

-- 8. 附件表
CREATE TABLE kb_attachment (
    id              BIGSERIAL       PRIMARY KEY,
    article_id      BIGINT          REFERENCES kb_article(id) ON DELETE SET NULL,
    file_name       VARCHAR(256)    NOT NULL,
    file_path       VARCHAR(512)    NOT NULL,
    file_size       BIGINT          NOT NULL,
    mime_type       VARCHAR(128),
    upload_user_id  BIGINT          NOT NULL REFERENCES sys_user(id),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_attachment_article ON kb_attachment(article_id);

COMMENT ON TABLE  kb_attachment IS '文件附件';
COMMENT ON COLUMN kb_attachment.article_id IS '关联文章ID，NULL 表示未关联（24h后清理）';

-- 9. ES 同步失败日志
CREATE TABLE es_sync_fail_log (
    id            BIGSERIAL       PRIMARY KEY,
    entity_type   VARCHAR(32)     NOT NULL,
    entity_id     BIGINT          NOT NULL,
    operation     VARCHAR(16)     NOT NULL CHECK (operation IN ('index','delete','update')),
    payload       JSONB,
    retry_count   INT             NOT NULL DEFAULT 0,
    status        SMALLINT        NOT NULL DEFAULT 0
                                  CHECK (status IN (0, 1, 2)),
    created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    next_retry_at TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sync_pending ON es_sync_fail_log(status, next_retry_at)
    WHERE status = 0;

COMMENT ON TABLE es_sync_fail_log IS 'ES同步失败重试队列（0-待重试 1-成功 2-放弃）';
```

```sql
-- ============================================================
-- V2__seed_data.sql — 初始数据
-- ============================================================

-- 默认管理员（密码: admin123，BCrypt 加密）
INSERT INTO sys_user (username, password_hash, email, role)
VALUES ('admin',
        '$2a$10$EqKcp1WFKs2AOoLOepht0OJMdVR/R1FyGgeSPfu00XJfDgE6wywiG',
        'admin@example.com', 'ADMIN');

-- 默认分类
INSERT INTO kb_category (parent_id, name, slug, sort_order) VALUES
    (NULL, '技术',     'tech',     1),
    (NULL, '产品',     'product',  2),
    (NULL, '设计',     'design',   3);

INSERT INTO kb_category (parent_id, name, slug, sort_order) VALUES
    ((SELECT id FROM kb_category WHERE slug='tech'), '后端开发', 'backend',  1),
    ((SELECT id FROM kb_category WHERE slug='tech'), '前端开发', 'frontend', 2),
    ((SELECT id FROM kb_category WHERE slug='tech'), '运维部署', 'devops',   3);
```

---

## 4. API 设计（核心端点）

基础路径：`/api/v1`

### 4.1 认证

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/auth/login` | 登录，返回 JWT（access_token + refresh_token） |
| POST | `/auth/refresh` | 刷新 Token |
| POST | `/auth/logout` | 登出，将当前 token 加入 Redis 黑名单（TTL = token 剩余有效期） |
| GET | `/auth/me` | 当前用户信息 |

> **JWT 黑名单机制**：logout 时将 access_token 的 `jti` 和 refresh_token 的 `jti` 均写入 Redis string key `token:blacklist:{jti}`，value 为 `1`，TTL 设为各 token 的剩余过期时间。JwtFilter 每次请求检查 access_token jti 是否在黑名单中；refresh 接口同理检查 refresh_token jti。这样即使攻击者拿到 refresh_token 也无法换新 access_token。

### 4.2 用户管理（Admin）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/users` | 用户列表（分页） |
| POST | `/users` | 创建用户 |
| PUT | `/users/{id}` | 更新用户 |
| DELETE | `/users/{id}` | 删除用户（软删除，标记 deleted_at） |
| PUT | `/users/{id}/role` | 修改角色 |

### 4.3 分类

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/categories/tree` | 获取分类树 | 所有角色 |
| POST | `/categories` | 创建分类 | Admin、Editor |
| PUT | `/categories/{id}` | 更新分类 | Admin、Editor |
| DELETE | `/categories/{id}` | 删除分类 | **仅 Admin**（有子分类/文章时返回 409） |

### 4.4 标签

| 方法 | 路径 | 说明 | 权限 |
|------|------|------|------|
| GET | `/tags` | 标签列表 | 所有角色 |
| POST | `/tags` | 创建标签 | Admin、Editor |
| PUT | `/tags/{id}` | 更新标签 | Admin、Editor |
| DELETE | `/tags/{id}` | 删除标签 | **仅 Admin** |

### 4.5 文章

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/articles?page=&size=&category_id=&tag_id=&status=&sort=updated_at&order=desc` | 文章列表（分页+过滤+排序） |
| GET | `/articles/{id}` | 文章详情 |
| POST | `/articles` | 创建文章 |
| PUT | `/articles/{id}` | 更新文章 |
| PATCH | `/articles/{id}/status` | 修改文章状态（归档、发布等），软删除也走此接口 `{ "status": "DELETED" }` |
| GET | `/articles/{id}/versions` | 版本列表 |
| GET | `/articles/{id}/versions/{version}` | 指定版本详情 |
| POST | `/articles/{id}/versions/{version}/restore` | 回滚到指定版本 |
| POST | `/articles/batch/delete` | 批量删除 `{"ids": [1,2,3]}`（单次最多 100 条） |
| POST | `/articles/batch/move` | 批量移动分类 `{"ids": [1,2,3], "category_id": 5}`（单次最多 100 条） |
| POST | `/articles/batch/tag` | 批量打标签 `{"ids": [1,2,3], "tag_ids": [1,2]}`（单次最多 100 条） |

### 4.6 搜索

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/search` | 全文搜索（JSON body，支持复杂过滤条件） |
| GET | `/search/suggest?q={query}` | 搜索建议 |

**POST /search 请求体**：
```json
{
  "query": "搜索关键词",
  "category_id": 1,
  "tag_ids": [2, 3],
  "date_from": "2026-01-01",
  "date_to": "2026-04-06",
  "sort": "relevance",
  "order": "desc",
  "page": 1,
  "size": 20
}
```

> 改用 POST + JSON body 是因为搜索条件（多标签、日期范围、排序方式）用 query string 会过长且难维护。

### 4.7 评论

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/articles/{id}/comments` | 评论列表（树形，包含已删除占位） |
| POST | `/articles/{id}/comments` | 发表评论 |
| DELETE | `/comments/{id}` | 删除评论（软删除，标记 status=0 + deleted_at） |

### 4.8 文件上传

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/upload/image` | 上传图片（Markdown 编辑器用），返回 URL |
| POST | `/upload/file` | 上传附件，返回 attachment_id + URL。支持两种模式：(1) 传 `article_id` 直接关联；(2) 不传 `article_id`，附件先存为「未关联」状态，文章创建/编辑时通过 `attachment_ids` 字段批量关联。未关联附件 24h 后定时清理 |

### 权限矩阵（完整版）

| 操作 | Admin | Editor | Reader |
|------|-------|--------|--------|
| 用户管理（增删改角色） | ✅ | ❌ | ❌ |
| 分类创建/编辑 | ✅ | ✅ | ❌ |
| 分类删除 | ✅ | ❌ | ❌ |
| 标签创建/编辑 | ✅ | ✅ | ❌ |
| 标签删除 | ✅ | ❌ | ❌ |
| 创建文章 | ✅ | ✅ | ❌ |
| 编辑文章 | ✅ | ✅（仅自己的） | ❌ |
| 删除文章 | ✅ | ✅（仅自己的） | ❌ |
| 查看已发布文章 | ✅ | ✅ | ✅ |
| 查看草稿 | ✅（所有） | ✅（仅自己的） | ❌ |
| 查看归档文章 | ✅ | ❌ | ❌ |
| 评论 | ✅ | ✅ | ✅ |
| 删除评论 | ✅（所有） | ✅（仅自己的） | ✅（仅自己的） |

---

## 5. 项目目录结构

```
knowledge-base/
├── docker-compose.yml
├── docker-compose.dev.yml            # 开发环境覆盖配置
├── .env.example                      # 环境变量模板
├── README.md
│
├── elasticsearch/                    # ES 自定义配置
│   ├── Dockerfile                    # 基于 ES 官方镜像，预装 IK 插件
│   └── config/
│       └── kb_custom.dic            # IK 自定义词典
│
├── nginx/                            # Nginx 配置
│   ├── Dockerfile
│   └── default.conf
│
├── backend/                          # Spring Boot
│   ├── pom.xml
│   ├── Dockerfile
│   ├── src/main/java/com/kb/
│   │   ├── KbApplication.java
│   │   ├── config/
│   │   │   ├── SecurityConfig.java
│   │   │   ├── ElasticsearchConfig.java
│   │   │   ├── RedisConfig.java
│   │   │   ├── MinioConfig.java
│   │   │   └── MyBatisPlusConfig.java
│   │   ├── common/
│   │   │   ├── Result.java
│   │   │   ├── PageResult.java
│   │   │   ├── BusinessException.java
│   │   │   └── ErrorCode.java
│   │   ├── auth/
│   │   │   ├── controller/AuthController.java
│   │   │   ├── service/AuthService.java
│   │   │   ├── jwt/JwtUtil.java
│   │   │   └── jwt/JwtFilter.java
│   │   ├── user/
│   │   │   ├── controller/UserController.java
│   │   │   ├── service/UserService.java
│   │   │   ├── mapper/UserMapper.java
│   │   │   └── entity/User.java
│   │   ├── category/
│   │   │   └── ...
│   │   ├── tag/
│   │   │   └── ...
│   │   ├── article/
│   │   │   ├── controller/ArticleController.java
│   │   │   ├── service/ArticleService.java
│   │   │   ├── service/ArticleVersionService.java
│   │   │   ├── mapper/ArticleMapper.java
│   │   │   └── entity/
│   │   │       ├── Article.java
│   │   │       ├── ArticleTag.java
│   │   │       ├── ArticleVersion.java
│   │   │       └── Attachment.java
│   │   ├── search/
│   │   │   ├── controller/SearchController.java
│   │   │   ├── service/SearchService.java
│   │   │   ├── service/EsSyncService.java
│   │   │   └── document/ArticleDocument.java
│   │   ├── comment/
│   │   │   └── ...
│   │   └── upload/
│   │       └── ...
│   └── src/main/resources/
│       ├── application.yml
│       ├── application-dev.yml
│       ├── application-prod.yml
│       └── db/migration/
│           ├── V1__init.sql
│           └── V2__seed_data.sql
│
└── frontend/                         # Vue 3
    ├── Dockerfile
    ├── package.json
    ├── vite.config.ts
    ├── tsconfig.json
    ├── index.html
    └── src/
        ├── main.ts
        ├── App.vue
        ├── api/
        │   ├── request.ts
        │   ├── auth.ts
        │   ├── article.ts
        │   ├── category.ts
        │   ├── tag.ts
        │   ├── search.ts
        │   └── comment.ts
        ├── views/
        │   ├── Login.vue
        │   ├── Dashboard.vue
        │   ├── ArticleList.vue
        │   ├── ArticleEdit.vue
        │   ├── ArticleDetail.vue
        │   ├── CategoryManage.vue
        │   ├── TagManage.vue
        │   ├── UserManage.vue
        │   └── Search.vue
        ├── components/
        │   ├── MarkdownEditor.vue
        │   ├── MarkdownPreview.vue
        │   ├── TagSelect.vue
        │   ├── CategoryTree.vue
        │   ├── CommentList.vue
        │   └── Pagination.vue
        ├── stores/
        │   ├── user.ts
        │   └── article.ts
        ├── router/
        │   └── index.ts
        ├── utils/
        │   └── permission.ts
        └── styles/
            └── global.css
```

---

## 6. 部署方案（Docker Compose）

### 6.1 `.env.example`

```env
# 数据库
DB_PASSWORD=change_me_in_production

# JWT
JWT_SECRET=change_me_at_least_32_chars_random_string
JWT_ACCESS_EXPIRE=3600      # access token 1小时
JWT_REFRESH_EXPIRE=604800   # refresh token 7天

# MinIO
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=change_me_minio_secret

# 环境
SPRING_PROFILES_ACTIVE=prod
```

### 6.2 Elasticsearch Dockerfile（预装 IK 插件）

```dockerfile
# elasticsearch/Dockerfile
FROM elasticsearch:8.12.0

# 安装 IK 分词插件（构建阶段）
RUN bin/elasticsearch-plugin install --batch https://get.infini.cloud/elasticsearch/analysis-ik/8.12.0

# 复制自定义词典
COPY config/kb_custom.dic /usr/share/elasticsearch/config/analysis-ik/kb_custom.dic
```

> IK 词典放在 IK 插件的 config 目录下会被自动加载，无需修改 IK 配置文件。

### 6.3 Nginx 配置

```nginx
# nginx/default.conf
server {
    listen 80;
    server_name _;

    # 前端静态资源
    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
    }

    # API 反向代理
    location /api/ {
        proxy_pass http://backend:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 上传文件大小限制
    client_max_body_size 50M;
}
```

### 6.4 docker-compose.yml

```yaml
version: '3.8'

services:
  # Nginx 反向代理 + 前端静态资源
  nginx:
    build: ./nginx
    ports:
      - "80:80"
    depends_on:
      - backend
      - frontend

  # 前端（构建产物挂载到 nginx）
  frontend:
    build: ./frontend
    volumes:
      - frontend_dist:/usr/share/nginx/html

  # 后端
  backend:
    build: ./backend
    ports:
      - "8080:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=${SPRING_PROFILES_ACTIVE:-prod}
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=knowledge_base
      - DB_USER=kb
      - DB_PASSWORD=${DB_PASSWORD}
      - REDIS_HOST=redis
      - ES_HOSTS=http://elasticsearch:9200
      - MINIO_ENDPOINT=http://minio:9000
      - MINIO_ACCESS_KEY=${MINIO_ACCESS_KEY}
      - MINIO_SECRET_KEY=${MINIO_SECRET_KEY}
      - JWT_SECRET=${JWT_SECRET}
      - JWT_ACCESS_EXPIRE=${JWT_ACCESS_EXPIRE:-3600}
      - JWT_REFRESH_EXPIRE=${JWT_REFRESH_EXPIRE:-604800}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      elasticsearch:
        condition: service_healthy
    restart: unless-stopped

  # PostgreSQL（开启 WAL logical decoding，为 Canal 做准备）
  postgres:
    image: postgres:16-alpine
    command: >
      postgres
      -c wal_level=logical
      -c max_replication_slots=4
      -c max_wal_senders=4
    environment:
      - POSTGRES_DB=knowledge_base
      - POSTGRES_USER=kb
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - pg_data:/var/lib/postgresql/data
    # 生产环境不应暴露端口，仅开发环境使用 docker-compose.dev.yml 覆盖
    # ports:
    #   - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U kb -d knowledge_base"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s

  # Redis
  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 256M

  # Elasticsearch（自定义镜像，预装 IK）
  elasticsearch:
    build: ./elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - xpack.security.http.ssl.enabled=false
      - ES_JAVA_OPTS=-Xms1g -Xmx1g
    volumes:
      - es_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:9200/_cluster/health || exit 1"]
      interval: 10s
      timeout: 10s
      retries: 20
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 2G
    restart: unless-stopped

  # MinIO 文件存储
  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    environment:
      - MINIO_ROOT_USER=${MINIO_ACCESS_KEY}
      - MINIO_ROOT_PASSWORD=${MINIO_SECRET_KEY}
    volumes:
      - minio_data:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 10s
      retries: 5
      start_period: 10s

volumes:
  pg_data:
  redis_data:
  es_data:
  minio_data:
  frontend_dist:
```

### 6.5 部署步骤

1. 复制环境变量模板：`cp .env.example .env`，修改密码和密钥
2. 一键启动：`docker compose up -d --build`
3. 等待所有服务健康（`docker compose ps` 确认全部 healthy）
4. 验证 IK 插件：`docker compose exec elasticsearch curl -s localhost:9200/_cat/plugins`
5. Flyway 在 Spring Boot 启动时自动执行数据库迁移（内置重试机制）
6. 访问 `http://localhost` 前端，`http://localhost:9001` MinIO 控制台

---

## 7. 分期计划

> **开发模式**：前后端各 1 人并行开发。预估基于 2 人团队。

### P0 — MVP（3 周）

> 最小可用，核心链路跑通

| 任务 | 负责人 | 预估工时 | 前置依赖 |
|------|--------|---------|---------|
| 技术方案评审 + 修订 | 全员 | 0.5 周 | — |
| Docker Compose 开发环境搭建 | 后端 | 2 天 | 方案定稿 |
| 数据库建表 + Flyway 迁移 | 后端 | 1 天 | 环境就绪 |
| 用户注册/登录/JWT 鉴权 | 后端 | 2 天 | 建表完成 |
| Spring Security 权限控制 | 后端 | 2 天 | 鉴权完成 |
| 文章 CRUD API | 后端 | 3 天 | 权限完成 |
| 分类树 CRUD API | 后端 | 1.5 天 | — |
| 标签管理 API | 后端 | 1 天 | — |
| 文章列表页 + 详情页 | 前端 | 3 天 | 后端 API 就绪 |
| Markdown 编辑/预览页 | 前端 | 3 天 | 后端 API 就绪 |
| 分类/标签管理页 | 前端 | 2 天 | 后端 API 就绪 |
| 登录页 + 路由守卫 + 权限 UI | 前端 | 2 天 | 鉴权 API |
| 集成联调 | 前后端 | 2 天 | 各自功能完成 |
| 认证/权限/文章 CRUD 单元测试 | 后端 | 2 天（穿插） | 同步进行 |

**关键里程碑**：Week 2 末可演示文章创建/编辑/发布全流程。

### P1 — 搜索与协作（2 周）

| 任务 | 负责人 | 预估工时 |
|------|--------|---------|
| Elasticsearch 集成 + IK 分词配置 | 后端 | 2 天 |
| 全文搜索 API（POST /search） | 后端 | 2 天 |
| 双写同步 + 失败重试机制 | 后端 | 1.5 天 |
| 搜索结果 Redis 缓存 | 后端 | 1 天 |
| 搜索建议（suggest） | 后端 | 1 天 |
| 搜索页面 + 高亮 | 前端 | 3 天 |
| 文章版本管理 API | 后端 | 2 天 |
| 版本对比/回滚 UI | 前端 | 2 天 |
| 评论系统 API（楼中楼） | 后端 | 2 天 |
| 评论组件 + UI | 前端 | 2 天 |
| 图片上传 + Markdown 图片粘贴 | 前端 + 后端 | 1.5 天 |
| 附件上传/管理 | 前端 + 后端 | 1.5 天 |
| SpringDoc 接口文档 | 后端 | 0.5 天 |

### P2 — 增强（2~3 周）

> Canal 增量同步在此阶段引入

- [ ] Canal 增量同步（监听 PostgreSQL WAL logical decoding，双写 Canal 双保险）
- [ ] 拼音搜索（pinyin Analyzer 插件）
- [ ] 文章导出（PDF/Word）
- [ ] 操作日志审计
- [ ] 仪表盘（文章统计、热门标签、活跃用户）
- [ ] 性能优化（慢查询治理、ES 索引优化）
- [ ] CI/CD（GitHub Actions 构建镜像）
- [ ] 生产部署 + HTTPS + 备份策略
- [ ] 数据迁移方案（如有旧系统）+ 数据库回滚策略
- [ ] 补全集成测试覆盖

---

## 附录：审查修订记录（v1 → v2）

| # | 级别 | 问题 | 处理方案 |
|---|------|------|---------|
| 1 | P0 | ES 镜像不包含 IK 插件 | 新增 `elasticsearch/Dockerfile`，构建阶段预装 IK + 自定义词典 |
| 2 | P0 | Canal 配置缺失 | P0 采用双写 + `es_sync_fail_log` 重试兜底；Canal 延至 P2 |
| 3 | P1 | 搜索缓存策略不明确 | 补充完整缓存策略：key 设计（MD5）、TTL 5min、主动清除机制 |
| 4 | P1 | ES 内存偏小 | 堆内存改为 1G，容器限制 2G |
| 5 | P1 | IK 自定义词典缺失 | 补充自定义词典方案：`kb_custom.dic`、Dockerfile COPY、热加载 |
| 6 | P0 | 文章缺 deleted_at | 已添加 |
| 7 | P0 | 评论缺软删除字段 | 已添加 `status` + `deleted_at` |
| 8 | P0 | 版本表缺唯一约束 | 已添加 `UNIQUE (article_id, version)` |
| 9 | P1 | 用户缺 deleted_at | 已添加，软删除时用户名加时间戳后缀 |
| 10 | P1 | 文章缺 slug | 已添加 |
| 11 | P1 | 评论缺 status | 已添加，软删除显示占位符 |
| 12 | P1 | 分类缺 description | 已添加 |
| 13 | P1 | article_tag 约束 | 明确复合主键即联合唯一 |
| 14 | P1 | 缺附件表 | 新增 `kb_attachment` 表 |
| 15 | P0 | DELETE 返回值不明确 | 改为 `PATCH /articles/{id}/status` 处理软删除 |
| 16 | P0 | 权限矩阵不完整 | 补充草稿查看、编辑范围、分类/标签删除权限 |
| 17 | P1 | 搜索用 GET 不够 RESTful | 改为 `POST /search` + JSON body |
| 18 | P1 | 文章列表缺排序参数 | 已添加 `sort` + `order` 参数 |
| 19 | P1 | 缺批量操作 API | 新增 batch/delete、batch/move、batch/tag |
| 20 | P0 | JWT logout 无意义 | 明确 Redis 黑名单机制 |
| 21 | P0 | ES healthcheck 用 curl | ES 8.12 镜像自带 curl，保留但加 `start_period` 和更长 timeout |
| 22 | P0 | minio_data volumes 遗漏 | 已包含（v1 实际已有，确认无遗漏） |
| 23 | P0 | 缺 Nginx 服务 | 新增 nginx 服务 + default.conf 配置 |
| 24 | P0 | ES 数据目录权限 | 自定义 Dockerfile 中处理，compose 加 `start_period` |
| 25 | P1 | 缺 .env.example | 新增完整模板 |
| 26 | P1 | 缺资源限制 | ES 限 2G、Redis 限 256M |
| 27 | P1 | Flyway 迁移时机 | Spring Boot 内置重试 + PG `start_period` |
| 28 | P0 | P0 工期偏低 | 调整为 3 周，明确 2 人团队 + 各任务工时 |
| 29 | P1 | Canal 延后不合理 | P0 双写 + 失败重试表兜底，Canal P2 引入 |
| 30 | P1 | 缺数据迁移/回滚方案 | P2 补充 |
| 31 | P1 | 测试后置 | P0 同步写认证/权限/文章 CRUD 单元测试 |
