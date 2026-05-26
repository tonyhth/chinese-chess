package com.kb.comment.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class CommentCreateRequest {

    @Size(max = 5000, message = "评论内容不能超过 5000 字")
    @NotBlank(message = "评论内容不能为空")
    private String content;

    /** 回复的评论 ID，null 为顶级评论 */
    private Long parentId;
}
