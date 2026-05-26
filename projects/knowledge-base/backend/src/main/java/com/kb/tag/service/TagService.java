package com.kb.tag.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.kb.common.BusinessException;
import com.kb.common.ErrorCode;
import com.kb.common.security.PermissionService;
import com.kb.tag.dto.TagCreateRequest;
import com.kb.tag.dto.TagUpdateRequest;
import com.kb.tag.entity.Tag;
import com.kb.tag.mapper.TagMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class TagService {

    private final TagMapper tagMapper;
    private final PermissionService permissionService;

    public List<Tag> list() {
        return tagMapper.selectList(null);
    }

    public Tag create(TagCreateRequest request) {
        permissionService.isEditorOrAbove();

        // 重名检查
        long count = tagMapper.selectCount(
                new LambdaQueryWrapper<Tag>().eq(Tag::getName, request.getName()));
        if (count > 0) {
            throw new BusinessException(ErrorCode.CONFLICT, "标签名已存在");
        }

        Tag tag = new Tag();
        tag.setName(request.getName());
        tag.setColor(request.getColor());
        tagMapper.insert(tag);
        return tag;
    }

    public Tag update(Long id, TagUpdateRequest request) {
        permissionService.isEditorOrAbove();
        Tag tag = tagMapper.selectById(id);
        if (tag == null) {
            throw new BusinessException(ErrorCode.TAG_NOT_FOUND);
        }
        if (request.getName() != null && !request.getName().equals(tag.getName())) {
            long count = tagMapper.selectCount(
                    new LambdaQueryWrapper<Tag>().eq(Tag::getName, request.getName()));
            if (count > 0) {
                throw new BusinessException(ErrorCode.CONFLICT, "标签名已存在");
            }
            tag.setName(request.getName());
        }
        if (request.getColor() != null) tag.setColor(request.getColor());
        tagMapper.updateById(tag);
        return tag;
    }

    public void delete(Long id) {
        permissionService.checkAdminOnly();
        tagMapper.deleteById(id);
    }
}
