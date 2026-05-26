package com.kb.search.service;

import co.elastic.clients.elasticsearch.ElasticsearchClient;
import co.elastic.clients.elasticsearch.core.BulkRequest;
import co.elastic.clients.elasticsearch.core.BulkResponse;
import co.elastic.clients.elasticsearch.core.IndexRequest;
import co.elastic.clients.elasticsearch.core.DeleteRequest;
import co.elastic.clients.elasticsearch.core.bulk.BulkResponseItem;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.kb.article.entity.Article;
import com.kb.article.mapper.ArticleMapper;
import com.kb.article.mapper.ArticleTagMapper;
import com.kb.category.entity.Category;
import com.kb.category.mapper.CategoryMapper;
import com.kb.search.document.ArticleDocument;
import com.kb.search.dto.SyncAllProgress;
import com.kb.search.entity.EsSyncFailLog;
import com.kb.search.mapper.EsSyncFailLogMapper;
import com.kb.tag.entity.Tag;
import com.kb.tag.mapper.TagMapper;
import com.kb.user.entity.User;
import com.kb.user.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.commonmark.node.Node;
import org.commonmark.parser.Parser;
import org.commonmark.renderer.text.TextContentRenderer;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;

import java.time.LocalDateTime;
import java.util.Collections;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

@Slf4j
@Service
@ConditionalOnProperty(name = "elasticsearch.enabled", havingValue = "true", matchIfMissing = true)
@RequiredArgsConstructor
public class EsSyncService {

    private static final String INDEX_NAME = "kb_article";
    private static final String SYNC_LOCK_KEY = "search:sync-all:lock";
    private static final String SYNC_CURSOR_KEY = "search:sync-all:cursor";
    private static final String SYNC_PROGRESS_KEY = "search:sync-all:progress";
    private static final long LOCK_TTL_MINUTES = 30;
    private static final int BATCH_SIZE = 500;
    private static final int MAX_RETRY = 5;

    private static final String UNLOCK_SCRIPT =
            "if redis.call('get', KEYS[1]) == ARGV[1] then " +
            "  return redis.call('del', KEYS[1]) " +
            "else " +
            "  return 0 " +
            "end";

    private final ElasticsearchClient esClient;
    private final ArticleMapper articleMapper;
    private final ArticleTagMapper articleTagMapper;
    private final TagMapper tagMapper;
    private final CategoryMapper categoryMapper;
    private final UserMapper userMapper;
    private final EsSyncFailLogMapper syncFailLogMapper;
    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    private final Parser markdownParser = Parser.builder().build();
    private final TextContentRenderer textRenderer = TextContentRenderer.builder().build();

    // ====== Markdown → 纯文本（AST 解析，禁止正则） ======

    public String markdownToPlainText(String markdown) {
        if (markdown == null || markdown.isBlank()) return "";
        Node document = markdownParser.parse(markdown);
        return textRenderer.render(document);
    }

    // ====== 构建 ES 文档 ======

    public ArticleDocument buildDocument(Article article) {
        ArticleDocument doc = new ArticleDocument();
        doc.setArticleId(article.getId());
        doc.setTitle(article.getTitle());
        doc.setTitleSuggest(ArticleDocument.TitleSuggest.of(article.getTitle()));
        doc.setSummary(article.getSummary());
        doc.setContent(markdownToPlainText(article.getContent()));
        doc.setCategoryId(article.getCategoryId());
        doc.setStatus(article.getStatus());
        doc.setUpdatedAt(article.getUpdatedAt());

        if (article.getCategoryId() != null) {
            StringBuilder path = new StringBuilder();
            Long catId = article.getCategoryId();
            while (catId != null) {
                Category cat = categoryMapper.selectById(catId);
                if (cat == null) break;
                if (path.length() > 0) path.insert(0, "/");
                path.insert(0, cat.getName());
                catId = cat.getParentId();
            }
            doc.setCategoryName(path.toString());
        }

        List<Long> tagIds = articleTagMapper.selectTagIdsByArticleId(article.getId());
        if (!tagIds.isEmpty()) {
            List<Tag> tags = tagMapper.selectBatchIds(tagIds);
            doc.setTagIds(tagIds);
            doc.setTagNames(tags.stream().map(Tag::getName).collect(Collectors.toList()));
        }

        User author = userMapper.selectActiveById(article.getAuthorId());
        if (author != null) {
            doc.setAuthorId(author.getId());
            doc.setAuthorName(author.getUsername());
        }

        return doc;
    }

    // ====== 单条同步（双写调用，写 fail-log） ======

    public void sync(String entityType, Long entityId, String operation) {
        try {
            doSyncDirect(entityType, entityId, operation);
        } catch (Exception e) {
            log.warn("[ES-SYNC] failed: entityType={}, entityId={}, op={}",
                    entityType, entityId, operation, e);
            try {
                saveFailLog(entityType, entityId, operation, e);
            } catch (Exception logEx) {
                log.error("[ES-SYNC] fail-log write also failed!", logEx);
            }
        }
    }

    /**
     * 直接执行 ES 操作，不写 fail-log（重试场景由 retryOne 自行管理状态）。
     */
    private void doSyncDirect(String entityType, Long entityId, String operation) throws Exception {
        switch (operation) {
            case "DELETE" -> {
                esClient.delete(DeleteRequest.of(d -> d
                        .index(INDEX_NAME)
                        .id(String.valueOf(entityId))));
                log.info("[ES-SYNC] articleId={} op=delete status=success", entityId);
            }
            case "CREATE", "UPDATE" -> {
                Article article = articleMapper.selectActiveById(entityId);
                if (article == null || article.getDeletedAt() != null) {
                    try {
                        esClient.delete(DeleteRequest.of(d -> d
                                .index(INDEX_NAME)
                                .id(String.valueOf(entityId))));
                    } catch (Exception ignored) {}
                    return;
                }
                ArticleDocument doc = buildDocument(article);
                esClient.index(IndexRequest.of(i -> i
                        .index(INDEX_NAME)
                        .id(String.valueOf(entityId))
                        .document(doc)));
                log.info("[ES-SYNC] articleId={} op={} status=success", entityId, operation);
            }
        }
    }

    private void saveFailLog(String entityType, Long entityId, String operation, Exception e) {
        EsSyncFailLog failLog = new EsSyncFailLog();
        failLog.setEntityType(entityType);
        failLog.setEntityId(entityId);
        failLog.setOperation(operation);
        failLog.setPayload(e.getMessage() != null ? e.getMessage().substring(0, Math.min(e.getMessage().length(), 4000)) : null);
        failLog.setRetryCount(0);
        failLog.setStatus(0);
        failLog.setNextRetryAt(LocalDateTime.now().plusMinutes(5));
        syncFailLogMapper.insert(failLog);
    }

    // ====== 定时重试（每条独立，不调 sync() 避免重复写 fail-log） ======

    @Scheduled(fixedDelay = 5 * 60 * 1000)
    public void retryFailedSyncs() {
        List<EsSyncFailLog> pending = syncFailLogMapper.selectPending();
        for (EsSyncFailLog failLog : pending) {
            try {
                doSyncDirect(failLog.getEntityType(), failLog.getEntityId(), failLog.getOperation());
                syncFailLogMapper.updateStatus(failLog.getId(), 1);
                log.info("[ES-SYNC-RETRY] id={} retryCount={} status=success", failLog.getId(), failLog.getRetryCount());
            } catch (Exception e) {
                log.warn("[ES-SYNC-RETRY] id={} retry failed", failLog.getId(), e);
                failLog.setRetryCount(failLog.getRetryCount() + 1);
                if (failLog.getRetryCount() >= MAX_RETRY) {
                    failLog.setStatus(2);
                    log.warn("[ES-SYNC-RETRY] abandoned after {} retries: id={}", MAX_RETRY, failLog.getId());
                } else {
                    failLog.setNextRetryAt(LocalDateTime.now().plusMinutes(5L * failLog.getRetryCount()));
                }
                failLog.setUpdatedAt(LocalDateTime.now());
                syncFailLogMapper.updateById(failLog);
            }
        }
    }

    // ====== 全量同步 ======

    public String syncAll() {
        String lockValue = UUID.randomUUID().toString();
        Boolean locked = redisTemplate.opsForValue().setIfAbsent(
                SYNC_LOCK_KEY, lockValue, LOCK_TTL_MINUTES, TimeUnit.MINUTES);
        if (locked == null || !locked) {
            return "全量同步正在进行中，请稍后";
        }

        try {
            String cursorStr = redisTemplate.opsForValue().get(SYNC_CURSOR_KEY);
            long cursor = 0;
            if (cursorStr != null) {
                cursor = Long.parseLong(cursorStr);
            }

            long total = articleMapper.countActive();

            SyncAllProgress progress = new SyncAllProgress();
            progress.setTotal(total);
            progress.setStatus("running");

            long synced = 0;
            boolean hasMore = true;

            while (hasMore) {
                List<Article> articles = articleMapper.selectActiveList(
                        new com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper<Article>()
                                .gt(Article::getId, cursor)
                                .isNull(Article::getDeletedAt)
                                .orderByAsc(Article::getId)
                                .last("LIMIT " + BATCH_SIZE));

                if (articles.isEmpty()) {
                    hasMore = false;
                    break;
                }

                BulkRequest.Builder bulkBuilder = new BulkRequest.Builder();
                for (Article article : articles) {
                    ArticleDocument doc = buildDocument(article);
                    bulkBuilder.operations(op -> op
                            .index(idx -> idx
                                    .index(INDEX_NAME)
                                    .id(String.valueOf(article.getId()))
                                    .document(doc)));
                }

                BulkResponse bulkResponse = esClient.bulk(bulkBuilder.build());

                if (bulkResponse.errors()) {
                    for (BulkResponseItem item : bulkResponse.items()) {
                        if (item.error() != null) {
                            log.error("[ES-SYNC-ALL] bulk error: id={}, reason={}", item.id(), item.error().reason());
                        }
                    }
                }

                cursor = articles.get(articles.size() - 1).getId();
                redisTemplate.opsForValue().set(SYNC_CURSOR_KEY, String.valueOf(cursor));

                synced += articles.size();
                progress.setSynced(synced);
                progress.setPercent(total > 0 ? Math.round(synced * 1000.0 / total) / 10.0 : 100.0);

                try {
                    redisTemplate.opsForValue().set(SYNC_PROGRESS_KEY, objectMapper.writeValueAsString(progress));
                } catch (Exception ignored) {}

                if (articles.size() < BATCH_SIZE) {
                    hasMore = false;
                }
            }

            progress.setStatus("completed");
            progress.setPercent(100.0);
            try {
                redisTemplate.opsForValue().set(SYNC_PROGRESS_KEY, objectMapper.writeValueAsString(progress));
            } catch (Exception ignored) {}

            redisTemplate.delete(SYNC_CURSOR_KEY);
            return "全量同步完成，共同步 " + synced + " 篇文章";
        } catch (Exception e) {
            log.error("[ES-SYNC-ALL] failed", e);
            redisTemplate.delete(SYNC_CURSOR_KEY);
            try {
                SyncAllProgress progress = new SyncAllProgress();
                progress.setStatus("failed");
                redisTemplate.opsForValue().set(SYNC_PROGRESS_KEY, objectMapper.writeValueAsString(progress));
            } catch (Exception ignored) {}
            return "全量同步失败: " + e.getMessage();
        } finally {
            DefaultRedisScript<Long> unlockScript = new DefaultRedisScript<>(UNLOCK_SCRIPT, Long.class);
            redisTemplate.execute(unlockScript, Collections.singletonList(SYNC_LOCK_KEY), lockValue);
        }
    }

    public SyncAllProgress getSyncProgress() {
        String json = redisTemplate.opsForValue().get(SYNC_PROGRESS_KEY);
        if (json == null) {
            SyncAllProgress p = new SyncAllProgress();
            p.setStatus("idle");
            return p;
        }
        try {
            return objectMapper.readValue(json, SyncAllProgress.class);
        } catch (Exception e) {
            SyncAllProgress p = new SyncAllProgress();
            p.setStatus("idle");
            return p;
        }
    }
}
