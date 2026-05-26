package com.kb.permission.service;

import com.kb.common.BusinessException;
import com.kb.common.ErrorCode;
import com.kb.common.security.PermissionService;
import com.kb.permission.dto.*;
import com.kb.permission.entity.ArticlePermission;
import com.kb.permission.mapper.ArticlePermissionMapper;
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
public class ArticlePermissionService {

    private final ArticlePermissionMapper articlePermissionMapper;
    private final UserMapper userMapper;
    private final PermissionService permissionService;

    private static final Set<String> VALID_PERMISSIONS = Set.of("VIEW", "EDIT", "MANAGE");

    public List<PermissionDTO> listPermissions(Long articleId) {
        List<ArticlePermission> perms = articlePermissionMapper.listByArticle(articleId);
        return toDTOList(perms);
    }

    /**
     * 获取权限列表（含操作者权限校验，仅 ADMIN 或 MANAGE 可查看）
     */
    public List<PermissionDTO> listPermissionsWithCheck(Long articleId) {
        Long currentUserId = permissionService.currentUserId();
        if (!canManage(articleId, currentUserId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "无权查看此文章的权限列表");
        }
        return listPermissions(articleId);
    }

    /**
     * 设置权限（批量 upsert）
     * 支持 userId 或 username 指定目标用户
     */
    @Transactional
    public List<PermissionDTO> setPermissions(Long articleId, List<PermissionGrantRequest> requests) {
        Long currentUserId = permissionService.currentUserId();

        // 校验操作者权限
        if (!canManage(articleId, currentUserId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "无权管理此文章的权限");
        }

        // 1. 批量校验 + 解析目标用户
        Map<Long, String> targetPerms = new LinkedHashMap<>();  // userId -> permission
        for (PermissionGrantRequest req : requests) {
            if (!req.hasIdentifier()) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "必须提供 userId 或 username");
            }
            // 不能对自己授权
            Long targetUserId = resolveUserId(req, currentUserId);
            if (targetUserId.equals(currentUserId)) {
                throw new BusinessException(ErrorCode.CONFLICT, "不能对自己授权");
            }
            if (!VALID_PERMISSIONS.contains(req.getPermission())) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "无效的权限级别: " + req.getPermission());
            }
            targetPerms.put(targetUserId, req.getPermission());
        }

        // 2. 批量 upsert（每用户 1 次查询 + 1 次写入，不回查）
        List<ArticlePermission> results = new ArrayList<>();
        for (Map.Entry<Long, String> entry : targetPerms.entrySet()) {
            Long userId = entry.getKey();
            String perm = entry.getValue();

            ArticlePermission existing = articlePermissionMapper.findByArticleAndUser(articleId, userId);
            if (existing != null) {
                existing.setPermission(perm);
                existing.setGrantedBy(currentUserId);
                existing.setUpdatedAt(LocalDateTime.now());
                articlePermissionMapper.updateById(existing);
                results.add(existing);
            } else {
                ArticlePermission ap = new ArticlePermission();
                ap.setArticleId(articleId);
                ap.setUserId(userId);
                ap.setPermission(perm);
                ap.setGrantedBy(currentUserId);
                articlePermissionMapper.insert(ap);
                results.add(ap);
            }
        }

        return toDTOList(results);
    }

    @Transactional
    public void removePermission(Long articleId, Long userId) {
        Long currentUserId = permissionService.currentUserId();
        if (!canManage(articleId, currentUserId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "无权管理此文章的权限");
        }
        ArticlePermission ap = articlePermissionMapper.findByArticleAndUser(articleId, userId);
        if (ap != null) {
            articlePermissionMapper.deleteById(ap.getId());
        }
    }

    public Map<Long, String> batchQuery(List<Long> articleIds) {
        Long userId = permissionService.currentUserId();
        if (permissionService.isAdmin()) {
            Map<Long, String> result = new HashMap<>();
            for (Long id : articleIds) result.put(id, "MANAGE");
            return result;
        }
        List<ArticlePermission> perms = articlePermissionMapper.listByArticleIds(userId, articleIds);
        Map<Long, String> result = new HashMap<>();
        for (ArticlePermission ap : perms) {
            result.put(ap.getArticleId(), ap.getPermission());
        }
        return result;
    }

    public boolean hasPermission(Long articleId, Long userId, String requiredLevel) {
        String perm = articlePermissionMapper.getPermissionLevel(articleId, userId);
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
        // 按 username 查找
        User target = userMapper.selectActiveByIdentifier(req.getUsername());
        if (target == null) throw new BusinessException(ErrorCode.USER_NOT_FOUND, "用户不存在: " + req.getUsername());
        return target.getId();
    }

    private boolean canManage(Long articleId, Long userId) {
        if (permissionService.isAdmin()) return true;
        return hasPermission(articleId, userId, "MANAGE");
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

    /**
     * 批量构造 DTO，一次性拉取关联用户信息避免 N+1
     */
    private List<PermissionDTO> toDTOList(List<ArticlePermission> perms) {
        if (perms.isEmpty()) return Collections.emptyList();

        Set<Long> allIds = new HashSet<>();
        for (ArticlePermission ap : perms) {
            allIds.add(ap.getUserId());
            allIds.add(ap.getGrantedBy());
        }
        // 批量查用户，一次 SQL 搞定
        List<User> users = userMapper.selectActiveList(
                new LambdaQueryWrapper<User>()
                        .in(User::getId, allIds)
                        .isNull(User::getDeletedAt)
        );
        Map<Long, User> userMap = new HashMap<>();
        for (User u : users) userMap.put(u.getId(), u);

        return perms.stream().map(ap -> {
            PermissionDTO dto = new PermissionDTO();
            dto.setId(ap.getId());
            dto.setResourceId(ap.getArticleId());
            dto.setUserId(ap.getUserId());
            dto.setPermission(ap.getPermission());
            dto.setGrantedBy(ap.getGrantedBy());
            dto.setCreatedAt(ap.getCreatedAt());
            dto.setUpdatedAt(ap.getUpdatedAt());
            User user = userMap.get(ap.getUserId());
            if (user != null) dto.setUsername(user.getUsername());
            User granter = userMap.get(ap.getGrantedBy());
            if (granter != null) dto.setGrantedByName(granter.getUsername());
            return dto;
        }).collect(Collectors.toList());
    }
}
