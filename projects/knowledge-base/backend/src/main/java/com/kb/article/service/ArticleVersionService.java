package com.kb.article.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.kb.article.dto.ArticleVersionDTO;
import com.kb.article.entity.Article;
import com.kb.article.entity.ArticleVersion;
import com.kb.article.mapper.ArticleMapper;
import com.kb.article.mapper.ArticleVersionMapper;
import com.kb.common.BusinessException;
import com.kb.common.ErrorCode;
import com.kb.common.security.PermissionService;
import com.kb.user.entity.User;
import com.kb.user.mapper.UserMapper;
import com.kb.search.event.ArticleChangeEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class ArticleVersionService {

    private final ArticleVersionMapper versionMapper;
    private final ArticleMapper articleMapper;
    private final UserMapper userMapper;
    private final PermissionService permissionService;
    private final ApplicationEventPublisher eventPublisher;

    private static final int MAX_VERSION_LIST_SIZE = 200;

    public List<ArticleVersionDTO> listVersions(Long articleId) {
        ensureArticleExists(articleId);

        LambdaQueryWrapper<ArticleVersion> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(ArticleVersion::getArticleId, articleId)
                .orderByDesc(ArticleVersion::getVersion)
                .last("LIMIT " + MAX_VERSION_LIST_SIZE);

        List<ArticleVersion> versions = versionMapper.selectList(wrapper);
        return batchToDTO(versions);
    }

    public ArticleVersionDTO getVersion(Long articleId, Integer version) {
        ensureArticleExists(articleId);

        ArticleVersion v = versionMapper.selectOne(
                new LambdaQueryWrapper<ArticleVersion>()
                        .eq(ArticleVersion::getArticleId, articleId)
                        .eq(ArticleVersion::getVersion, version));
        if (v == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "版本不存在");
        }
        return toDTO(v);
    }

    /**
     * 回滚到指定版本（乐观锁）
     */
    @Transactional
    public ArticleVersionDTO restoreVersion(Long articleId, Integer targetVersion) {
        Article article = permissionService.checkArticleEditable(articleId);

        ArticleVersion target = versionMapper.selectOne(
                new LambdaQueryWrapper<ArticleVersion>()
                        .eq(ArticleVersion::getArticleId, articleId)
                        .eq(ArticleVersion::getVersion, targetVersion));
        if (target == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "版本不存在");
        }

        int currentVersion = article.getVersion();
        int newVersion = currentVersion + 1;

        // 幂等保存当前状态为版本快照
        Long existing = versionMapper.selectCount(
                new LambdaQueryWrapper<ArticleVersion>()
                        .eq(ArticleVersion::getArticleId, articleId)
                        .eq(ArticleVersion::getVersion, currentVersion));
        if (existing == 0) {
            ArticleVersion snapshot = new ArticleVersion();
            snapshot.setArticleId(articleId);
            snapshot.setTitle(article.getTitle());
            snapshot.setContent(article.getContent());
            snapshot.setVersion(currentVersion);
            snapshot.setCreatedBy(permissionService.currentUserId());
            snapshot.setChangeSummary("回滚前自动快照，回滚到版本 " + targetVersion);
            versionMapper.insert(snapshot);
        }

        // 乐观锁更新：WHERE id=? AND version=?
        int updated = articleMapper.updateVersionAndContent(
                articleId, currentVersion,
                target.getTitle(), target.getContent(),
                null, null, null, newVersion);
        if (updated == 0) {
            throw new BusinessException(ErrorCode.CONFLICT,
                    "文章已被其他人修改，回滚冲突，请刷新后重试");
        }

        log.info("[VERSION] articleId={} restore v{}→v{} by userId={}",
                articleId, currentVersion, newVersion, permissionService.currentUserId());

        // 发布双写事件
        eventPublisher.publishEvent(new ArticleChangeEvent("article", articleId, "UPDATE"));

        // 返回回滚后的最新版本（newVersion），而非快照
        ArticleVersion restoredVersion = new ArticleVersion();
        restoredVersion.setArticleId(articleId);
        restoredVersion.setTitle(target.getTitle());
        restoredVersion.setContent(target.getContent());
        restoredVersion.setVersion(newVersion);
        restoredVersion.setChangeSummary("回滚到版本 " + targetVersion);
        restoredVersion.setCreatedBy(permissionService.currentUserId());
        restoredVersion.setCreatedAt(java.time.LocalDateTime.now());
        return toDTO(restoredVersion);
    }

    private void ensureArticleExists(Long articleId) {
        Article article = articleMapper.selectById(articleId);
        if (article == null || article.getDeletedAt() != null) {
            throw new BusinessException(ErrorCode.ARTICLE_NOT_FOUND);
        }
    }

    private ArticleVersionDTO toDTO(ArticleVersion v) {
        return toDTO(v, null);
    }

    private ArticleVersionDTO toDTO(ArticleVersion v, String userName) {
        ArticleVersionDTO dto = new ArticleVersionDTO();
        dto.setId(v.getId());
        dto.setArticleId(v.getArticleId());
        dto.setTitle(v.getTitle());
        dto.setContent(v.getContent());
        dto.setVersion(v.getVersion());
        dto.setChangeSummary(v.getChangeSummary());
        dto.setCreatedBy(v.getCreatedBy());
        dto.setCreatedAt(v.getCreatedAt());
        dto.setCreatedByName(userName);
        return dto;
    }

    private List<ArticleVersionDTO> batchToDTO(List<ArticleVersion> versions) {
        if (versions.isEmpty()) return List.of();

        List<Long> userIds = versions.stream()
                .map(ArticleVersion::getCreatedBy)
                .filter(id -> id != null)
                .distinct()
                .collect(Collectors.toList());

        java.util.Map<Long, String> userNameMap = java.util.Collections.emptyMap();
        if (!userIds.isEmpty()) {
            userNameMap = userMapper.selectBatchIds(userIds).stream()
                    .collect(Collectors.toMap(
                            User::getId,
                            User::getUsername,
                            (a, b) -> a));
        }

        java.util.Map<Long, String> finalMap = userNameMap;
        return versions.stream()
                .map(v -> toDTO(v, finalMap.getOrDefault(v.getCreatedBy(), null)))
                .collect(Collectors.toList());
    }
}
