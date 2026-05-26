-- V5: 资源级权限表（文章 + 分类）
-- 权限语义：VIEW < EDIT < MANAGE，每用户每资源只存最高级别

CREATE TABLE kb_article_permission (
    id          BIGSERIAL PRIMARY KEY,
    article_id  BIGINT NOT NULL REFERENCES kb_article(id),
    user_id     BIGINT NOT NULL REFERENCES sys_user(id),
    permission  VARCHAR(20) NOT NULL,  -- 'VIEW' | 'EDIT' | 'MANAGE'
    granted_by  BIGINT NOT NULL REFERENCES sys_user(id),
    created_at  TIMESTAMP DEFAULT NOW(),
    updated_at  TIMESTAMP DEFAULT NOW(),
    UNIQUE(article_id, user_id)
);

CREATE INDEX idx_ap_article ON kb_article_permission(article_id);
CREATE INDEX idx_ap_user ON kb_article_permission(user_id);

CREATE TABLE kb_category_permission (
    id           BIGSERIAL PRIMARY KEY,
    category_id  BIGINT NOT NULL REFERENCES kb_category(id),
    user_id      BIGINT NOT NULL REFERENCES sys_user(id),
    permission   VARCHAR(20) NOT NULL,  -- 'VIEW' | 'EDIT' | 'MANAGE'
    granted_by   BIGINT NOT NULL REFERENCES sys_user(id),
    created_at   TIMESTAMP DEFAULT NOW(),
    updated_at   TIMESTAMP DEFAULT NOW(),
    UNIQUE(category_id, user_id)
);

CREATE INDEX idx_cp_category ON kb_category_permission(category_id);
CREATE INDEX idx_cp_user ON kb_category_permission(user_id);
