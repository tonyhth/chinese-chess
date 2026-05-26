package com.kb.article.dto;

import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;

@Data
public class ArticleUpdateRequest {
    @Size(max = 256, message = "标题长度不能超过 256")
    private String title;

    private String slug;

    private String content;

    private String summary;

    private Long categoryId;

    private List<Long> tagIds;
}
