package com.kb.category.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class CategoryCreateRequest {
    @NotBlank(message = "分类名不能为空")
    @Size(max = 128, message = "分类名长度不能超过 128")
    private String name;

    @NotBlank(message = "slug不能为空")
    @Size(max = 128)
    private String slug;

    private Long parentId;
    private String description;
    private Integer sortOrder;
}
