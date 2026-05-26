package com.kb.tag.dto;

import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class TagUpdateRequest {
    @Size(max = 64, message = "标签名长度不能超过 64")
    private String name;
    private String color;
}
