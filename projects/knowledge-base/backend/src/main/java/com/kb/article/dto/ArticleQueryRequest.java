package com.kb.article.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.Data;

@Data
public class ArticleQueryRequest {
    private Long categoryId;
    private Long tagId;
    private String status;
    private String keyword;
    @Min(1)
    private Integer page = 1;
    @Min(1) @Max(100)
    private Integer size = 20;
    private String sort = "updated_at";
    private String order = "desc";
}
