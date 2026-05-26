package com.kb.search.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kb.search.entity.EsSyncFailLog;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.util.List;

@Mapper
public interface EsSyncFailLogMapper extends BaseMapper<EsSyncFailLog> {

    @Select("SELECT * FROM es_sync_fail_log WHERE status = 0 AND next_retry_at <= NOW() ORDER BY next_retry_at ASC LIMIT 100")
    List<EsSyncFailLog> selectPending();

    @Update("UPDATE es_sync_fail_log SET status = #{status}, updated_at = NOW() WHERE id = #{id}")
    int updateStatus(Long id, int status);
}
