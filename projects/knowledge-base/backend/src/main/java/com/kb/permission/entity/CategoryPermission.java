package com.kb.permission.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("kb_category_permission")
public class CategoryPermission {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long categoryId;
    private Long userId;
    private String permission;  // VIEW | EDIT | MANAGE
    private Long grantedBy;
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
