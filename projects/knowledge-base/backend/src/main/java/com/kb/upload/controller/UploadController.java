package com.kb.upload.controller;

import com.kb.common.Result;
import com.kb.upload.dto.UploadDTO;
import com.kb.upload.service.UploadService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@ConditionalOnProperty(name = "minio.enabled", havingValue = "true", matchIfMissing = true)
@RequestMapping("/api/v1")
@RequiredArgsConstructor
@Tag(name = "上传", description = "文件上传与附件管理")
public class UploadController {

    private final UploadService uploadService;

    @PostMapping("/upload/image")
    @Operation(summary = "上传图片（5MB，JPG/PNG/GIF/WebP）")
    @PreAuthorize("hasAnyRole('ADMIN', 'EDITOR')")
    public Result<UploadDTO> uploadImage(
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "client_id", required = false) String clientId) {
        return Result.ok(uploadService.uploadImage(file, clientId));
    }

    @PostMapping("/upload/file")
    @Operation(summary = "上传附件（50MB，PDF/DOC/XLSX/PPTX/ZIP/TAR.GZ）")
    @PreAuthorize("hasAnyRole('ADMIN', 'EDITOR')")
    public Result<UploadDTO> uploadFile(
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "client_id", required = false) String clientId) {
        return Result.ok(uploadService.uploadFile(file, clientId));
    }

    @GetMapping("/articles/{articleId}/attachments")
    @Operation(summary = "获取文章附件列表")
    public Result<List<UploadDTO>> listAttachments(@PathVariable Long articleId) {
        return Result.ok(uploadService.listByArticle(articleId));
    }

    @PostMapping("/attachments/{id}/link")
    @Operation(summary = "关联附件到文章")
    @PreAuthorize("hasAnyRole('ADMIN', 'EDITOR')")
    public Result<Void> linkAttachment(@PathVariable Long id, @RequestParam Long articleId) {
        uploadService.linkToArticle(id, articleId);
        return Result.ok();
    }

    @DeleteMapping("/attachments/{id}")
    @Operation(summary = "删除附件（先删 MinIO 后删 DB）")
    @PreAuthorize("hasAnyRole('ADMIN', 'EDITOR')")
    public Result<Void> deleteAttachment(@PathVariable Long id) {
        uploadService.deleteAttachment(id);
        return Result.ok();
    }
}
