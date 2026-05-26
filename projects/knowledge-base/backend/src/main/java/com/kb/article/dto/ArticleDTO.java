package com.kb.article.dto;

import lombok.Data;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class ArticleDTO {
    private Long id;
    private String title;
    private String slug;
    private String summary;
    private String content;
    private String contentHtml;
    private Long categoryId;
    private String categoryName;
    private Long authorId;
    private String authorName;
    private String status;
    private Integer viewCount;
    private Integer version;
    private List<TagRef> tags;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    @Data
    public static class TagRef {
        private Long id;
        private String name;
        private String color;
    }
}
