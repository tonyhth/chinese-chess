package com.kb.article.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

/**
 * 文章-标签关联。
 * 无单一主键，不使用 BaseMapper，Service 层用自定义 SQL 操作。
 */
@Data
@TableName("kb_article_tag")
public class ArticleTag {
    private Long articleId;
    private Long tagId;
}
