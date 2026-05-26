package com.kb.article.mapper;

import com.kb.article.entity.ArticleTag;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Insert;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import java.util.List;

@Mapper
public interface ArticleTagMapper {

    @Insert("INSERT INTO kb_article_tag (article_id, tag_id) VALUES (#{articleId}, #{tagId})")
    int insert(ArticleTag articleTag);

    @Delete("DELETE FROM kb_article_tag WHERE article_id = #{articleId}")
    int deleteByArticleId(Long articleId);

    @Select("SELECT tag_id FROM kb_article_tag WHERE article_id = #{articleId}")
    List<Long> selectTagIdsByArticleId(Long articleId);

    @Select("SELECT article_id FROM kb_article_tag WHERE tag_id = #{tagId}")
    List<Long> selectArticleIdsByTagId(Long tagId);

    @Select("SELECT COUNT(*) FROM kb_article_tag WHERE article_id = #{articleId}")
    long countByArticleId(Long articleId);

    /**
     * 幂等插入：不存在才插入
     */
    @Insert("INSERT INTO kb_article_tag (article_id, tag_id) SELECT #{articleId}, #{tagId} " +
            "WHERE NOT EXISTS (SELECT 1 FROM kb_article_tag WHERE article_id = #{articleId} AND tag_id = #{tagId})")
    int insertIfNotExists(@Param("articleId") Long articleId, @Param("tagId") Long tagId);
}
