package com.kb.comment.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.kb.comment.dto.CommentCreateRequest;
import com.kb.comment.dto.CommentDTO;
import com.kb.comment.entity.Comment;
import com.kb.comment.mapper.CommentMapper;
import com.kb.common.BusinessException;
import com.kb.common.ErrorCode;
import com.kb.common.security.PermissionService;
import com.kb.article.mapper.ArticleMapper;
import com.kb.article.entity.Article;
import com.kb.user.entity.User;
import com.kb.user.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class CommentService {

    private final CommentMapper commentMapper;
    private final UserMapper userMapper;
    private final ArticleMapper articleMapper;
    private final PermissionService permissionService;

    private static final int MAX_DEPTH = 2; // depth 0/1/2 = 3层嵌套

    public List<CommentDTO> listByArticle(Long articleId) {
        ensureArticleExists(articleId);
        List<Comment> comments = commentMapper.selectCommentTree(articleId);
        if (comments.isEmpty()) return List.of();
        return batchToDTO(comments);
    }

    @Transactional
    public CommentDTO create(Long articleId, CommentCreateRequest request) {
        permissionService.currentUserId();
        ensureArticleExists(articleId);

        int depth = 0;
        if (request.getParentId() != null) {
            Comment parent = commentMapper.selectById(request.getParentId());
            if (parent == null || !parent.getArticleId().equals(articleId)) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "回复的评论不存在");
            }
            // depth 冗余字段，O(1) 层级判断
            depth = parent.getDepth() + 1;
            if (depth > MAX_DEPTH) {
                throw new BusinessException(ErrorCode.COMMENT_DEPTH_EXCEEDED,
                        "评论最多支持 3 层嵌套");
            }
        }

        Comment comment = new Comment();
        comment.setArticleId(articleId);
        comment.setParentId(request.getParentId());
        comment.setContent(sanitizeContent(request.getContent()));
        comment.setAuthorId(permissionService.currentUserId());
        comment.setStatus(1);
        comment.setDepth(depth);
        commentMapper.insert(comment);

        return toDTO(comment);
    }

    @Transactional
    public void delete(Long commentId) {
        Comment comment = commentMapper.selectById(commentId);
        if (comment == null) {
            throw new BusinessException(ErrorCode.COMMENT_NOT_FOUND);
        }
        if (comment.getStatus() == 0) {
            return;
        }
        permissionService.checkCommentDeletable(comment.getAuthorId());

        List<Long> descendantIds = commentMapper.selectDescendantIds(commentId);
        if (!descendantIds.isEmpty()) {
            commentMapper.batchSoftDelete(descendantIds);
        }

        comment.setStatus(0);
        comment.setDeletedAt(LocalDateTime.now());
        commentMapper.updateById(comment);
    }

    private void ensureArticleExists(Long articleId) {
        Article article = articleMapper.selectActiveById(articleId);
        if (article == null) {
            throw new BusinessException(ErrorCode.ARTICLE_NOT_FOUND);
        }
    }

    private String sanitizeContent(String content) {
        if (content == null) return null;
        String sanitized = content.replaceAll("(?is)<script[^>]*>.*?</script>", "");
        sanitized = sanitized.replaceAll("(?is)<script[^>]*/>", "");
        sanitized = sanitized.replaceAll("(?i)\\s+on\\w+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^>\\s]+)", "");
        sanitized = sanitized.replaceAll("(?i)javascript\\s*:", "");
        return sanitized;
    }

    private CommentDTO toDTO(Comment c) {
        CommentDTO dto = new CommentDTO();
        dto.setId(c.getId());
        dto.setArticleId(c.getArticleId());
        dto.setParentId(c.getParentId());
        dto.setContent(c.getStatus() == 0 ? "该评论已删除" : c.getContent());
        dto.setAuthorId(c.getAuthorId());
        dto.setStatus(c.getStatus());
        dto.setDepth(c.getDepth());
        dto.setCreatedAt(c.getCreatedAt());
        dto.setUpdatedAt(c.getUpdatedAt());

        if (c.getStatus() == 0) {
            dto.setAuthorName("匿名用户");
        } else if (c.getAuthorId() != null) {
            User user = userMapper.selectActiveById(c.getAuthorId());
            if (user != null) {
                dto.setAuthorName(user.getUsername());
                dto.setAuthorAvatar(user.getAvatarUrl());
            }
        }
        return dto;
    }

    private List<CommentDTO> batchToDTO(List<Comment> comments) {
        if (comments.isEmpty()) return List.of();

        Set<Long> userIds = comments.stream()
                .filter(c -> c.getStatus() == 1 && c.getAuthorId() != null)
                .map(Comment::getAuthorId)
                .collect(Collectors.toSet());

        Map<Long, User> userMap;
        if (!userIds.isEmpty()) {
            userMap = userMapper.selectBatchIds(userIds).stream()
                    .collect(Collectors.toMap(User::getId, u -> u, (a, b) -> a));
        } else {
            userMap = Map.of();
        }

        return comments.stream().map(c -> {
            CommentDTO dto = new CommentDTO();
            dto.setId(c.getId());
            dto.setArticleId(c.getArticleId());
            dto.setParentId(c.getParentId());
            dto.setContent(c.getStatus() == 0 ? "该评论已删除" : c.getContent());
            dto.setAuthorId(c.getAuthorId());
            dto.setStatus(c.getStatus());
            dto.setDepth(c.getDepth());
            dto.setCreatedAt(c.getCreatedAt());
            dto.setUpdatedAt(c.getUpdatedAt());

            if (c.getStatus() == 0) {
                dto.setAuthorName("匿名用户");
            } else if (c.getAuthorId() != null) {
                User user = userMap.get(c.getAuthorId());
                if (user != null) {
                    dto.setAuthorName(user.getUsername());
                    dto.setAuthorAvatar(user.getAvatarUrl());
                }
            }
            return dto;
        }).collect(Collectors.toList());
    }
}
