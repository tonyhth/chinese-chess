package com.kb.user.mapper;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.baomidou.mybatisplus.core.toolkit.Constants;
import com.kb.user.entity.User;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface UserMapper extends BaseMapper<User> {

    @Select("SELECT * FROM sys_user WHERE deleted_at IS NULL AND id = #{id}")
    User selectActiveById(@Param("id") Long id);

    /** 按用户名查询（参数名 identifier 为未来支持邮箱登录预留） */
    @Select("SELECT * FROM sys_user WHERE deleted_at IS NULL AND username = #{identifier}")
    User selectActiveByIdentifier(@Param("identifier") String identifier);

    @Select("SELECT * FROM sys_user WHERE deleted_at IS NULL AND email = #{email}")
    User selectActiveByEmail(@Param("email") String email);

    @Select("SELECT * FROM sys_user WHERE deleted_at IS NULL ${ew.customSqlSegment}")
    java.util.List<User> selectActiveList(@Param(Constants.WRAPPER) LambdaQueryWrapper<User> wrapper);
}
