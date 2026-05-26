package com.kb.article.dto;

import lombok.Data;
import java.time.LocalDateTime;

@Data
public class ArticleVersionDTO {
    private Long id;
    private Long articleId;
    private String title;
    private String content;
    private Integer version;
    private String changeSummary;
    private Long createdBy;
    private String createdByName;
    private LocalDateTime createdAt;
}
