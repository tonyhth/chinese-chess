package com.kb.comment.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 评论实体。
 * 不使用 @TableLogic，因为查询评论树时需要包含已删除评论（显示占位符）。
 */
@Data
@TableName("kb_comment")
public class Comment {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long articleId;
    private Long parentId;
    private String content;
    private Long authorId;
    private Integer status;
    private Integer depth; // 嵌套层级：0=顶级，1/2/3=回复
    private LocalDateTime deletedAt;
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
