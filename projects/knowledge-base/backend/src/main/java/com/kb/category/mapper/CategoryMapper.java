package com.kb.category.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kb.category.entity.Category;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface CategoryMapper extends BaseMapper<Category> {

    @Select("SELECT * FROM kb_category ORDER BY sort_order, id")
    List<Category> selectAllOrdered();
}
