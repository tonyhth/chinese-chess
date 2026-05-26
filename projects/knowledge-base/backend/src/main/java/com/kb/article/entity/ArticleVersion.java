package com.kb.article.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("kb_article_version")
public class ArticleVersion {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long articleId;
    private String title;
    private String content;
    private Integer version;
    private String changeSummary;
    private Long createdBy;
    private LocalDateTime createdAt;
}
