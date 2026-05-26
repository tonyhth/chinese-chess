package com.kb.article.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;

@Data
public class ArticleBatchMoveRequest {
    @NotEmpty(message = "文章ID列表不能为空")
    @Size(max = 100, message = "单次最多操作 100 篇文章")
    private List<Long> ids;

    @NotNull(message = "目标分类ID不能为空")
    private Long categoryId;
}
