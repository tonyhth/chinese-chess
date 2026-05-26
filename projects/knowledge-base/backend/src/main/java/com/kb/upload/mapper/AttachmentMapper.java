package com.kb.upload.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.kb.upload.entity.Attachment;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface AttachmentMapper extends BaseMapper<Attachment> {

    @Select("SELECT * FROM kb_attachment WHERE client_id = #{clientId} LIMIT 1")
    Attachment selectByClientId(@Param("clientId") String clientId);

    @Select("SELECT * FROM kb_attachment WHERE file_path = #{filePath} LIMIT 1")
    Attachment selectByFilePath(@Param("filePath") String filePath);
}
