package com.kb.permission.dto;

import lombok.Data;

@Data
public class PermissionGrantRequest {
    private Long userId;
    private String username;  // userId 和 username 至少提供一个
    private String permission;  // VIEW | EDIT | MANAGE

    public boolean hasIdentifier() {
        return userId != null || (username != null && !username.isBlank());
    }
}
