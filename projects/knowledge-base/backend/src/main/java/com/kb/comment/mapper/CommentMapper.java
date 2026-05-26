package com.kb.comment.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kb.comment.entity.Comment;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.util.List;

@Mapper
public interface CommentMapper extends BaseMapper<Comment> {

    /**
     * WITH RECURSIVE CTE 查询指定文章的全部评论（平铺 + parent_id）。
     * 包含已删除评论（保留占位），前端根据 parentId 递归组装树形。
     * 嵌套深度上限 3 层，直接使用表字段 depth。
     */
    @Select("""
            WITH RECURSIVE comment_tree AS (
                SELECT c.*
                FROM kb_comment c
                WHERE c.article_id = #{articleId} AND c.parent_id IS NULL
              UNION ALL
                SELECT c2.*
                FROM kb_comment c2
                JOIN comment_tree ct ON c2.parent_id = ct.id
                WHERE ct.depth < 2
            )
            SELECT * FROM comment_tree ORDER BY depth, created_at
            LIMIT 200
            """)
    List<Comment> selectCommentTree(@Param("articleId") Long articleId);

    @Select("""
            WITH RECURSIVE descendants AS (
                SELECT id FROM kb_comment WHERE parent_id = #{commentId} AND status = 1
              UNION ALL
                SELECT c.id FROM kb_comment c
                JOIN descendants d ON c.parent_id = d.id
                WHERE c.status = 1
            )
            SELECT id FROM descendants
            """)
    List<Long> selectDescendantIds(@Param("commentId") Long commentId);

    @Update("""
            <script>
            UPDATE kb_comment SET status = 0, deleted_at = NOW(), updated_at = NOW()
            WHERE id IN
            <foreach collection="ids" item="id" open="(" separator="," close=")">
                #{id}
            </foreach>
            AND status = 1
            </script>
            """)
    int batchSoftDelete(@Param("ids") List<Long> ids);
}
