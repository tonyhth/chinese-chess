-- V4__p1_comment_depth.sql
-- 评论表新增 depth 冗余字段，支持 O(1) 层级判断
ALTER TABLE kb_comment ADD COLUMN IF NOT EXISTS depth SMALLINT NOT NULL DEFAULT 0;
COMMENT ON COLUMN kb_comment.depth IS '嵌套层级：0=顶级，1/2/3=回复';

CREATE INDEX IF NOT EXISTS idx_comment_parent_depth ON kb_comment(parent_id, depth);
