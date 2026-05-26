package com.kb.search.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.Instant;
import java.time.LocalDateTime;

@Data
@TableName("es_sync_fail_log")
public class EsSyncFailLog {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String entityType;
    private Long entityId;
    private String operation;
    private String payload;
    private Integer retryCount;
    private Integer status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private LocalDateTime nextRetryAt;
}
