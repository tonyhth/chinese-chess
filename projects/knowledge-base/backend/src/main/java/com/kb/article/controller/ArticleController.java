package com.kb.article.controller;

import com.kb.article.dto.*;
import com.kb.article.service.ArticleService;
import com.kb.article.service.ArticleVersionService;
import com.kb.article.service.ArticleBatchService;
import com.kb.common.PageResult;
import com.kb.common.Result;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;

import java.util.List;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/articles")
@RequiredArgsConstructor
@Tag(name = "文章", description = "文章 CRUD")
public class ArticleController {

    private final ArticleService articleService;
    private final ArticleVersionService articleVersionService;
    private final ArticleBatchService articleBatchService;

    @PostMapping
    @Operation(summary = "创建文章")
    @PreAuthorize("hasAnyRole('ADMIN', 'EDITOR')")
    public Result<ArticleDTO> create(@Valid @RequestBody ArticleCreateRequest request) {
        return Result.ok(articleService.create(request));
    }

    @GetMapping
    @Operation(summary = "文章列表（分页）")
    public Result<PageResult<ArticleDTO>> list(ArticleQueryRequest query) {
        return Result.ok(articleService.list(query));
    }

    @GetMapping("/{id}")
    @Operation(summary = "文章详情")
    public Result<ArticleDTO> getById(@PathVariable Long id) {
        return Result.ok(articleService.getById(id));
    }

    @PutMapping("/{id}")
    @Operation(summary = "更新文章")
    @PreAuthorize("hasAnyRole('ADMIN', 'EDITOR')")
    public Result<ArticleDTO> update(@PathVariable Long id, @Valid @RequestBody ArticleUpdateRequest request) {
        return Result.ok(articleService.update(id, request));
    }

    @GetMapping("/{id}/versions")
    @Operation(summary = "文章版本列表")
    public Result<List<ArticleVersionDTO>> listVersions(@PathVariable Long id) {
        return Result.ok(articleVersionService.listVersions(id));
    }

    @GetMapping("/{id}/versions/{version}")
    @Operation(summary = "文章版本详情")
    public Result<ArticleVersionDTO> getVersion(@PathVariable Long id, @PathVariable Integer version) {
        return Result.ok(articleVersionService.getVersion(id, version));
    }

    @PostMapping("/{id}/versions/{version}/restore")
    @Operation(summary = "回滚到指定版本")
    @PreAuthorize("hasAnyRole('ADMIN', 'EDITOR')")
    public Result<ArticleVersionDTO> restoreVersion(@PathVariable Long id, @PathVariable Integer version) {
        return Result.ok(articleVersionService.restoreVersion(id, version));
    }

    @PatchMapping("/{id}/status")
    @Operation(summary = "修改文章状态（包括软删除：status=DELETED）")
    @PreAuthorize("hasAnyRole('ADMIN', 'EDITOR')")
    public Result<ArticleDTO> updateStatus(@PathVariable Long id, @Valid @RequestBody StatusUpdateRequest request) {
        return Result.ok(articleService.updateStatus(id, request));
    }

    @PostMapping("/batch/delete")
    @Operation(summary = "批量删除文章")
    @PreAuthorize("hasAnyRole('ADMIN', 'EDITOR')")
    public Result<ArticleBatchResult> batchDelete(@Valid @RequestBody ArticleBatchDeleteRequest request) {
        return Result.ok(articleBatchService.batchDelete(request));
    }

    @PostMapping("/batch/move")
    @Operation(summary = "批量移动文章到分类")
    @PreAuthorize("hasAnyRole('ADMIN', 'EDITOR')")
    public Result<ArticleBatchResult> batchMove(@Valid @RequestBody ArticleBatchMoveRequest request) {
        return Result.ok(articleBatchService.batchMove(request));
    }

    @PostMapping("/batch/tag")
    @Operation(summary = "批量打标签")
    @PreAuthorize("hasAnyRole('ADMIN', 'EDITOR')")
    public Result<ArticleBatchResult> batchTag(@Valid @RequestBody ArticleBatchTagRequest request) {
        return Result.ok(articleBatchService.batchTag(request));
    }
}
