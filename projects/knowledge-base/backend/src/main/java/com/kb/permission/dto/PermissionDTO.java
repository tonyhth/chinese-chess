package com.kb.permission.dto;

import lombok.Data;
import java.time.LocalDateTime;

@Data
public class PermissionDTO {
    private Long id;
    private Long resourceId;   // articleId or categoryId
    private Long userId;
    private String username;
    private String permission; // VIEW | EDIT | MANAGE
    private Long grantedBy;
    private String grantedByName;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
