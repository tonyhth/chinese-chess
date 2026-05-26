package com.kb.article;

import com.kb.article.dto.ArticleCreateRequest;
import com.kb.article.dto.ArticleBatchResult;
import com.kb.article.dto.ArticleBatchDeleteRequest;
import com.kb.article.dto.ArticleBatchMoveRequest;
import com.kb.article.dto.ArticleBatchTagRequest;
import com.kb.article.service.ArticleBatchService;
import com.kb.article.service.ArticleService;
import com.kb.category.dto.CategoryCreateRequest;
import com.kb.category.service.CategoryService;
import com.kb.auth.service.AuthService;
import com.kb.auth.dto.LoginRequest;
import com.kb.tag.dto.TagCreateRequest;
import com.kb.tag.service.TagService;
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
class ArticleBatchServiceTest {

    @Autowired
    private ArticleBatchService batchService;

    @Autowired
    private ArticleService articleService;

    @Autowired
    private CategoryService categoryService;

    @Autowired
    private TagService tagService;

    @Autowired
    private AuthService authService;

    private void loginAsAdmin() {
        // Mock admin user in SecurityContext
        CustomUserDetails admin = new CustomUserDetails(1L, "admin", "ADMIN");
        var auth = new UsernamePasswordAuthenticationToken(admin, null, admin.getAuthorities());
        SecurityContextHolder.getContext().setAuthentication(auth);
    }

    private Long createArticle(String title) {
        ArticleCreateRequest req = new ArticleCreateRequest();
        req.setTitle(title);
        req.setContent("内容 " + title);
        req.setStatus("PUBLISHED");
        return articleService.create(req).getId();
    }

    @Test
    @DisplayName("批量删除 — 全部成功")
    void batchDelete_allSuccess() {
        loginAsAdmin();
        Long id1 = createArticle("批量删除1");
        Long id2 = createArticle("批量删除2");

        ArticleBatchDeleteRequest req = new ArticleBatchDeleteRequest();
        req.setIds(List.of(id1, id2));
        ArticleBatchResult result = batchService.batchDelete(req);

        assertEquals(2, result.getSuccessCount());
        assertEquals(0, result.getFailCount());
    }

    @Test
    @DisplayName("批量删除 — 部分失败（不存在的ID）")
    void batchDelete_partialFail() {
        loginAsAdmin();
        Long id1 = createArticle("批量删除部分");

        ArticleBatchDeleteRequest req = new ArticleBatchDeleteRequest();
        req.setIds(List.of(id1, 99999L));
        ArticleBatchResult result = batchService.batchDelete(req);

        assertEquals(1, result.getSuccessCount());
        assertEquals(1, result.getFailCount());
        assertTrue(result.getFailedIds().contains(99999L));
    }

    @Test
    @DisplayName("批量移动分类")
    void batchMove_success() {
        loginAsAdmin();
        Long id1 = createArticle("移动1");
        Long id2 = createArticle("移动2");

        CategoryCreateRequest catReq = new CategoryCreateRequest();
        catReq.setName("移动目标分类");
        catReq.setSlug("move-target");
        Long catId = categoryService.create(catReq).getId();

        ArticleBatchMoveRequest req = new ArticleBatchMoveRequest();
        req.setIds(List.of(id1, id2));
        req.setCategoryId(catId);
        ArticleBatchResult result = batchService.batchMove(req);

        assertEquals(2, result.getSuccessCount());

        // 验证文章分类已更新
        var a1 = articleService.getById(id1);
        assertEquals(catId, a1.getCategoryId());
    }

    @Test
    @DisplayName("批量打标签")
    void batchTag_success() {
        loginAsAdmin();
        Long id1 = createArticle("打标签1");

        TagCreateRequest tagReq = new TagCreateRequest();
        tagReq.setName("批量测试标签");
        Long tagId = tagService.create(tagReq).getId();

        ArticleBatchTagRequest req = new ArticleBatchTagRequest();
        req.setIds(List.of(id1));
        req.setTagIds(List.of(tagId));
        ArticleBatchResult result = batchService.batchTag(req);

        assertEquals(1, result.getSuccessCount());
    }

    @Test
    @DisplayName("批量打标签 — 幂等不重复插入")
    void batchTag_idempotent() {
        loginAsAdmin();
        Long id1 = createArticle("幂等标签");

        TagCreateRequest tagReq = new TagCreateRequest();
        tagReq.setName("幂等标签");
        Long tagId = tagService.create(tagReq).getId();

        ArticleBatchTagRequest req = new ArticleBatchTagRequest();
        req.setIds(List.of(id1));
        req.setTagIds(List.of(tagId));

        batchService.batchTag(req);
        // 第二次不报错
        ArticleBatchResult result = batchService.batchTag(req);
        assertEquals(1, result.getSuccessCount());
    }
}
