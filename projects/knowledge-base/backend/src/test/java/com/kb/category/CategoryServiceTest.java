package com.kb.category;

import com.kb.article.dto.ArticleCreateRequest;
import com.kb.article.service.ArticleService;
import com.kb.auth.service.AuthService;
import com.kb.auth.dto.LoginRequest;
import com.kb.category.dto.CategoryCreateRequest;
import com.kb.category.dto.CategoryTreeDTO;
import com.kb.category.dto.CategoryUpdateRequest;
import com.kb.category.service.CategoryService;
import com.kb.common.BusinessException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import com.kb.test.TestRedisConfig;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.security.test.context.support.WithMockUser;
import com.kb.auth.security.CustomUserDetails;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@Import(com.kb.test.TestRedisConfig.class)
    @Sql("/test-data.sql")
@ActiveProfiles("test")
@Transactional
class CategoryServiceTest {

    @Autowired
    private CategoryService categoryService;

    @Autowired
    private ArticleService articleService;

    @Autowired
    private AuthService authService;

    private void loginAsAdmin() {
        // Mock admin user in SecurityContext
        CustomUserDetails admin = new CustomUserDetails(1L, "admin", "ADMIN");
        var auth = new UsernamePasswordAuthenticationToken(admin, null, admin.getAuthorities());
        SecurityContextHolder.getContext().setAuthentication(auth);
    }

    @Test
    @DisplayName("创建根分类")
    void create_root() {
        loginAsAdmin();
        CategoryCreateRequest req = new CategoryCreateRequest();
        req.setName("测试分类");
        req.setSlug("test-cat");
        CategoryTreeDTO dto = categoryService.create(req);
        assertNotNull(dto.getId());
        assertEquals("测试分类", dto.getName());
        assertNull(dto.getParentId());
    }

    @Test
    @DisplayName("创建子分类")
    void create_child() {
        loginAsAdmin();
        CategoryCreateRequest parentReq = new CategoryCreateRequest();
        parentReq.setName("父分类");
        parentReq.setSlug("parent");
        Long parentId = categoryService.create(parentReq).getId();

        CategoryCreateRequest childReq = new CategoryCreateRequest();
        childReq.setName("子分类");
        childReq.setSlug("child");
        childReq.setParentId(parentId);
        CategoryTreeDTO child = categoryService.create(childReq);
        assertEquals(parentId, child.getParentId());
    }

    @Test
    @DisplayName("获取分类树")
    void getTree() {
        loginAsAdmin();
        CategoryCreateRequest req = new CategoryCreateRequest();
        req.setName("树测试");
        req.setSlug("tree-test");
        categoryService.create(req);

        List<CategoryTreeDTO> tree = categoryService.getTree();
        assertFalse(tree.isEmpty());
    }

    @Test
    @DisplayName("更新分类")
    void update_success() {
        loginAsAdmin();
        CategoryCreateRequest req = new CategoryCreateRequest();
        req.setName("原名称");
        req.setSlug("update-test");
        Long id = categoryService.create(req).getId();

        CategoryUpdateRequest update = new CategoryUpdateRequest();
        update.setName("新名称");
        CategoryTreeDTO updated = categoryService.update(id, update);
        assertEquals("新名称", updated.getName());
    }

    @Test
    @DisplayName("更新不存在的分类抛异常")
    void update_notFound() {
        loginAsAdmin();
        CategoryUpdateRequest update = new CategoryUpdateRequest();
        update.setName("不存在");
        assertThrows(BusinessException.class, () -> categoryService.update(99999L, update));
    }

    @Test
    @DisplayName("删除有空子分类的分类抛异常")
    void delete_hasChildren() {
        loginAsAdmin();
        CategoryCreateRequest parentReq = new CategoryCreateRequest();
        parentReq.setName("父");
        parentReq.setSlug("del-parent");
        Long parentId = categoryService.create(parentReq).getId();

        CategoryCreateRequest childReq = new CategoryCreateRequest();
        childReq.setName("子");
        childReq.setSlug("del-child");
        childReq.setParentId(parentId);
        categoryService.create(childReq);

        assertThrows(BusinessException.class, () -> categoryService.delete(parentId));
    }

    @Test
    @DisplayName("删除有关联文章的分类抛异常")
    void delete_hasArticles() {
        loginAsAdmin();
        CategoryCreateRequest req = new CategoryCreateRequest();
        req.setName("文章分类");
        req.setSlug("art-cat");
        Long catId = categoryService.create(req).getId();

        ArticleCreateRequest artReq = new ArticleCreateRequest();
        artReq.setTitle("测试文章");
        artReq.setContent("内容");
        artReq.setStatus("PUBLISHED");
        artReq.setCategoryId(catId);
        articleService.create(artReq);

        assertThrows(BusinessException.class, () -> categoryService.delete(catId));
    }

    @Test
    @DisplayName("删除空分类成功")
    void delete_success() {
        loginAsAdmin();
        CategoryCreateRequest req = new CategoryCreateRequest();
        req.setName("可删除分类");
        req.setSlug("deletable");
        Long id = categoryService.create(req).getId();

        assertDoesNotThrow(() -> categoryService.delete(id));
    }

    @Test
    @DisplayName("分类不能成为自己的子分类")
    void update_selfParent() {
        loginAsAdmin();
        CategoryCreateRequest req = new CategoryCreateRequest();
        req.setName("自引用");
        req.setSlug("self-ref");
        Long id = categoryService.create(req).getId();

        CategoryUpdateRequest update = new CategoryUpdateRequest();
        update.setParentId(id);
        assertThrows(BusinessException.class, () -> categoryService.update(id, update));
    }
}
