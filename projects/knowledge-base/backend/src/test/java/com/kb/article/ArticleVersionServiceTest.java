package com.kb.article;

import com.kb.article.dto.ArticleCreateRequest;
import com.kb.article.dto.ArticleUpdateRequest;
import com.kb.article.dto.ArticleVersionDTO;
import com.kb.article.service.ArticleVersionService;
import com.kb.article.service.ArticleService;
import com.kb.auth.service.AuthService;
import com.kb.auth.dto.LoginRequest;
import com.kb.auth.dto.RegisterRequest;
import com.kb.common.BusinessException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import com.kb.test.TestRedisConfig;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import com.kb.auth.security.CustomUserDetails;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@Import(com.kb.test.TestRedisConfig.class)
    @Sql("/test-data.sql")
@ActiveProfiles("test")
@AutoConfigureMockMvc
@Transactional
class ArticleVersionServiceTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private ArticleService articleService;

    @Autowired
    private ArticleVersionService articleVersionService;

    @Autowired
    private AuthService authService;

    private String token;
    private Long articleId;

    private void loginAsAdmin() {
        CustomUserDetails admin = new CustomUserDetails(1L, "admin", "ADMIN");
        var auth = new UsernamePasswordAuthenticationToken(admin, null, admin.getAuthorities());
        SecurityContextHolder.getContext().setAuthentication(auth);
    }
    private void setupArticle() {
        loginAsAdmin();
        ArticleCreateRequest req = new ArticleCreateRequest();
        req.setTitle("版本测试文章");
        req.setContent("初始内容 v1");
        req.setStatus("DRAFT");
        var dto = articleService.create(req);
        articleId = dto.getId();
    }

    @Test
    @DisplayName("创建文章时自动生成初始版本")
    void createArticle_generatesVersion() {
        setupArticle();
        List<ArticleVersionDTO> versions = articleVersionService.listVersions(articleId);
        assertEquals(1, versions.size());
        assertEquals(1, versions.get(0).getVersion());
        assertEquals("初始内容 v1", versions.get(0).getContent());
    }

    @Test
    @DisplayName("更新文章时自动生成新版本")
    void updateArticle_generatesNewVersion() {
        setupArticle();
        ArticleUpdateRequest update = new ArticleUpdateRequest();
        update.setContent("修改后内容 v2");
        articleService.update(articleId, update);

        List<ArticleVersionDTO> versions = articleVersionService.listVersions(articleId);
        assertEquals(2, versions.size());
        // 倒序，第一条是 v2
        assertEquals(2, versions.get(0).getVersion());
        assertEquals("修改后内容 v2", versions.get(0).getContent());
        assertEquals(1, versions.get(1).getVersion());
    }

    @Test
    @DisplayName("获取指定版本详情")
    void getVersion_success() {
        setupArticle();
        ArticleVersionDTO v1 = articleVersionService.getVersion(articleId, 1);
        assertNotNull(v1);
        assertEquals(1, v1.getVersion());
        assertEquals("初始内容 v1", v1.getContent());
    }

    @Test
    @DisplayName("获取不存在的版本返回404")
    void getVersion_notFound() {
        setupArticle();
        assertThrows(BusinessException.class, () -> articleVersionService.getVersion(articleId, 999));
    }

    @Test
    @DisplayName("回滚到指定版本")
    void restoreVersion_success() {
        setupArticle();

        // 编辑文章
        ArticleUpdateRequest update = new ArticleUpdateRequest();
        update.setContent("修改后内容 v2");
        articleService.update(articleId, update);

        // 回滚到 v1
        ArticleVersionDTO restored = articleVersionService.restoreVersion(articleId, 1);

        // 验证文章内容恢复
        var article = articleService.getById(articleId);
        assertEquals("初始内容 v1", article.getContent());
        assertEquals(3, article.getVersion());
    }

    @Test
    @DisplayName("版本列表限制200条")
    void listVersions_max200() {
        setupArticle();
        List<ArticleVersionDTO> versions = articleVersionService.listVersions(articleId);
        assertTrue(versions.size() <= 200);
    }

    @Test
    @DisplayName("API: GET /articles/{id}/versions")
    void api_getVersions() throws Exception {
        setupArticle();
        mockMvc.perform(get("/api/v1/articles/{id}/versions", articleId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data").isArray())
                .andExpect(jsonPath("$.data.length()").value(1));
    }

    @Test
    @DisplayName("API: POST /articles/{id}/versions/{version}/restore")
    void api_restoreVersion() throws Exception {
        setupArticle();
        ArticleUpdateRequest update = new ArticleUpdateRequest();
        update.setContent("v2 content");
        articleService.update(articleId, update);

        mockMvc.perform(post("/api/v1/articles/{id}/versions/{version}/restore", articleId, 1)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());
    }
}
