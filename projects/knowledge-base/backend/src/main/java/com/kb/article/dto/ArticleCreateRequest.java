package com.kb.article.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;

@Data
public class ArticleCreateRequest {
    @NotBlank(message = "标题不能为空")
    @Size(max = 256, message = "标题长度不能超过 256")
    private String title;

    private String slug;

    @NotBlank(message = "内容不能为空")
    private String content;

    private String summary;

    private Long categoryId;

    private List<Long> tagIds;

    /** DRAFT 或 PUBLISHED，默认 DRAFT */
    private String status;
}
