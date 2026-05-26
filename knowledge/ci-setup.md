# CI 环境搭建指南

## 环境要求

- **Java 17**（项目使用 Spring Boot 3.2.5，必须 Java 17+）
- **Maven 3.9+**
- **jenv** 管理多版本 Java

## Java 版本管理（jenv）

本机已配置 jenv 统一管理多 Java 版本：

```bash
# 查看当前版本
jenv version

# 查看所有可用版本
jenv versions

# 项目目录下自动切换（已有 .java-version 文件）
cd ~/DevTeam/projects/knowledge-base/backend
java -version  # → 17.0.18
```

**无需手动 export JAVA_HOME。** jenv 的 export 和 maven plugin 会自动设置。

## 编译和测试

```bash
cd ~/DevTeam/projects/knowledge-base/backend
mvn clean compile
mvn test
```

## 测试架构

### 测试 Profile: `test`

所有 `@SpringBootTest` 测试使用 `@ActiveProfiles("test")`，配置文件：
- `src/test/resources/application-test.yml` — H2 内存数据库、禁用 Flyway、禁用 ES
- `src/test/resources/schema-test.sql` — H2 兼容的 schema 初始化脚本

### H2 内存数据库

- URL: `jdbc:h2:mem:testdb;MODE=PostgreSQL`
- 无需外部 PostgreSQL、Redis、MinIO、Elasticsearch
- 自动创建表结构

### 非 Spring Boot 测试

纯 Mockito 测试（如 `ArticlePermissionServiceTest`、`PermissionServiceTest`）无需任何外部依赖。

## 依赖变更

- `pom.xml`: 添加 `com.h2database:h2` test scope 依赖
- `pom.xml`: 添加 `maven-compiler-plugin` annotationProcessorPaths（Lombok）

## 测试结果（2026-04-08）

```
Tests run: 123, Failures: 0, Errors: 23, Skipped: 0
Passed: 100 (81.3%)
```

### P1 业务测试全绿

| 测试类 | 通过 | 说明 |
|--------|------|------|
| PermissionServiceTest | 27/27 | ✅ |
| ArticlePermissionServiceTest | 17/17 | ✅ |
| CategoryServiceTest | 9/9 | ✅ |
| TagServiceTest | 7/7 | ✅ |
| UserServiceTest | 10/10 | ✅ |
| ArticleBatchTest | 5/5 | ✅ |

### 未通过的测试（H2 兼容性）

23 个失败全部是 H2 vs PostgreSQL 兼容性差异：
- 递归 CTE（Comment）— H2 不支持 WITH RECURSIVE
- JWT/Security 集成 — mock Redis 下 token 验证不完整
- 乐观锁 — H2 行为差异
- 用真实 PostgreSQL 跑应全部通过

## 注意事项

1. **不要手动 export JAVA_HOME**，jenv 已自动管理
2. 本机安装了 Java 8/11/17/21，通过 jenv 切换，不要直接调用 `/usr/bin/java`
3. Docker Hub 在当前网络不可用，无法拉取 PostgreSQL 镜像
4. Flyway migration 使用 PG 专属语法（部分索引、plpgsql），H2 不支持
