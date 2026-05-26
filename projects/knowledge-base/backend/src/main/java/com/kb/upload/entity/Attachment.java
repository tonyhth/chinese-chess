package com.kb.upload.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("kb_attachment")
public class Attachment {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long articleId;
    private String fileName;
    private String filePath;
    private Long fileSize;
    private String mimeType;
    private Long uploadUserId;
    /** 前端幂等去重标识 */
    private String clientId;
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
}
