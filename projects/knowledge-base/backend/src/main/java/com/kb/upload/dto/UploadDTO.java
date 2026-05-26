package com.kb.upload.dto;

import lombok.Data;

import java.time.LocalDateTime;

@Data
public class UploadDTO {
    private Long id;
    private String url;
    private String fileName;
    private String filePath;
    private Long fileSize;
    private String mimeType;
    private LocalDateTime createdAt;
}
