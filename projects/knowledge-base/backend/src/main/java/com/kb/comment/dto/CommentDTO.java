package com.kb.comment.dto;

import lombok.Data;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class CommentDTO {
    private Long id;
    private Long articleId;
    private Long parentId;
    private String content;
    private Long authorId;
    private String authorName;
    private String authorAvatar;
    private Integer status;
    private Integer depth;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    /** 嵌套回复（仅 CTE 查询返回时前端用于组装树） */
    private List<CommentDTO> replies;
}
