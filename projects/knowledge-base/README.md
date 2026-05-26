# 团队知识库系统

## 快速开始

```bash
# 1. 配置环境变量
cp .env.example .env

# 2. 启动基础服务（PostgreSQL + Redis + MinIO）
docker compose up -d

# 3. 启动后端
cd backend && mvn spring-boot:run

# 4. API 文档
open http://localhost:8080/swagger-ui.html
```

## 技术栈

- 后端：Spring Boot 3.2 + Java 17 + MyBatis-Plus
- 数据库：PostgreSQL 16
- 缓存：Redis 7
- 文件存储：MinIO
- API 文档：SpringDoc OpenAPI
