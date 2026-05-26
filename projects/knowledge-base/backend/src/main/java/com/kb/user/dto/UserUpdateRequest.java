package com.kb.user.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class UserUpdateRequest {
    @Size(max = 64, message = "用户名不能超过 64 字符")
    private String username;

    @Email(message = "邮箱格式不正确")
    private String email;

    private String avatarUrl;
}
