package com.kb.comment.controller;

import com.kb.comment.dto.CommentCreateRequest;
import com.kb.comment.dto.CommentDTO;
import com.kb.comment.service.CommentService;
import com.kb.common.Result;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
@Tag(name = "评论", description = "评论管理")
public class CommentController {

    private final CommentService commentService;

    @GetMapping("/articles/{articleId}/comments")
    @Operation(summary = "获取文章评论列表（平铺，前端组装树）")
    public Result<List<CommentDTO>> listComments(@PathVariable Long articleId) {
        return Result.ok(commentService.listByArticle(articleId));
    }

    @PostMapping("/articles/{articleId}/comments")
    @Operation(summary = "发表评论")
    public Result<CommentDTO> createComment(@PathVariable Long articleId,
                                            @Valid @RequestBody CommentCreateRequest request) {
        return Result.ok(commentService.create(articleId, request));
    }

    @DeleteMapping("/comments/{commentId}")
    @Operation(summary = "删除评论（本人或管理员）")
    public Result<Void> deleteComment(@PathVariable Long commentId) {
        commentService.delete(commentId);
        return Result.ok();
    }
}
