package com.kb.common;

import lombok.Getter;

@Getter
public enum ErrorCode {
    SUCCESS(200, "操作成功"),
    BAD_REQUEST(400, "请求参数错误"),
    UNAUTHORIZED(401, "未认证"),
    FORBIDDEN(403, "无权限"),
    NOT_FOUND(404, "资源不存在"),
    CONFLICT(409, "资源冲突"),
    INTERNAL_ERROR(500, "服务器内部错误"),
    USER_NOT_FOUND(1001, "用户不存在"),
    USER_ALREADY_EXISTS(1002, "用户已存在"),
    ARTICLE_NOT_FOUND(2001, "文章不存在"),
    ARTICLE_VERSION_CONFLICT(2002, "文章版本冲突"),
    CATEGORY_NOT_FOUND(3001, "分类不存在"),
    CATEGORY_HAS_CHILDREN(3002, "分类下有子分类，无法删除"),
    CATEGORY_HAS_ARTICLES(3003, "分类下有文章，无法删除"),
    TAG_NOT_FOUND(4001, "标签不存在"),
    COMMENT_NOT_FOUND(5001, "评论不存在"),
    COMMENT_DEPTH_EXCEEDED(5002, "评论嵌套深度不能超过 3 层"),
    FILE_UPLOAD_FAILED(6001, "文件上传失败"),
    FILE_DELETE_FAILED(6002, "文件删除失败");

    private final int code;
    private final String message;

    ErrorCode(int code, String message) {
        this.code = code;
        this.message = message;
    }
}
