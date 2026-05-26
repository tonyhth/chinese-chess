package com.kb.category.dto;

import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class CategoryUpdateRequest {
    @Size(max = 128, message = "分类名长度不能超过 128")
    private String name;
    private String slug;
    private Long parentId;
    private String description;
    private Integer sortOrder;
}
