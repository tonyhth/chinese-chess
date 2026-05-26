package com.kb.upload.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.kb.common.BusinessException;
import com.kb.common.ErrorCode;
import com.kb.common.security.PermissionService;
import com.kb.upload.dto.UploadDTO;
import com.kb.upload.entity.Attachment;
import com.kb.upload.mapper.AttachmentMapper;
import io.minio.BucketExistsArgs;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.RemoveObjectArgs;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Slf4j
@Service
@ConditionalOnProperty(name = "minio.enabled", havingValue = "true", matchIfMissing = true)
@RequiredArgsConstructor
public class UploadService {

    private final MinioClient minioClient;
    private final AttachmentMapper attachmentMapper;
    private final PermissionService permissionService;

    @Value("${minio.bucket}")
    private String bucket;

    @Value("${minio.endpoint}")
    private String endpoint;

    private static final long MAX_IMAGE_SIZE = 5 * 1024 * 1024; // 5MB
    private static final long MAX_FILE_SIZE = 50 * 1024 * 1024;  // 50MB

    private static final Set<String> IMAGE_TYPES = Set.of(
            "image/jpeg", "image/png", "image/gif", "image/webp"
    );
    private static final Set<String> ATTACHMENT_TYPES = Set.of(
            "application/pdf",
            "application/msword",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "application/vnd.ms-excel",
            "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "application/vnd.ms-powerpoint",
            "application/zip",
            "application/gzip",
            "application/x-tar",
            "application/x-gzip"
    );

    private static final byte[] JPEG_MAGIC = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF};
    private static final byte[] PNG_MAGIC = {(byte) 0x89, 0x50, 0x4E, 0x47};
    private static final byte[] GIF_MAGIC_PREFIX = {0x47, 0x49, 0x46, 0x38};
    private static final byte[] WEBP_MAGIC = {0x52, 0x49, 0x46, 0x46};

    private static final DateTimeFormatter DATE_PATH = DateTimeFormatter.ofPattern("yyyy/MM");

    @PostConstruct
    public void init() {
        try {
            boolean exists = minioClient.bucketExists(BucketExistsArgs.builder().bucket(bucket).build());
            if (!exists) {
                minioClient.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
                log.info("MinIO bucket '{}' 创建成功", bucket);
            }
        } catch (Exception e) {
            log.warn("MinIO bucket 初始化失败（可能未连接）: {}", e.getMessage());
        }
    }

    // ====== 上传 ======

    public UploadDTO uploadImage(MultipartFile file, String clientId) {
        permissionService.isEditorOrAbove();
        validateImage(file);

        if (clientId != null && !clientId.isBlank()) {
            Attachment existing = attachmentMapper.selectByClientId(clientId);
            if (existing != null) return toDTO(existing);
        }

        String ext = getExtension(file.getOriginalFilename());
        String objectName = "image/" + LocalDateTime.now().format(DATE_PATH) + "/" + UUID.randomUUID() + "." + ext;
        String filePath = uploadToMinio(file, objectName);
        Attachment attachment = saveAttachment(file, filePath, clientId);
        return toDTO(attachment);
    }

    public UploadDTO uploadFile(MultipartFile file, String clientId) {
        permissionService.isEditorOrAbove();
        validateAttachment(file);

        if (clientId != null && !clientId.isBlank()) {
            Attachment existing = attachmentMapper.selectByClientId(clientId);
            if (existing != null) return toDTO(existing);
        }

        String ext = getExtension(file.getOriginalFilename());
        String objectName = "file/" + LocalDateTime.now().format(DATE_PATH) + "/" + UUID.randomUUID() + "." + ext;
        String filePath = uploadToMinio(file, objectName);
        Attachment attachment = saveAttachment(file, filePath, clientId);
        return toDTO(attachment);
    }

    // ====== T12: 附件管理 ======

    /**
     * 获取文章的附件列表
     */
    public List<UploadDTO> listByArticle(Long articleId) {
        LambdaQueryWrapper<Attachment> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Attachment::getArticleId, articleId)
                .orderByDesc(Attachment::getCreatedAt);
        return attachmentMapper.selectList(wrapper).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    /**
     * 关联附件到文章
     */
    public void linkToArticle(Long attachmentId, Long articleId) {
        Attachment att = attachmentMapper.selectById(attachmentId);
        if (att == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "附件不存在");
        }
        att.setArticleId(articleId);
        attachmentMapper.updateById(att);
    }

    /**
     * 删除附件：先删 MinIO，成功后再删 DB。
     * MinIO 删除失败则不删 DB，保证数据可追溯。
     *
     * ⚠️ 已知风险：MinIO 删除成功后、DB deleteById 之前如果应用崩溃，
     * MinIO 文件已删但 DB 记录还在。这与需求文档"先 MinIO 后 DB"一致，
     * 但存在短暂的不一致窗口。下次孤儿清理会跳过（MinIO 404），
     * 需人工介入处理。
     */
    public void deleteAttachment(Long id) {
        Attachment attachment = attachmentMapper.selectById(id);
        if (attachment == null) {
            throw new BusinessException(ErrorCode.NOT_FOUND, "附件不存在");
        }
        permissionService.isEditorOrAbove();

        // 1. 先删 MinIO
        try {
            minioClient.removeObject(
                    RemoveObjectArgs.builder()
                            .bucket(bucket)
                            .object(attachment.getFilePath())
                            .build());
            log.info("[ATTACHMENT] MinIO deleted: filePath={}", attachment.getFilePath());
        } catch (Exception e) {
            log.error("[ATTACHMENT] MinIO delete failed, abort DB delete. id={}", id, e);
            throw new BusinessException(ErrorCode.FILE_DELETE_FAILED, "文件存储删除失败，请联系管理员");
        }

        // 2. MinIO 删除成功后才删 DB
        attachmentMapper.deleteById(id);
        log.info("[ATTACHMENT] deleted: id={}, fileName={}", id, attachment.getFileName());
    }

    /**
     * 孤儿附件清理：每天凌晨 3 点清理未关联且超过 24 小时的附件。
     * 两阶段批量清理（先 MinIO 后 DB），批量上限 500 条。
     */
    @Scheduled(cron = "0 0 3 * * ?")
    public void cleanOrphanAttachments() {
        LambdaQueryWrapper<Attachment> wrapper = new LambdaQueryWrapper<>();
        wrapper.isNull(Attachment::getArticleId)
                .lt(Attachment::getCreatedAt, LocalDateTime.now().minusHours(24))
                .last("LIMIT 500");
        List<Attachment> orphans = attachmentMapper.selectList(wrapper);

        if (orphans.isEmpty()) return;

        log.info("[ATTACHMENT] orphan cleanup: found {} candidates", orphans.size());

        // 阶段 1：批量删 MinIO，记录成功的 ID
        Set<Long> minioDeletedIds = new HashSet<>();
        for (Attachment a : orphans) {
            try {
                minioClient.removeObject(
                        RemoveObjectArgs.builder()
                                .bucket(bucket)
                                .object(a.getFilePath())
                                .build());
                minioDeletedIds.add(a.getId());
            } catch (Exception e) {
                log.warn("[ATTACHMENT] orphan MinIO delete failed for id={}, skipping", a.getId(), e);
            }
        }

        // 阶段 2：批量删 DB（只删 MinIO 成功的）
        if (!minioDeletedIds.isEmpty()) {
            attachmentMapper.deleteBatchIds(minioDeletedIds);
        }

        log.info("[ATTACHMENT] orphan cleanup done: minioDeleted={}, total={}", minioDeletedIds.size(), orphans.size());
    }

    // ====== private helpers ======

    private void validateImage(MultipartFile file) {
        if (file.isEmpty()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "文件不能为空");
        }
        if (file.getSize() > MAX_IMAGE_SIZE) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "图片大小不能超过 5MB");
        }
        String contentType = file.getContentType();
        if (contentType == null || !IMAGE_TYPES.contains(contentType)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "仅支持 JPG/PNG/GIF/WebP 格式");
        }
        validateMagicBytes(file, "图片");
    }

    private void validateAttachment(MultipartFile file) {
        if (file.isEmpty()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "文件不能为空");
        }
        if (file.getSize() > MAX_FILE_SIZE) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "附件大小不能超过 50MB");
        }
        String contentType = file.getContentType();
        if (contentType != null && !ATTACHMENT_TYPES.contains(contentType)) {
            String ext = getExtension(file.getOriginalFilename());
            if (!isAllowedExtension(ext)) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "不支持的文件类型");
            }
        }
    }

    private boolean isAllowedExtension(String ext) {
        return Set.of("pdf", "doc", "docx", "xlsx", "xls", "pptx", "ppt", "zip", "tar", "gz").contains(ext);
    }

    private void validateMagicBytes(MultipartFile file, String label) {
        try (InputStream is = file.getInputStream()) {
            byte[] header = new byte[12];
            int read = is.read(header);
            if (read < 4) return;

            boolean valid = startsWith(header, JPEG_MAGIC)
                    || startsWith(header, PNG_MAGIC)
                    || startsWith(header, GIF_MAGIC_PREFIX)
                    || startsWith(header, WEBP_MAGIC);
            if (!valid) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, label + "文件内容与扩展名不匹配");
            }
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            log.warn("Magic bytes 验证失败: {}", e.getMessage());
        }
    }

    private boolean startsWith(byte[] data, byte[] prefix) {
        if (data.length < prefix.length) return false;
        for (int i = 0; i < prefix.length; i++) {
            if (data[i] != prefix[i]) return false;
        }
        return true;
    }

    private String uploadToMinio(MultipartFile file, String objectName) {
        try (InputStream is = file.getInputStream()) {
            minioClient.putObject(PutObjectArgs.builder()
                    .bucket(bucket)
                    .object(objectName)
                    .stream(is, file.getSize(), -1)
                    .contentType(file.getContentType())
                    .build());
            return objectName;
        } catch (Exception e) {
            log.error("文件上传到 MinIO 失败: {}", e.getMessage());
            throw new BusinessException(ErrorCode.FILE_UPLOAD_FAILED);
        }
    }

    private Attachment saveAttachment(MultipartFile file, String filePath, String clientId) {
        Attachment attachment = new Attachment();
        attachment.setFileName(file.getOriginalFilename());
        attachment.setFilePath(filePath);
        attachment.setFileSize(file.getSize());
        attachment.setMimeType(file.getContentType());
        attachment.setUploadUserId(permissionService.currentUserId());
        attachment.setClientId(clientId);
        attachmentMapper.insert(attachment);
        return attachment;
    }

    private UploadDTO toDTO(Attachment a) {
        UploadDTO dto = new UploadDTO();
        dto.setId(a.getId());
        dto.setUrl(endpoint + "/" + bucket + "/" + a.getFilePath());
        dto.setFileName(a.getFileName());
        dto.setFilePath(a.getFilePath());
        dto.setFileSize(a.getFileSize());
        dto.setMimeType(a.getMimeType());
        dto.setCreatedAt(a.getCreatedAt());
        return dto;
    }

    private String getExtension(String filename) {
        if (filename == null || !filename.contains(".")) return "bin";
        return filename.substring(filename.lastIndexOf(".") + 1).toLowerCase();
    }
}
