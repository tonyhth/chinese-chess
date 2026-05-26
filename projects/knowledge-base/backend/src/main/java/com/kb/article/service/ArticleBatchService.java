package com.kb.article.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.kb.article.dto.ArticleBatchDeleteRequest;
import com.kb.article.dto.ArticleBatchMoveRequest;
import com.kb.article.dto.ArticleBatchResult;
import com.kb.article.dto.ArticleBatchTagRequest;
import com.kb.article.entity.Article;
import com.kb.article.mapper.ArticleMapper;
import com.kb.article.mapper.ArticleTagMapper;
import com.kb.category.mapper.CategoryMapper;
import com.kb.common.BusinessException;
import com.kb.common.ErrorCode;
import com.kb.common.security.PermissionService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class ArticleBatchService {

    private final ArticleMapper articleMapper;
    private final ArticleTagMapper articleTagMapper;
    private final CategoryMapper categoryMapper;
    private final PermissionService permissionService;

    @Transactional
    public ArticleBatchResult batchDelete(ArticleBatchDeleteRequest request) {
        permissionService.isEditorOrAbove();
        Long userId = permissionService.currentUserId();
        boolean isAdmin = permissionService.isAdmin();
        int success = 0;
        List<Long> failed = new ArrayList<>();

        for (Long id : request.getIds()) {
            try {
                Article article = articleMapper.selectActiveById(id);
                if (article == null) {
                    failed.add(id);
                    continue;
                }
                if (!isAdmin && !article.getAuthorId().equals(userId)) {
                    failed.add(id);
                    continue;
                }
                article.setDeletedAt(LocalDateTime.now());
                articleMapper.updateById(article);
                success++;
            } catch (DataAccessException e) {
                // 数据库系统性错误，快速失败回滚事务
                log.error("批量删除遇到数据库异常: {}", e.getMessage());
                throw new BusinessException(ErrorCode.INTERNAL_ERROR, "数据库操作失败");
            } catch (Exception e) {
                log.warn("批量删除文章 {} 失败: {}", id, e.getMessage());
                failed.add(id);
            }
        }
        log.info("批量删除文章: 成功 {} 失败 {}", success, failed.size());
        return failed.isEmpty() ? ArticleBatchResult.allSuccess(success)
                : ArticleBatchResult.partial(success, failed);
    }

    @Transactional
    public ArticleBatchResult batchMove(ArticleBatchMoveRequest request) {
        permissionService.isEditorOrAbove();
        if (categoryMapper.selectById(request.getCategoryId()) == null) {
            throw new BusinessException(ErrorCode.CATEGORY_NOT_FOUND);
        }
        Long userId = permissionService.currentUserId();
        boolean isAdmin = permissionService.isAdmin();
        int success = 0;
        List<Long> failed = new ArrayList<>();

        for (Long id : request.getIds()) {
            try {
                Article article = articleMapper.selectActiveById(id);
                if (article == null) {
                    failed.add(id);
                    continue;
                }
                if (!isAdmin && !article.getAuthorId().equals(userId)) {
                    failed.add(id);
                    continue;
                }
                article.setCategoryId(request.getCategoryId());
                articleMapper.updateById(article);
                success++;
            } catch (DataAccessException e) {
                log.error("批量移动遇到数据库异常: {}", e.getMessage());
                throw new BusinessException(ErrorCode.INTERNAL_ERROR, "数据库操作失败");
            } catch (Exception e) {
                log.warn("批量移动文章 {} 失败: {}", id, e.getMessage());
                failed.add(id);
            }
        }
        log.info("批量移动文章到分类 {}: 成功 {} 失败 {}", request.getCategoryId(), success, failed.size());
        return failed.isEmpty() ? ArticleBatchResult.allSuccess(success)
                : ArticleBatchResult.partial(success, failed);
    }

    @Transactional
    public ArticleBatchResult batchTag(ArticleBatchTagRequest request) {
        permissionService.isEditorOrAbove();
        Long userId = permissionService.currentUserId();
        boolean isAdmin = permissionService.isAdmin();
        int success = 0;
        List<Long> failed = new ArrayList<>();

        for (Long id : request.getIds()) {
            try {
                Article article = articleMapper.selectActiveById(id);
                if (article == null) {
                    failed.add(id);
                    continue;
                }
                // 非 ADMIN 只能给自己的文章打标签
                if (!isAdmin && !article.getAuthorId().equals(userId)) {
                    failed.add(id);
                    continue;
                }
                for (Long tagId : request.getTagIds()) {
                    articleTagMapper.insertIfNotExists(id, tagId);
                }
                success++;
            } catch (DataAccessException e) {
                log.error("批量打标签遇到数据库异常: {}", e.getMessage());
                throw new BusinessException(ErrorCode.INTERNAL_ERROR, "数据库操作失败");
            } catch (Exception e) {
                log.warn("批量打标签文章 {} 失败: {}", id, e.getMessage());
                failed.add(id);
            }
        }
        log.info("批量打标签: 成功 {} 失败 {}", success, failed.size());
        return failed.isEmpty() ? ArticleBatchResult.allSuccess(success)
                : ArticleBatchResult.partial(success, failed);
    }
}
