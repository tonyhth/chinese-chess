-- V2__seed_data.sql — 初始数据
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
