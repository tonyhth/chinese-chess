package com.kb.user.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("sys_user")
public class User {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String username;
    private String passwordHash;
    private String email;
    private String avatarUrl;
    private String role;
    private Integer status;
    private LocalDateTime deletedAt;
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
    // updated_at 由数据库触发器维护
    // 注意：不使用 @TableLogic，软删除通过 Mapper 自定义 SQL (WHERE deleted_at IS NULL) 控制
}
