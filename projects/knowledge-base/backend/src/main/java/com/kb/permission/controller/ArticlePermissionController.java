package com.kb.permission.controller;

import com.kb.common.BusinessException;
import com.kb.common.ErrorCode;
import com.kb.common.Result;
import com.kb.permission.dto.*;
import com.kb.permission.service.ArticlePermissionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
@Tag(name = "文章权限", description = "文章资源级权限管理")
public class ArticlePermissionController {

    private final ArticlePermissionService articlePermissionService;

    @GetMapping("/articles/{articleId}/permissions")
    @Operation(summary = "获取文章权限列表")
    @PreAuthorize("isAuthenticated()")
    public Result<List<PermissionDTO>> listPermissions(@PathVariable Long articleId) {
        return Result.ok(articlePermissionService.listPermissionsWithCheck(articleId));
    }

    @PutMapping("/articles/{articleId}/permissions")
    @Operation(summary = "设置文章权限（批量 upsert）")
    @PreAuthorize("isAuthenticated()")
    public Result<List<PermissionDTO>> setPermissions(
            @PathVariable Long articleId,
            @Valid @RequestBody BatchPermissionRequest request) {
        return Result.ok(articlePermissionService.setPermissions(articleId, request.getPermissions()));
    }

    @DeleteMapping("/articles/{articleId}/permissions/{userId}")
    @Operation(summary = "移除文章权限")
    @PreAuthorize("isAuthenticated()")
    public Result<Void> removePermission(@PathVariable Long articleId, @PathVariable Long userId) {
        articlePermissionService.removePermission(articleId, userId);
        return Result.ok();
    }

    @PostMapping("/articles/permissions/batch-query")
    @Operation(summary = "批量查询当前用户对多篇文章的权限")
    @PreAuthorize("isAuthenticated()")
    public Result<Map<Long, String>> batchQuery(@RequestBody List<Long> articleIds) {
        if (articleIds == null || articleIds.size() > 100) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "articleIds 数量不能超过 100");
        }
        return Result.ok(articlePermissionService.batchQuery(articleIds));
    }
}
