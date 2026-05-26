package com.kb.category.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.kb.article.entity.Article;
import com.kb.article.mapper.ArticleMapper;
import com.kb.category.dto.CategoryCreateRequest;
import com.kb.category.dto.CategoryTreeDTO;
import com.kb.category.dto.CategoryUpdateRequest;
import com.kb.category.entity.Category;
import com.kb.category.mapper.CategoryMapper;
import com.kb.common.BusinessException;
import com.kb.common.ErrorCode;
import com.kb.common.security.PermissionService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CategoryService {

    private final CategoryMapper categoryMapper;
    private final ArticleMapper articleMapper;
    private final PermissionService permissionService;

    public List<CategoryTreeDTO> getTree() {
        List<Category> all = categoryMapper.selectAllOrdered();
        return buildTree(all, null);
    }

    public CategoryTreeDTO create(CategoryCreateRequest request) {
        permissionService.isEditorOrAbove();

        Category category = new Category();
        category.setName(request.getName());
        category.setSlug(request.getSlug());
        category.setParentId(request.getParentId());
        category.setDescription(request.getDescription());
        category.setSortOrder(request.getSortOrder() != null ? request.getSortOrder() : 0);
        categoryMapper.insert(category);
        return toDTO(category);
    }

    public CategoryTreeDTO update(Long id, CategoryUpdateRequest request) {
        permissionService.checkCategoryEditable(id);

        Category category = categoryMapper.selectById(id);
        if (category == null) {
            throw new BusinessException(ErrorCode.CATEGORY_NOT_FOUND);
        }
        if (request.getName() != null) category.setName(request.getName());
        if (request.getSlug() != null) category.setSlug(request.getSlug());
        if (request.getParentId() != null) {
            if (request.getParentId().equals(id)) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "分类不能成为自己的子分类");
            }
            category.setParentId(request.getParentId());
        }
        if (request.getDescription() != null) category.setDescription(request.getDescription());
        if (request.getSortOrder() != null) category.setSortOrder(request.getSortOrder());
        categoryMapper.updateById(category);
        return toDTO(category);
    }

    public void delete(Long id) {
        permissionService.checkAdminOnly();

        // 检查是否有子分类
        long childCount = categoryMapper.selectCount(
                new LambdaQueryWrapper<Category>().eq(Category::getParentId, id));
        if (childCount > 0) {
            throw new BusinessException(ErrorCode.CATEGORY_HAS_CHILDREN);
        }

        // 检查是否有关联文章
        long articleCount = articleMapper.selectCount(
                new LambdaQueryWrapper<Article>()
                        .eq(Article::getCategoryId, id)
                        .isNull(Article::getDeletedAt));
        if (articleCount > 0) {
            throw new BusinessException(ErrorCode.CATEGORY_HAS_ARTICLES);
        }

        categoryMapper.deleteById(id);
    }

    // --- private ---

    private List<CategoryTreeDTO> buildTree(List<Category> all, Long parentId) {
        return all.stream()
                .filter(c -> Objects.equals(c.getParentId(), parentId))
                .map(c -> {
                    CategoryTreeDTO dto = toDTO(c);
                    dto.setChildren(buildTree(all, c.getId()));
                    return dto;
                })
                .collect(Collectors.toList());
    }

    private CategoryTreeDTO toDTO(Category category) {
        CategoryTreeDTO dto = new CategoryTreeDTO();
        dto.setId(category.getId());
        dto.setParentId(category.getParentId());
        dto.setName(category.getName());
        dto.setSlug(category.getSlug());
        dto.setDescription(category.getDescription());
        dto.setSortOrder(category.getSortOrder());
        dto.setCreatedAt(category.getCreatedAt());
        return dto;
    }
}
