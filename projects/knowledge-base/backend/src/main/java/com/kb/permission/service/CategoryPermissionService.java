package com.kb.permission.service;

import com.kb.common.BusinessException;
import com.kb.common.ErrorCode;
import com.kb.common.security.PermissionService;
import com.kb.permission.dto.*;
import com.kb.permission.entity.CategoryPermission;
import com.kb.permission.mapper.CategoryPermissionMapper;
import com.kb.user.entity.User;
import com.kb.user.mapper.UserMapper;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CategoryPermissionService {

    private final CategoryPermissionMapper categoryPermissionMapper;
    private final UserMapper userMapper;
    private final PermissionService permissionService;

    private static final Set<String> VALID_PERMISSIONS = Set.of("VIEW", "EDIT", "MANAGE");

    public List<PermissionDTO> listPermissions(Long categoryId) {
        List<CategoryPermission> perms = categoryPermissionMapper.listByCategory(categoryId);
        return toDTOList(perms);
    }

    /**
     * 获取权限列表（含操作者权限校验，仅 ADMIN 或 MANAGE 可查看）
     */
    public List<PermissionDTO> listPermissionsWithCheck(Long categoryId) {
        Long currentUserId = permissionService.currentUserId();
        if (!canManage(categoryId, currentUserId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "无权查看此分类的权限列表");
        }
        return listPermissions(categoryId);
    }

    @Transactional
    public List<PermissionDTO> setPermissions(Long categoryId, List<PermissionGrantRequest> requests) {
        Long currentUserId = permissionService.currentUserId();

        if (!canManage(categoryId, currentUserId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "无权管理此分类的权限");
        }

        // 批量校验 + 解析目标用户
        Map<Long, String> targetPerms = new LinkedHashMap<>();
        for (PermissionGrantRequest req : requests) {
            if (!req.hasIdentifier()) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "必须提供 userId 或 username");
            }
            Long targetUserId = resolveUserId(req, currentUserId);
            if (targetUserId.equals(currentUserId)) {
                throw new BusinessException(ErrorCode.CONFLICT, "不能对自己授权");
            }
            if (!VALID_PERMISSIONS.contains(req.getPermission())) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "无效的权限级别: " + req.getPermission());
            }
            targetPerms.put(targetUserId, req.getPermission());
        }

        List<CategoryPermission> results = new ArrayList<>();
        for (Map.Entry<Long, String> entry : targetPerms.entrySet()) {
            Long userId = entry.getKey();
            String perm = entry.getValue();

            CategoryPermission existing = categoryPermissionMapper.findByCategoryAndUser(categoryId, userId);
            if (existing != null) {
                existing.setPermission(perm);
                existing.setGrantedBy(currentUserId);
                existing.setUpdatedAt(LocalDateTime.now());
                categoryPermissionMapper.updateById(existing);
                results.add(existing);
            } else {
                CategoryPermission cp = new CategoryPermission();
                cp.setCategoryId(categoryId);
                cp.setUserId(userId);
                cp.setPermission(perm);
                cp.setGrantedBy(currentUserId);
                categoryPermissionMapper.insert(cp);
                results.add(cp);
            }
        }

        return toDTOList(results);
    }

    @Transactional
    public void removePermission(Long categoryId, Long userId) {
        Long currentUserId = permissionService.currentUserId();
        if (!canManage(categoryId, currentUserId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "无权管理此分类的权限");
        }
        CategoryPermission cp = categoryPermissionMapper.findByCategoryAndUser(categoryId, userId);
        if (cp != null) {
            categoryPermissionMapper.deleteById(cp.getId());
        }
    }

    public boolean hasPermission(Long categoryId, Long userId, String requiredLevel) {
        String perm = categoryPermissionMapper.getPermissionLevel(categoryId, userId);
        if (perm == null) return false;
        return comparePermission(perm, requiredLevel) >= 0;
    }

    // --- internal ---

    private Long resolveUserId(PermissionGrantRequest req, Long currentUserId) {
        if (req.getUserId() != null) {
            User target = userMapper.selectActiveById(req.getUserId());
            if (target == null) throw new BusinessException(ErrorCode.USER_NOT_FOUND);
            return target.getId();
        }
        User target = userMapper.selectActiveByIdentifier(req.getUsername());
        if (target == null) throw new BusinessException(ErrorCode.USER_NOT_FOUND, "用户不存在: " + req.getUsername());
        return target.getId();
    }

    private boolean canManage(Long categoryId, Long userId) {
        if (permissionService.isAdmin()) return true;
        return hasPermission(categoryId, userId, "MANAGE");
    }

    private int permissionOrder(String p) {
        return switch (p) {
            case "VIEW" -> 0;
            case "EDIT" -> 1;
            case "MANAGE" -> 2;
            default -> -1;
        };
    }

    private int comparePermission(String a, String b) {
        return Integer.compare(permissionOrder(a), permissionOrder(b));
    }

    private List<PermissionDTO> toDTOList(List<CategoryPermission> perms) {
        if (perms.isEmpty()) return Collections.emptyList();

        Set<Long> allIds = new HashSet<>();
        for (CategoryPermission cp : perms) {
            allIds.add(cp.getUserId());
            allIds.add(cp.getGrantedBy());
        }
        // 批量查用户，一次 SQL
        List<User> users = userMapper.selectActiveList(
                new LambdaQueryWrapper<User>()
                        .in(User::getId, allIds)
                        .isNull(User::getDeletedAt)
        );
        Map<Long, User> userMap = new HashMap<>();
        for (User u : users) userMap.put(u.getId(), u);

        return perms.stream().map(cp -> {
            PermissionDTO dto = new PermissionDTO();
            dto.setId(cp.getId());
            dto.setResourceId(cp.getCategoryId());
            dto.setUserId(cp.getUserId());
            dto.setPermission(cp.getPermission());
            dto.setGrantedBy(cp.getGrantedBy());
            dto.setCreatedAt(cp.getCreatedAt());
            dto.setUpdatedAt(cp.getUpdatedAt());
            User user = userMap.get(cp.getUserId());
            if (user != null) dto.setUsername(user.getUsername());
            User granter = userMap.get(cp.getGrantedBy());
            if (granter != null) dto.setGrantedByName(granter.getUsername());
            return dto;
        }).collect(Collectors.toList());
    }
}
