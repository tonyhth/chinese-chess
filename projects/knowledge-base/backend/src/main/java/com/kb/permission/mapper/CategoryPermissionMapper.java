package com.kb.permission.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kb.permission.entity.CategoryPermission;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface CategoryPermissionMapper extends BaseMapper<CategoryPermission> {

    @Select("SELECT * FROM kb_category_permission WHERE category_id = #{categoryId} AND user_id = #{userId}")
    CategoryPermission findByCategoryAndUser(@Param("categoryId") Long categoryId, @Param("userId") Long userId);

    @Select("SELECT * FROM kb_category_permission WHERE category_id = #{categoryId}")
    List<CategoryPermission> listByCategory(@Param("categoryId") Long categoryId);

    @Select("SELECT permission FROM kb_category_permission WHERE category_id = #{categoryId} AND user_id = #{userId}")
    String getPermissionLevel(@Param("categoryId") Long categoryId, @Param("userId") Long userId);
}
