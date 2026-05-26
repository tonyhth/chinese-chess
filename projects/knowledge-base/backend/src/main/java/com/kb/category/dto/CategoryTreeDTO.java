package com.kb.category.dto;

import lombok.Data;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class CategoryTreeDTO {
    private Long id;
    private Long parentId;
    private String name;
    private String slug;
    private String description;
    private Integer sortOrder;
    private LocalDateTime createdAt;
    private List<CategoryTreeDTO> children;
}
