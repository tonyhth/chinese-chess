-- V1__init.sql
-- 知识库系统核心表结构
-- 适配 Spring Boot 3.2 + MyBatis-Plus

-- ============================================================
-- 1. 用户表 sys_user
-- ============================================================
CREATE TABLE sys_user (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username        VARCHAR(64)  NOT NULL,
    password_hash   VARCHAR(256) NOT NULL,
    email           VARCHAR(128),
    avatar_url      VARCHAR(512),
    role            VARCHAR(16)  NOT NULL DEFAULT 'READER' CHECK (role IN ('ADMIN','EDITOR','READER')),
    status          SMALLINT     NOT NULL DEFAULT 1 CHECK (status IN (0,1)),
    deleted_at      TIMESTAMP,
    created_at      TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX uk_user_username ON sys_user (username) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX uk_user_email ON sys_user (email) WHERE deleted_at IS NULL AND email IS NOT NULL;

COMMENT ON TABLE sys_user IS '用户表';
COMMENT ON COLUMN sys_user.deleted_at IS '软删除标记，非空表示已删除';
COMMENT ON COLUMN sys_user.role IS '角色：ADMIN/EDITOR/READER';

-- ============================================================
-- 2. 分类表 kb_category（树形结构）
-- ============================================================
CREATE TABLE kb_category (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_id       BIGINT REFERENCES kb_category(id) ON DELETE RESTRICT,
    name            VARCHAR(128) NOT NULL,
    slug            VARCHAR(128) NOT NULL,
    description     VARCHAR(512),
    sort_order      INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX uk_category_slug ON kb_category (slug);

COMMENT ON TABLE kb_category IS '文章分类表（树形）';
COMMENT ON COLUMN kb_category.parent_id IS '父分类ID，NULL为根节点';

-- ============================================================
-- 3. 标签表 kb_tag
-- ============================================================
CREATE TABLE kb_tag (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            VARCHAR(64) NOT NULL,
    color           VARCHAR(16)
);

CREATE UNIQUE INDEX uk_tag_name ON kb_tag (name);

COMMENT ON TABLE kb_tag IS '标签表';

-- ============================================================
-- 4. 文章表 kb_article
-- ============================================================
CREATE TABLE kb_article (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title           VARCHAR(256) NOT NULL,
    slug            VARCHAR(256),
    content         TEXT         NOT NULL,
    content_html    TEXT,
    summary         VARCHAR(512),
    category_id     BIGINT REFERENCES kb_category(id) ON DELETE SET NULL,
    author_id       BIGINT NOT NULL REFERENCES sys_user(id) ON DELETE RESTRICT,
    status          VARCHAR(16) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','PUBLISHED','ARCHIVED')),
    view_count      INT NOT NULL DEFAULT 0,
    version         INT NOT NULL DEFAULT 1,
    deleted_at      TIMESTAMP,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX uk_article_slug ON kb_article (slug) WHERE deleted_at IS NULL;
CREATE INDEX idx_article_category ON kb_article (category_id);
CREATE INDEX idx_article_author ON kb_article (author_id);
CREATE INDEX idx_article_status ON kb_article (status);
CREATE INDEX idx_article_deleted ON kb_article (deleted_at);

COMMENT ON TABLE kb_article IS '文章表';
COMMENT ON COLUMN kb_article.slug IS 'URL友好路径';
COMMENT ON COLUMN kb_article.status IS 'DRAFT/PUBLISHED/ARCHIVED。删除通过 deleted_at 软删除实现，不走 status';

-- ============================================================
-- 5. 文章标签关联 kb_article_tag
-- ============================================================
CREATE TABLE kb_article_tag (
    article_id      BIGINT NOT NULL REFERENCES kb_article(id) ON DELETE CASCADE,
    tag_id          BIGINT NOT NULL REFERENCES kb_tag(id) ON DELETE CASCADE,
    PRIMARY KEY (article_id, tag_id)
);

COMMENT ON TABLE kb_article_tag IS '文章-标签关联表。软删除文章保留标签关联，恢复文章时标签关系仍在';

-- ============================================================
-- 6. 文章版本 kb_article_version
-- ============================================================
CREATE TABLE kb_article_version (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    article_id      BIGINT NOT NULL REFERENCES kb_article(id) ON DELETE CASCADE,
    title           VARCHAR(256) NOT NULL,
    content         TEXT NOT NULL,
    version         INT NOT NULL,
    change_summary  VARCHAR(512),
    created_by      BIGINT NOT NULL REFERENCES sys_user(id) ON DELETE RESTRICT,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),

    UNIQUE (article_id, version)
);

CREATE INDEX idx_version_article ON kb_article_version (article_id);

COMMENT ON TABLE kb_article_version IS '文章版本历史';
COMMENT ON COLUMN kb_article_version.version IS '版本号，与 article_id 联合唯一';

-- ============================================================
-- 7. 评论表 kb_comment
-- ============================================================
CREATE TABLE kb_comment (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    article_id      BIGINT NOT NULL REFERENCES kb_article(id) ON DELETE CASCADE,
    parent_id       BIGINT REFERENCES kb_comment(id) ON DELETE CASCADE,
    content         TEXT NOT NULL,
    author_id       BIGINT NOT NULL REFERENCES sys_user(id) ON DELETE RESTRICT,
    status          SMALLINT NOT NULL DEFAULT 1 CHECK (status IN (0,1)),
    deleted_at      TIMESTAMP,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_comment_article ON kb_comment (article_id);
CREATE INDEX idx_comment_parent ON kb_comment (parent_id);

COMMENT ON TABLE kb_comment IS '评论表（楼中楼）';
COMMENT ON COLUMN kb_comment.status IS '0=已删除 1=正常';
COMMENT ON COLUMN kb_comment.deleted_at IS '软删除时间，已删除评论保留占位';

-- ============================================================
-- 8. 附件表 kb_attachment
-- ============================================================
CREATE TABLE kb_attachment (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    article_id      BIGINT REFERENCES kb_article(id) ON DELETE SET NULL,
    file_name       VARCHAR(256) NOT NULL,
    file_path       VARCHAR(512) NOT NULL,
    file_size       BIGINT NOT NULL,
    mime_type       VARCHAR(128),
    upload_user_id  BIGINT NOT NULL REFERENCES sys_user(id) ON DELETE RESTRICT,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_attachment_article ON kb_attachment (article_id);

COMMENT ON TABLE kb_attachment IS '附件表。清理未关联附件时需同时检查 article_id IS NULL 和关联文章的 deleted_at';

-- ============================================================
-- 9. ES 同步失败日志 es_sync_fail_log
-- ============================================================
CREATE TABLE es_sync_fail_log (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_type     VARCHAR(32) NOT NULL,
    entity_id       BIGINT NOT NULL,
    operation       VARCHAR(16) NOT NULL,
    payload         JSONB,
    retry_count     INT NOT NULL DEFAULT 0,
    status          SMALLINT NOT NULL DEFAULT 0 CHECK (status IN (0,1,2)),
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    next_retry_at   TIMESTAMP
);

CREATE INDEX idx_sync_retry ON es_sync_fail_log (status, next_retry_at);

COMMENT ON TABLE es_sync_fail_log IS 'ES同步失败日志';
COMMENT ON COLUMN es_sync_fail_log.status IS '0=待重试 1=成功 2=放弃(>=5次)';

-- ============================================================
-- updated_at 自动更新触发器
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_user_updated_at BEFORE UPDATE ON sys_user
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER tr_article_updated_at BEFORE UPDATE ON kb_article
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER tr_comment_updated_at BEFORE UPDATE ON kb_comment
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
