package com.kb.category.controller;

import com.kb.category.dto.CategoryCreateRequest;
import com.kb.category.dto.CategoryTreeDTO;
import com.kb.category.dto.CategoryUpdateRequest;
import com.kb.category.service.CategoryService;
import com.kb.common.Result;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/categories")
@RequiredArgsConstructor
@Tag(name = "分类", description = "文章分类管理")
public class CategoryController {

    private final CategoryService categoryService;

    @GetMapping
    @Operation(summary = "获取分类树")
    public Result<List<CategoryTreeDTO>> getTree() {
        return Result.ok(categoryService.getTree());
    }

    @PostMapping
    @Operation(summary = "创建分类")
    @PreAuthorize("hasAnyRole('ADMIN', 'EDITOR')")
    public Result<CategoryTreeDTO> create(@Valid @RequestBody CategoryCreateRequest request) {
        return Result.ok(categoryService.create(request));
    }

    @PutMapping("/{id}")
    @Operation(summary = "更新分类")
    @PreAuthorize("hasAnyRole('ADMIN', 'EDITOR')")
    public Result<CategoryTreeDTO> update(@PathVariable Long id, @Valid @RequestBody CategoryUpdateRequest request) {
        return Result.ok(categoryService.update(id, request));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "删除分类（仅ADMIN）")
    @PreAuthorize("hasRole('ADMIN')")
    public Result<Void> delete(@PathVariable Long id) {
        categoryService.delete(id);
        return Result.ok();
    }
}
