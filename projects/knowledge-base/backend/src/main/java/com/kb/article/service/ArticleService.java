package com.kb.article.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.kb.article.dto.*;
import com.kb.article.entity.Article;
import com.kb.article.entity.ArticleVersion;
import com.kb.article.mapper.ArticleMapper;
import com.kb.article.mapper.ArticleTagMapper;
import com.kb.article.mapper.ArticleVersionMapper;
import com.kb.category.entity.Category;
import com.kb.category.mapper.CategoryMapper;
import com.kb.common.BusinessException;
import com.kb.common.ErrorCode;
import com.kb.common.PageResult;
import com.kb.common.security.PermissionService;
import com.kb.search.event.ArticleChangeEvent;
import com.kb.tag.entity.Tag;
import com.kb.tag.mapper.TagMapper;
import com.kb.user.entity.User;
import com.kb.user.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.CollectionUtils;
import org.springframework.util.StringUtils;

import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class ArticleService {

    private final ArticleMapper articleMapper;
    private final ArticleTagMapper articleTagMapper;
    private final ArticleVersionMapper articleVersionMapper;
    private final CategoryMapper categoryMapper;
    private final TagMapper tagMapper;
    private final UserMapper userMapper;
    private final PermissionService permissionService;
    private final ApplicationEventPublisher eventPublisher;

    @Transactional
    public ArticleDTO create(ArticleCreateRequest request) {
        permissionService.isEditorOrAbove();

        Article article = new Article();
        article.setTitle(request.getTitle());
        article.setSlug(request.getSlug());
        article.setContent(request.getContent());
        article.setSummary(request.getSummary());
        article.setCategoryId(request.getCategoryId());
        article.setAuthorId(permissionService.currentUserId());
        article.setStatus(StringUtils.hasText(request.getStatus()) ? request.getStatus() : "DRAFT");
        article.setViewCount(0);
        article.setVersion(1);
        articleMapper.insert(article);

        // 保存标签关联
        saveTags(article.getId(), request.getTagIds());

        // 创建初始版本
        saveVersion(article);

        // 发布双写事件
        eventPublisher.publishEvent(new ArticleChangeEvent("article", article.getId(), "CREATE"));

        return toDTO(article);
    }

    public PageResult<ArticleDTO> list(ArticleQueryRequest query) {
        Long userId = permissionService.currentUserId();
        String role = permissionService.currentUser().getRole();

        Page<Article> page = new Page<>(query.getPage(), query.getSize());
        LambdaQueryWrapper<Article> wrapper = new LambdaQueryWrapper<>();
        wrapper.isNull(Article::getDeletedAt);

        // 权限过滤
        if ("ADMIN".equals(role)) {
            if (StringUtils.hasText(query.getStatus())) {
                wrapper.eq(Article::getStatus, query.getStatus());
            }
        } else {
            wrapper.and(w -> w
                    .eq(Article::getStatus, "PUBLISHED")
                    .or(o -> o.eq(Article::getAuthorId, userId)
                            .in(Article::getStatus, "DRAFT", "PUBLISHED")));
        }

        if (query.getCategoryId() != null) {
            wrapper.eq(Article::getCategoryId, query.getCategoryId());
        }
        if (query.getTagId() != null) {
            List<Long> articleIdsByTag = articleTagMapper.selectArticleIdsByTagId(query.getTagId());
            if (articleIdsByTag.isEmpty()) {
                return new PageResult<>(List.of(), 0, query.getPage(), query.getSize());
            }
            wrapper.in(Article::getId, articleIdsByTag);
        }
        if (StringUtils.hasText(query.getKeyword())) {
            wrapper.and(w -> w
                    .like(Article::getTitle, query.getKeyword())
                    .or().like(Article::getSummary, query.getKeyword()));
        }

        // 排序
        if ("created_at".equals(query.getSort())) {
            wrapper.orderBy(true, "asc".equals(query.getOrder()), Article::getCreatedAt);
        } else {
            wrapper.orderBy(true, "asc".equals(query.getOrder()), Article::getUpdatedAt);
        }

        Page<Article> result = articleMapper.selectPage(page, wrapper);
        List<ArticleDTO> records = result.getRecords().stream()
                .map(this::toDTO)
                .collect(Collectors.toList());

        return new PageResult<>(records, result.getTotal(), query.getPage(), query.getSize());
    }

    public ArticleDTO getById(Long id) {
        Article article = permissionService.checkArticleVisible(id);
        return toFullDTO(article);
    }

    @Transactional
    public ArticleDTO update(Long id, ArticleUpdateRequest request) {
        Article article = permissionService.checkArticleEditable(id);

        // 保存旧版本
        saveVersion(article);

        if (StringUtils.hasText(request.getTitle())) {
            article.setTitle(request.getTitle());
        }
        if (request.getSlug() != null) {
            if (!request.getSlug().equals(article.getSlug())) {
                long count = articleMapper.selectCount(
                        new LambdaQueryWrapper<Article>()
                                .eq(Article::getSlug, request.getSlug())
                                .isNull(Article::getDeletedAt)
                                .ne(Article::getId, id));
                if (count > 0) {
                    throw new BusinessException(ErrorCode.CONFLICT, "slug 已被使用");
                }
            }
            article.setSlug(request.getSlug());
        }
        if (StringUtils.hasText(request.getContent())) {
            article.setContent(request.getContent());
        }
        if (request.getSummary() != null) {
            article.setSummary(request.getSummary());
        }
        if (request.getCategoryId() != null) {
            article.setCategoryId(request.getCategoryId());
        }
        article.setVersion(article.getVersion() + 1);

        // 乐观锁更新：WHERE id=? AND version=?
        int updated = articleMapper.updateVersionAndContent(
                id, article.getVersion() - 1,
                article.getTitle(), article.getContent(),
                article.getSummary(), article.getCategoryId(),
                article.getSlug(), article.getVersion());
        if (updated == 0) {
            throw new BusinessException(ErrorCode.CONFLICT,
                    "文章已被其他人修改，请刷新后重试");
        }

        // 更新标签关联
        if (request.getTagIds() != null) {
            articleTagMapper.deleteByArticleId(id);
            saveTags(id, request.getTagIds());
        }

        // 发布双写事件
        eventPublisher.publishEvent(new ArticleChangeEvent("article", id, "UPDATE"));

        return toDTO(article);
    }

    @Transactional
    public ArticleDTO updateStatus(Long id, StatusUpdateRequest request) {
        if ("DELETED".equals(request.getStatus())) {
            Article article = permissionService.checkArticleDeletable(id);
            article.setDeletedAt(java.time.LocalDateTime.now());
            articleMapper.updateById(article);

            // 发布双写事件（删除）
            eventPublisher.publishEvent(new ArticleChangeEvent("article", id, "DELETE"));
            return toDTO(article);
        } else {
            // 状态变更需要 MANAGE 权限（并集策略）
            Article article = permissionService.checkArticleStatusChangeable(id);
            article.setStatus(request.getStatus());
            articleMapper.updateById(article);

            // 发布双写事件（更新）
            eventPublisher.publishEvent(new ArticleChangeEvent("article", id, "UPDATE"));
            return toDTO(article);
        }
    }

    // --- private helpers ---

    private void saveTags(Long articleId, List<Long> tagIds) {
        if (CollectionUtils.isEmpty(tagIds)) return;
        articleTagMapper.deleteByArticleId(articleId);
        for (Long tagId : tagIds) {
            com.kb.article.entity.ArticleTag at = new com.kb.article.entity.ArticleTag();
            at.setArticleId(articleId);
            at.setTagId(tagId);
            articleTagMapper.insert(at);
        }
    }

    private void saveVersion(Article article) {
        Long existing = articleVersionMapper.selectCount(
                new LambdaQueryWrapper<ArticleVersion>()
                        .eq(ArticleVersion::getArticleId, article.getId())
                        .eq(ArticleVersion::getVersion, article.getVersion()));
        if (existing > 0) return;

        ArticleVersion version = new ArticleVersion();
        version.setArticleId(article.getId());
        version.setTitle(article.getTitle());
        version.setContent(article.getContent());
        version.setVersion(article.getVersion());
        version.setCreatedBy(permissionService.currentUserId());
        articleVersionMapper.insert(version);
    }

    private ArticleDTO toDTO(Article article) {
        ArticleDTO dto = new ArticleDTO();
        dto.setId(article.getId());
        dto.setTitle(article.getTitle());
        dto.setSlug(article.getSlug());
        dto.setSummary(article.getSummary());
        dto.setCategoryId(article.getCategoryId());
        dto.setAuthorId(article.getAuthorId());
        dto.setStatus(article.getStatus());
        dto.setViewCount(article.getViewCount());
        dto.setVersion(article.getVersion());
        dto.setCreatedAt(article.getCreatedAt());
        dto.setUpdatedAt(article.getUpdatedAt());

        // 分类名
        if (article.getCategoryId() != null) {
            Category cat = categoryMapper.selectById(article.getCategoryId());
            if (cat != null) dto.setCategoryName(cat.getName());
        }
        // 标签
        List<Long> tagIds = articleTagMapper.selectTagIdsByArticleId(article.getId());
        if (!tagIds.isEmpty()) {
            dto.setTags(tagMapper.selectBatchIds(tagIds).stream().map(t -> {
                ArticleDTO.TagRef ref = new ArticleDTO.TagRef();
                ref.setId(t.getId());
                ref.setName(t.getName());
                ref.setColor(t.getColor());
                return ref;
            }).collect(Collectors.toList()));
        }
        return dto;
    }

    private ArticleDTO toFullDTO(Article article) {
        ArticleDTO dto = toDTO(article);
        dto.setContent(article.getContent());
        dto.setContentHtml(article.getContentHtml());

        // 作者名
        User author = userMapper.selectActiveById(article.getAuthorId());
        if (author != null) dto.setAuthorName(author.getUsername());
        return dto;
    }
}
