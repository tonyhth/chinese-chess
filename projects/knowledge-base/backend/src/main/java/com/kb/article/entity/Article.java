package com.kb.article.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("kb_article")
public class Article {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String title;
    private String slug;
    private String content;
    private String contentHtml;
    private String summary;
    private Long categoryId;
    private Long authorId;
    private String status;
    private Integer viewCount;
    private Integer version;
    private LocalDateTime deletedAt;
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
    // updated_at 由数据库触发器维护
    // 注意：不使用 @TableLogic，软删除通过 Mapper 自定义 SQL (WHERE deleted_at IS NULL) 控制
}
