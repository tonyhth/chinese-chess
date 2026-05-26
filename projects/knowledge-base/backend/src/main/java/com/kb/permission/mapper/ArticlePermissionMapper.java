package com.kb.permission.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kb.permission.entity.ArticlePermission;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface ArticlePermissionMapper extends BaseMapper<ArticlePermission> {

    @Select("SELECT * FROM kb_article_permission WHERE article_id = #{articleId} AND user_id = #{userId}")
    ArticlePermission findByArticleAndUser(@Param("articleId") Long articleId, @Param("userId") Long userId);

    @Select("SELECT * FROM kb_article_permission WHERE article_id = #{articleId}")
    List<ArticlePermission> listByArticle(@Param("articleId") Long articleId);

    @Select("SELECT permission FROM kb_article_permission WHERE article_id = #{articleId} AND user_id = #{userId}")
    String getPermissionLevel(@Param("articleId") Long articleId, @Param("userId") Long userId);

    /**
     * 批量查询用户对多篇文章的权限
     */
    @Select("<script>" +
            "SELECT article_id, permission FROM kb_article_permission " +
            "WHERE user_id = #{userId} AND article_id IN " +
            "<foreach item='id' collection='articleIds' open='(' separator=',' close=')'>" +
            "#{id}" +
            "</foreach>" +
            "</script>")
    List<ArticlePermission> listByArticleIds(@Param("userId") Long userId, @Param("articleIds") List<Long> articleIds);
}
