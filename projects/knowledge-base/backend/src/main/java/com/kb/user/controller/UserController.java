package com.kb.user.controller;

import com.kb.auth.security.CustomUserDetails;
import com.kb.common.BusinessException;
import com.kb.common.ErrorCode;
import com.kb.common.PageResult;
import com.kb.common.Result;
import com.kb.common.security.PermissionService;
import com.kb.permission.service.ArticlePermissionService;
import com.kb.permission.service.CategoryPermissionService;
import com.kb.user.dto.UserCreateRequest;
import com.kb.user.dto.UserDTO;
import com.kb.user.dto.UserUpdateRequest;
import com.kb.user.dto.RoleUpdateRequest;
import com.kb.user.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
@Tag(name = "用户", description = "用户信息与管理")
public class UserController {

    private final UserService userService;
    private final PermissionService permissionService;
    private final ArticlePermissionService articlePermissionService;
    private final CategoryPermissionService categoryPermissionService;

    @GetMapping("/users/me")
    @Operation(summary = "获取当前用户信息")
    public Result<UserDTO> me(@AuthenticationPrincipal CustomUserDetails userDetails) {
        return Result.ok(userService.getMe(userDetails.getId()));
    }

    @GetMapping("/users")
    @Operation(summary = "用户列表（分页）")
    @PreAuthorize("hasRole('ADMIN')")
    public Result<PageResult<UserDTO>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size) {
        return Result.ok(userService.list(page, size));
    }

    @PostMapping("/users")
    @Operation(summary = "创建用户（仅ADMIN）")
    @PreAuthorize("hasRole('ADMIN')")
    public Result<UserDTO> create(@Valid @RequestBody UserCreateRequest request) {
        return Result.ok(userService.create(request));
    }

    @PutMapping("/users/{id}")
    @Operation(summary = "更新用户信息（仅ADMIN）")
    @PreAuthorize("hasRole('ADMIN')")
    public Result<UserDTO> update(@PathVariable Long id, @Valid @RequestBody UserUpdateRequest request) {
        return Result.ok(userService.update(id, request));
    }

    @DeleteMapping("/users/{id}")
    @Operation(summary = "删除用户（仅ADMIN）")
    @PreAuthorize("hasRole('ADMIN')")
    public Result<Void> delete(@PathVariable Long id) {
        userService.delete(id);
        return Result.ok();
    }

    @GetMapping("/users/search")
    @Operation(summary = "搜索用户（按用户名或邮箱模糊匹配）")
    @PreAuthorize("isAuthenticated()")
    public Result<PageResult<UserDTO>> search(
            @RequestParam String keyword,
            @RequestParam(required = false) String resourceType,
            @RequestParam(required = false) Long resourceId,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size) {
        // 鉴权：ADMIN 直接放行；非 ADMIN 必须传 resourceType+resourceId 且拥有该资源 MANAGE 权限
        if (!permissionService.isAdmin()) {
            if (resourceType == null || resourceId == null) {
                throw new BusinessException(ErrorCode.FORBIDDEN, "非管理员需指定资源类型和 ID");
            }
            if ("article".equals(resourceType)) {
                if (!articlePermissionService.hasPermission(resourceId, permissionService.currentUserId(), "MANAGE")) {
                    throw new BusinessException(ErrorCode.FORBIDDEN, "无权搜索用户");
                }
            } else if ("category".equals(resourceType)) {
                if (!categoryPermissionService.hasPermission(resourceId, permissionService.currentUserId(), "MANAGE")) {
                    throw new BusinessException(ErrorCode.FORBIDDEN, "无权搜索用户");
                }
            } else {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "不支持的资源类型: " + resourceType);
            }
        }
        return Result.ok(userService.searchUsers(keyword, page, size));
    }

    @PutMapping("/users/{id}/role")
    @Operation(summary = "修改用户角色（仅ADMIN）")
    @PreAuthorize("hasRole('ADMIN')")
    public Result<UserDTO> updateRole(@PathVariable Long id, @Valid @RequestBody RoleUpdateRequest request) {
        return Result.ok(userService.updateRole(id, request.getRole()));
    }
}
