package com.kb.tag.controller;

import com.kb.common.Result;
import com.kb.tag.dto.TagCreateRequest;
import com.kb.tag.dto.TagUpdateRequest;
import com.kb.tag.entity.Tag;
import com.kb.tag.service.TagService;
import io.swagger.v3.oas.annotations.Operation;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/tags")
@RequiredArgsConstructor
@io.swagger.v3.oas.annotations.tags.Tag(name = "标签", description = "标签管理")
public class TagController {

    private final TagService tagService;

    @GetMapping
    @Operation(summary = "标签列表")
    public Result<List<Tag>> list() {
        return Result.ok(tagService.list());
    }

    @PostMapping
    @Operation(summary = "创建标签")
    @PreAuthorize("hasAnyRole('ADMIN', 'EDITOR')")
    public Result<Tag> create(@Valid @RequestBody TagCreateRequest request) {
        return Result.ok(tagService.create(request));
    }

    @PutMapping("/{id}")
    @Operation(summary = "更新标签")
    @PreAuthorize("hasAnyRole('ADMIN', 'EDITOR')")
    public Result<Tag> update(@PathVariable Long id, @Valid @RequestBody TagUpdateRequest request) {
        return Result.ok(tagService.update(id, request));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "删除标签（仅ADMIN）")
    @PreAuthorize("hasRole('ADMIN')")
    public Result<Void> delete(@PathVariable Long id) {
        tagService.delete(id);
        return Result.ok();
    }
}
