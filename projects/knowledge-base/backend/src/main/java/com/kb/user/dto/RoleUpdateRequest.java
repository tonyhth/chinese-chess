package com.kb.user.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class RoleUpdateRequest {
    @NotBlank(message = "角色不能为空")
    private String role;
}
