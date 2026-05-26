package com.kb.tag.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class TagCreateRequest {
    @NotBlank(message = "标签名不能为空")
    @Size(max = 64, message = "标签名长度不能超过 64")
    private String name;
    private String color;
}
