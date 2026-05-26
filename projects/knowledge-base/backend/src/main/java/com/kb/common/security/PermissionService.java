package com.kb.common.security;

import com.kb.article.entity.Article;
import com.kb.article.mapper.ArticleMapper;
import com.kb.auth.security.CustomUserDetails;
import com.kb.common.BusinessException;
import com.kb.common.ErrorCode;
import com.kb.permission.service.ArticlePermissionService;
import com.kb.permission.service.CategoryPermissionService;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Lazy;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

/**
 * 业务级权限校验服务。
 * 方法级角色控制用 @PreAuthorize，
 * 资源级权限（草稿可见性、编辑他人文章、资源权限）在这里处理。
 *
 * 并集策略：角色允许 OR 资源权限允许 → 放行。
 * 资源权限只能放大不能缩小角色权限。
 */
@Component
public class PermissionService {

    private final ArticleMapper articleMapper;
    @Lazy
    private final ArticlePermissionService articlePermissionService;
    @Lazy
    private final CategoryPermissionService categoryPermissionService;

    public PermissionService(ArticleMapper articleMapper,
                             @Lazy ArticlePermissionService articlePermissionService,
                             @Lazy CategoryPermissionService categoryPermissionService) {
        this.articleMapper = articleMapper;
        this.articlePermissionService = articlePermissionService;
        this.categoryPermissionService = categoryPermissionService;
    }

    public CustomUserDetails currentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getPrincipal() == null) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED);
        }
        if (auth.getPrincipal() instanceof CustomUserDetails userDetails) {
            return userDetails;
        }
        throw new BusinessException(ErrorCode.UNAUTHORIZED);
    }

    public Long currentUserId() {
        return currentUser().getId();
    }

    public boolean isAdmin() {
        return "ADMIN".equals(currentUser().getRole());
    }

    public boolean isEditorOrAbove() {
        String role = currentUser().getRole();
        return "ADMIN".equals(role) || "EDITOR".equals(role);
    }

    /**
     * 校验文章可见性：
     * - 已发布：所有人可见
     * - 归档：ADMIN 或有 VIEW 权限
     * - 草稿：作者、ADMIN 或有 VIEW 权限
     */
    public Article checkArticleVisible(Long articleId) {
        Article article = articleMapper.selectActiveById(articleId);
        if (article == null) {
            throw new BusinessException(ErrorCode.ARTICLE_NOT_FOUND);
        }

        String status = article.getStatus();
        if ("PUBLISHED".equals(status)) {
            return article;
        }

        Long userId = currentUserId();

        if ("ARCHIVED".equals(status)) {
            // 并集：ADMIN OR 资源权限
            if (isAdmin() || articlePermissionService.hasPermission(articleId, userId, "VIEW")) {
                return article;
            }
            throw new BusinessException(ErrorCode.FORBIDDEN, "无权查看归档文章");
        }

        if ("DRAFT".equals(status)) {
            if (isAdmin()
                    || article.getAuthorId().equals(userId)
                    || articlePermissionService.hasPermission(articleId, userId, "VIEW")) {
                return article;
            }
            throw new BusinessException(ErrorCode.FORBIDDEN, "无权查看该草稿");
        }

        return article;
    }

    /**
     * 校验文章编辑权限（并集策略）：
     * - ADMIN：可编辑所有
     * - EDITOR 且是作者：可编辑
     * - 有 EDIT 资源权限：可编辑
     */
    public Article checkArticleEditable(Long articleId) {
        Article article = articleMapper.selectActiveById(articleId);
        if (article == null) {
            throw new BusinessException(ErrorCode.ARTICLE_NOT_FOUND);
        }

        Long userId = currentUserId();
        // 并集：角色允许 OR 资源权限允许
        if (isAdmin()
                || article.getAuthorId().equals(userId)
                || articlePermissionService.hasPermission(articleId, userId, "EDIT")) {
            return article;
        }
        throw new BusinessException(ErrorCode.FORBIDDEN, "只能编辑自己的文章");
    }

    /**
     * 校验文章删除权限（并集策略）：
     * - ADMIN：可删除所有
     * - EDITOR 且是作者：可删除
     * - 有 MANAGE 资源权限：可删除
     */
    public Article checkArticleDeletable(Long articleId) {
        Article article = articleMapper.selectActiveById(articleId);
        if (article == null) {
            throw new BusinessException(ErrorCode.ARTICLE_NOT_FOUND);
        }

        Long userId = currentUserId();
        if (isAdmin()
                || article.getAuthorId().equals(userId)
                || articlePermissionService.hasPermission(articleId, userId, "MANAGE")) {
            return article;
        }
        throw new BusinessException(ErrorCode.FORBIDDEN, "无权删除此文章");
    }

    /**
     * 校验文章状态变更权限（需要 MANAGE）
     */
    public Article checkArticleStatusChangeable(Long articleId) {
        Article article = articleMapper.selectActiveById(articleId);
        if (article == null) {
            throw new BusinessException(ErrorCode.ARTICLE_NOT_FOUND);
        }
        Long userId = currentUserId();
        if (isAdmin()
                || article.getAuthorId().equals(userId)
                || articlePermissionService.hasPermission(articleId, userId, "MANAGE")) {
            return article;
        }
        throw new BusinessException(ErrorCode.FORBIDDEN, "无权变更此文章状态");
    }

    /**
     * 校验分类编辑权限（并集策略）
     */
    public void checkCategoryEditable(Long categoryId) {
        Long userId = currentUserId();
        if (isAdmin() || categoryPermissionService.hasPermission(categoryId, userId, "EDIT")) {
            return;
        }
        throw new BusinessException(ErrorCode.FORBIDDEN, "无权编辑此分类");
    }

    /**
     * 校验分类/标签删除权限：仅 ADMIN
     */
    public void checkAdminOnly() {
        if (!isAdmin()) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "仅管理员可执行此操作");
        }
    }

    public void checkCommentDeletable(Long authorId) {
        if (!isAdmin() && !currentUserId().equals(authorId)) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "只能删除自己的评论");
        }
    }
}
