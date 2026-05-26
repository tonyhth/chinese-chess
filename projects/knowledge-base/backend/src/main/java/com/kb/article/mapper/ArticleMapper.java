package com.kb.article.mapper;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.baomidou.mybatisplus.core.toolkit.Constants;
import com.kb.article.entity.Article;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

@Mapper
public interface ArticleMapper extends BaseMapper<Article> {

    @Select("SELECT * FROM kb_article WHERE deleted_at IS NULL AND id = #{id}")
    Article selectActiveById(@Param("id") Long id);

    @Select("SELECT * FROM kb_article WHERE deleted_at IS NULL ${ew.customSqlSegment}")
    java.util.List<Article> selectActiveList(@Param(Constants.WRAPPER) LambdaQueryWrapper<Article> wrapper);

    @Select("SELECT COUNT(*) FROM kb_article WHERE deleted_at IS NULL")
    long countActive();

    /**
     * 乐观锁更新：WHERE id=? AND version=?
     * 返回受影响行数，0 表示版本冲突
     */
    @Update("UPDATE kb_article SET title=#{title}, content=#{content}, " +
            "summary=#{summary}, category_id=#{categoryId}, slug=#{slug}, " +
            "version=#{newVersion}, updated_at=NOW() " +
            "WHERE id=#{id} AND version=#{oldVersion}")
    int updateVersionAndContent(@Param("id") Long id,
                                @Param("oldVersion") int oldVersion,
                                @Param("title") String title,
                                @Param("content") String content,
                                @Param("summary") String summary,
                                @Param("categoryId") Long categoryId,
                                @Param("slug") String slug,
                                @Param("newVersion") int newVersion);
}
