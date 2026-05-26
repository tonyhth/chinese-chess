package com.kb.search.controller;

import com.kb.common.Result;
import com.kb.search.dto.SearchRequest;
import com.kb.search.dto.SearchResponse;
import com.kb.search.dto.SuggestResponse;
import com.kb.search.dto.SyncAllProgress;
import com.kb.search.service.EsSyncService;
import com.kb.search.service.SearchService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@ConditionalOnProperty(name = "elasticsearch.enabled", havingValue = "true", matchIfMissing = true)
@RequestMapping("/api/v1/search")
@RequiredArgsConstructor
@Tag(name = "搜索", description = "全文搜索与搜索建议")
public class SearchController {

    private final SearchService searchService;
    private final EsSyncService esSyncService;

    @PostMapping
    @Operation(summary = "全文搜索", description = "支持关键词、分类、标签、日期过滤，结果高亮")
    public Result<SearchResponse> search(@Valid @RequestBody SearchRequest request) {
        return Result.ok(searchService.search(request));
    }

    @GetMapping("/suggest")
    @Operation(summary = "搜索建议", description = "基于标题的 completion suggester 补全")
    public Result<SuggestResponse> suggest(@RequestParam String q,
                                           @RequestParam(defaultValue = "10") int size) {
        return Result.ok(searchService.suggest(q, size));
    }

    @PostMapping("/sync-all")
    @Operation(summary = "全量同步文章到 ES（管理员）")
    @PreAuthorize("hasRole('ADMIN')")
    public Result<String> syncAll() {
        return Result.ok(esSyncService.syncAll());
    }

    @GetMapping("/sync-all/progress")
    @Operation(summary = "全量同步进度查询")
    @PreAuthorize("hasRole('ADMIN')")
    public Result<SyncAllProgress> syncProgress() {
        return Result.ok(esSyncService.getSyncProgress());
    }
}
