package com.kb.search.service;

import co.elastic.clients.elasticsearch.ElasticsearchClient;
import co.elastic.clients.elasticsearch._types.FieldValue;
import co.elastic.clients.elasticsearch._types.SortOrder;
import co.elastic.clients.elasticsearch.core.search.TotalHitsRelation;
import co.elastic.clients.json.JsonData;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.kb.search.dto.SearchRequest;
import com.kb.search.dto.SuggestResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@ConditionalOnProperty(name = "elasticsearch.enabled", havingValue = "true", matchIfMissing = true)
@RequiredArgsConstructor
public class SearchService {

    private static final String INDEX_NAME = "kb_article";
    private static final String CACHE_PREFIX = "search:";
    private static final Duration CACHE_TTL = Duration.ofMinutes(5);

    private final ElasticsearchClient esClient;
    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    /**
     * 全文搜索（T2）
     */
    public com.kb.search.dto.SearchResponse search(SearchRequest request) {
        // 检查缓存
        String cacheKey = CACHE_PREFIX + md5(request.cacheKey());
        String cached = redisTemplate.opsForValue().get(cacheKey);
        if (cached != null) {
            try {
                com.kb.search.dto.SearchResponse response = objectMapper.readValue(cached, com.kb.search.dto.SearchResponse.class);
                response.setCached(true);
                return response;
            } catch (Exception e) {
                log.warn("[CACHE] deserialization failed for key={}, removing", cacheKey, e);
                redisTemplate.delete(cacheKey);
            }
        }

        // 构建 ES 查询
        try {
            co.elastic.clients.elasticsearch.core.SearchRequest.Builder esReqBuilder =
                    new co.elastic.clients.elasticsearch.core.SearchRequest.Builder()
                            .index(INDEX_NAME)
                            .from((request.getPage() - 1) * request.getSize())
                            .size(request.getSize());

            // 查询条件
            esReqBuilder.query(q -> q.bool(b -> {
                b.must(m -> m.multiMatch(mm -> mm
                        .query(request.getQuery())
                        .fields("title^2", "content", "summary")
                        .type(co.elastic.clients.elasticsearch._types.query_dsl.TextQueryType.BestFields)));

                b.filter(f -> f.term(t -> t.field("status").value(FieldValue.of("PUBLISHED"))));

                if (request.getCategoryId() != null) {
                    b.filter(f -> f.term(t -> t.field("categoryId").value(FieldValue.of(request.getCategoryId()))));
                }

                if (request.getTagNames() != null && !request.getTagNames().isEmpty()) {
                    for (String tagName : request.getTagNames()) {
                        b.filter(f -> f.term(t -> t.field("tagNames").value(FieldValue.of(tagName))));
                    }
                }

                if (request.getDateFrom() != null || request.getDateTo() != null) {
                    b.filter(f -> f.range(r -> {
                        r.field("updatedAt");
                        if (request.getDateFrom() != null) {
                            r.gte(JsonData.of(request.getDateFrom()));
                        }
                        if (request.getDateTo() != null) {
                            r.lte(JsonData.of(request.getDateTo()));
                        }
                        return r;
                    }));
                }

                return b;
            }));

            // 高亮
            esReqBuilder.highlight(h -> h
                    .preTags("<em class='hl'>")
                    .postTags("</em>")
                    .fields("title", hf -> hf.numberOfFragments(0))
                    .fields("content", hf -> hf.fragmentSize(150).numberOfFragments(3))
                    .fields("summary", hf -> hf.fragmentSize(100).numberOfFragments(1)));

            // 排序
            String sort = request.getSort() != null ? request.getSort() : "relevance";
            switch (sort) {
                case "newest" -> esReqBuilder.sort(s -> s.field(f -> f.field("updatedAt").order(SortOrder.Desc)));
                case "oldest" -> esReqBuilder.sort(s -> s.field(f -> f.field("updatedAt").order(SortOrder.Asc)));
                default -> esReqBuilder.sort(s -> s.score(sc -> sc.order(SortOrder.Desc)));
            }

            // 执行搜索 — 返回原始 hit，手动映射
            co.elastic.clients.elasticsearch.core.SearchResponse<Map> esResponse =
                    esClient.search(esReqBuilder.build(), Map.class);

            // 组装响应
            com.kb.search.dto.SearchResponse response = new com.kb.search.dto.SearchResponse();
            response.setTotal(esResponse.hits().total() != null ? esResponse.hits().total().value() : 0);
            response.setPage(request.getPage());
            response.setSize(request.getSize());
            response.setCached(false);

            List<com.kb.search.dto.SearchResponse.SearchHit> hits = esResponse.hits().hits().stream().map(hit -> {
                com.kb.search.dto.SearchResponse.SearchHit h = new com.kb.search.dto.SearchResponse.SearchHit();
                Map<String, Object> source = hit.source();
                if (source != null) {
                    if (source.get("articleId") != null) h.setArticleId(((Number) source.get("articleId")).longValue());
                    h.setTitle((String) source.get("title"));
                    h.setSummary((String) source.get("summary"));
                    h.setCategoryName((String) source.get("categoryName"));
                    h.setTagNames((List<String>) source.get("tagNames"));
                    h.setAuthorName((String) source.get("authorName"));
                    if (source.get("updatedAt") != null) {
                        // ES date field 可能是字符串或数字
                        Object val = source.get("updatedAt");
                        if (val instanceof String) {
                            h.setUpdatedAt(java.time.LocalDateTime.parse((String) val,
                                    java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss")));
                        }
                    }
                }

                // 高亮覆盖
                if (hit.highlight() != null) {
                    List<String> titleHl = hit.highlight().get("title");
                    if (titleHl != null && !titleHl.isEmpty()) h.setTitle(titleHl.get(0));
                    List<String> summaryHl = hit.highlight().get("summary");
                    if (summaryHl != null && !summaryHl.isEmpty()) h.setSummary(summaryHl.get(0));
                    List<String> contentHl = hit.highlight().get("content");
                    if (contentHl != null) h.setContentHighlights(contentHl);
                }

                return h;
            }).collect(Collectors.toList());

            response.setHits(hits);

            // 缓存（空结果不缓存）
            if (response.getTotal() > 0) {
                try {
                    String json = objectMapper.writeValueAsString(response);
                    redisTemplate.opsForValue().set(cacheKey, json, CACHE_TTL);
                } catch (Exception ignored) {}
            }

            log.info("[SEARCH] query=\"{}\" hits={} cached=false", request.getQuery(), response.getTotal());
            return response;

        } catch (IOException e) {
            log.error("[SEARCH] ES query failed: query={}", request.getQuery(), e);
            throw new RuntimeException("搜索服务暂时不可用", e);
        }
    }

    /**
     * 搜索建议（T5）
     */
    public SuggestResponse suggest(String prefix, int size) {
        try {
            co.elastic.clients.elasticsearch.core.SearchResponse<Void> esResponse = esClient.search(
                    s -> s.index(INDEX_NAME)
                            .suggest(su -> su
                                    .suggesters("title-suggest", ts -> ts
                                            .prefix(prefix)
                                            .completion(c -> c
                                                    .field("titleSuggest")
                                                    .size(size)
                                                    .skipDuplicates(true)))),
                    Void.class);

            SuggestResponse response = new SuggestResponse();
            List<SuggestResponse.SuggestItem> items = new ArrayList<>();

            if (esResponse.suggest() != null && esResponse.suggest().get("title-suggest") != null) {
                try {
                    for (var entry : esResponse.suggest().get("title-suggest")) {
                        if (entry.isCompletion()) {
                            var cs = entry.completion();
                            for (var opt : cs.options()) {
                                SuggestResponse.SuggestItem item = new SuggestResponse.SuggestItem();
                                item.setText(opt.text());
                                if (opt.id() != null) {
                                    try {
                                        item.setArticleId(Long.parseLong(opt.id()));
                                    } catch (NumberFormatException ignored) {}
                                }
                                items.add(item);
                            }
                        }
                    }
                } catch (Exception e) {
                    log.warn("解析搜索建议失败: {}", e.getMessage());
                }
            }

            response.setSuggestions(items);
            return response;

        } catch (IOException e) {
            log.error("[SUGGEST] ES suggest failed: prefix={}", prefix, e);
            SuggestResponse empty = new SuggestResponse();
            empty.setSuggestions(List.of());
            return empty;
        }
    }

    /**
     * 清除所有搜索缓存
     */
    public void evictAllSearchCache() {
        Set<String> keys = new HashSet<>();
        try (var cursor = redisTemplate.scan(
                org.springframework.data.redis.core.ScanOptions.scanOptions()
                        .match(CACHE_PREFIX + "*")
                        .count(200)
                        .build())) {
            cursor.forEachRemaining(keys::add);
        }
        if (!keys.isEmpty()) {
            redisTemplate.delete(keys);
            log.debug("[CACHE] evicted {} search cache keys", keys.size());
        }
    }

    private String md5(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("MD5");
            byte[] digest = md.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : digest) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (Exception e) {
            return String.valueOf(input.hashCode());
        }
    }
}
