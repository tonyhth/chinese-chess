package com.kb.search.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.Data;

import java.util.List;

@Data
public class SearchRequest {
    @NotBlank(message = "搜索关键词不能为空")
    private String query;

    private Long categoryId;

    private List<String> tagNames;

    private String dateFrom; // yyyy-MM-dd

    private String dateTo;

    private String sort; // relevance | newest | oldest，默认 relevance

    @Min(1)
    private Integer page = 1;

    @Min(1)
    @Max(50)
    private Integer size = 20;

    /**
     * 缓存 key：由所有影响结果的参数组成
     */
    public String cacheKey() {
        StringBuilder sb = new StringBuilder();
        sb.append(query != null ? query : "");
        sb.append("|").append(categoryId != null ? categoryId : "");
        sb.append("|").append(tagNames != null ? String.join(",", tagNames) : "");
        sb.append("|").append(dateFrom != null ? dateFrom : "");
        sb.append("|").append(dateTo != null ? dateTo : "");
        sb.append("|").append(sort != null ? sort : "relevance");
        sb.append("|").append(page);
        sb.append("|").append(size);
        return sb.toString();
    }
}
