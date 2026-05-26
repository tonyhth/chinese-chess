package com.kb.article.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;

@Data
public class ArticleBatchDeleteRequest {
    @NotEmpty(message = "文章ID列表不能为空")
    @Size(max = 100, message = "单次最多操作 100 篇文章")
    private List<Long> ids;
}
