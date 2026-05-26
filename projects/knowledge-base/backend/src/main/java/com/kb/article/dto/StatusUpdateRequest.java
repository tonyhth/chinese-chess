package com.kb.article.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

@Data
public class StatusUpdateRequest {
    @NotBlank(message = "状态不能为空")
    @Pattern(regexp = "PUBLISHED|ARCHIVED|DELETED", message = "状态只能是 PUBLISHED、ARCHIVED 或 DELETED")
    private String status;
}
