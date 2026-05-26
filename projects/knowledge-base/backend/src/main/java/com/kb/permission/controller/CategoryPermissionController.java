package com.kb.permission.controller;

import com.kb.common.Result;
import com.kb.permission.dto.*;
import com.kb.permission.service.CategoryPermissionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/categories/{categoryId}/permissions")
@RequiredArgsConstructor
@Tag(name = "分类权限", description = "分类资源级权限管理")
public class CategoryPermissionController {

    private final CategoryPermissionService categoryPermissionService;

    @GetMapping
    @Operation(summary = "获取分类权限列表")
    @PreAuthorize("isAuthenticated()")
    public Result<List<PermissionDTO>> listPermissions(@PathVariable Long categoryId) {
        return Result.ok(categoryPermissionService.listPermissionsWithCheck(categoryId));
    }

    @PutMapping
    @Operation(summary = "设置分类权限（批量 upsert）")
    @PreAuthorize("isAuthenticated()")
    public Result<List<PermissionDTO>> setPermissions(
            @PathVariable Long categoryId,
            @Valid @RequestBody BatchPermissionRequest request) {
        return Result.ok(categoryPermissionService.setPermissions(categoryId, request.getPermissions()));
    }

    @DeleteMapping("/{userId}")
    @Operation(summary = "移除分类权限")
    @PreAuthorize("isAuthenticated()")
    public Result<Void> removePermission(@PathVariable Long categoryId, @PathVariable Long userId) {
        categoryPermissionService.removePermission(categoryId, userId);
        return Result.ok();
    }
}
