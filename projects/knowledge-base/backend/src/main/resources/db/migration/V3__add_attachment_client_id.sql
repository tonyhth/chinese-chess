-- V3__add_attachment_client_id.sql
-- 附件表增加 client_id 字段，用于前端幂等去重

ALTER TABLE kb_attachment ADD COLUMN IF NOT EXISTS client_id VARCHAR(128);

COMMENT ON COLUMN kb_attachment.client_id IS '前端幂等去重标识，相同 client_id 不重复创建附件记录';
