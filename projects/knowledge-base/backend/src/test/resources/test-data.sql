-- 测试数据初始化：预设用户（密码均为 admin123）
MERGE INTO sys_user (id, username, password_hash, email, role, status) KEY(id) VALUES (1, 'admin', '$2a$10$8jRZ8fTUX3j.EW2wB/vDHu44F6zykZigbBbxUTo4zGbCLfL/.TwGO', 'admin@test.com', 'ADMIN', 1);
MERGE INTO sys_user (id, username, password_hash, email, role, status) KEY(id) VALUES (2, 'editor', '$2a$10$8jRZ8fTUX3j.EW2wB/vDHu44F6zykZigbBbxUTo4zGbCLfL/.TwGO', 'editor@test.com', 'EDITOR', 1);
MERGE INTO sys_user (id, username, password_hash, email, role, status) KEY(id) VALUES (3, 'reader', '$2a$10$8jRZ8fTUX3j.EW2wB/vDHu44F6zykZigbBbxUTo4zGbCLfL/.TwGO', 'reader@test.com', 'READER', 1);

MERGE INTO kb_category (id, name, slug, sort_order) KEY(id) VALUES (1, '根分类A', 'root-a', 0);
MERGE INTO kb_category (id, parent_id, name, slug, sort_order) KEY(id) VALUES (2, 1, '子分类A1', 'child-a1', 0);

MERGE INTO kb_tag (id, name, color) KEY(id) VALUES (1, 'TestTag1', '#b07219');
MERGE INTO kb_tag (id, name, color) KEY(id) VALUES (2, 'TestTag2', '#3572A5');
