package com.kb.comment;

import com.kb.article.dto.ArticleCreateRequest;
import com.kb.article.service.ArticleService;
import com.kb.auth.service.AuthService;
import com.kb.auth.dto.LoginRequest;
import com.kb.comment.dto.CommentCreateRequest;
import com.kb.comment.dto.CommentDTO;
import com.kb.comment.service.CommentService;
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
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import com.kb.auth.security.CustomUserDetails;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@Import(com.kb.test.TestRedisConfig.class)
    @Sql("/test-data.sql")
@ActiveProfiles("test")
@Transactional
class CommentServiceTest {

    @Autowired
    private CommentService commentService;

    @Autowired
    private ArticleService articleService;

    @Autowired
    private AuthService authService;

    private String token;
    private Long articleId;

    private void loginAsAdmin() {
        CustomUserDetails admin = new CustomUserDetails(1L, "admin", "ADMIN");
        var auth = new UsernamePasswordAuthenticationToken(admin, null, admin.getAuthorities());
        SecurityContextHolder.getContext().setAuthentication(auth);
    }
    private void setup() {
        loginAsAdmin();
        ArticleCreateRequest req = new ArticleCreateRequest();
        req.setTitle("评论测试文章");
        req.setContent("文章内容");
        req.setStatus("PUBLISHED");
        articleId = articleService.create(req).getId();
    }

    @Test
    @DisplayName("发表顶级评论")
    void create_topLevel() {
        setup();
        CommentCreateRequest req = new CommentCreateRequest();
        req.setContent("这是一条顶级评论");
        CommentDTO comment = commentService.create(articleId, req);
        assertNotNull(comment.getId());
        assertNull(comment.getParentId());
        assertEquals("这是一条顶级评论", comment.getContent());
    }

    @Test
    @DisplayName("发表回复评论")
    void create_reply() {
        setup();

        // 创建顶级评论
        CommentCreateRequest parentReq = new CommentCreateRequest();
        parentReq.setContent("顶级评论");
        CommentDTO parent = commentService.create(articleId, parentReq);

        // 回复
        CommentCreateRequest replyReq = new CommentCreateRequest();
        replyReq.setContent("回复内容");
        replyReq.setParentId(parent.getId());
        CommentDTO reply = commentService.create(articleId, replyReq);

        assertEquals(parent.getId(), reply.getParentId());
    }

    @Test
    @DisplayName("评论树查询包含已删除评论占位")
    void listByArticle_includesDeleted() {
        setup();

        CommentCreateRequest req = new CommentCreateRequest();
        req.setContent("要删除的评论");
        CommentDTO comment = commentService.create(articleId, req);

        // 删除评论
        commentService.delete(comment.getId());

        // 查询评论列表
        List<CommentDTO> comments = commentService.listByArticle(articleId);
        assertEquals(1, comments.size());
        assertEquals(0, comments.get(0).getStatus());
        assertEquals("该评论已删除", comments.get(0).getContent());
    }

    @Test
    @DisplayName("软删除评论级联删除子评论")
    void delete_cascadesToChildren() {
        setup();

        CommentCreateRequest parentReq = new CommentCreateRequest();
        parentReq.setContent("父评论");
        CommentDTO parent = commentService.create(articleId, parentReq);

        CommentCreateRequest childReq = new CommentCreateRequest();
        childReq.setContent("子评论");
        childReq.setParentId(parent.getId());
        CommentDTO child = commentService.create(articleId, childReq);

        // 删除父评论
        commentService.delete(parent.getId());

        // 验证子评论也被软删除
        List<CommentDTO> comments = commentService.listByArticle(articleId);
        long deletedCount = comments.stream().filter(c -> c.getStatus() == 0).count();
        assertEquals(2, deletedCount);
    }

    @Test
    @DisplayName("删除不存在的评论抛异常")
    void delete_notFound() {
        setup();
        assertThrows(BusinessException.class, () -> commentService.delete(99999L));
    }

    @Test
    @DisplayName("重复删除幂等")
    void delete_idempotent() {
        setup();
        CommentCreateRequest req = new CommentCreateRequest();
        req.setContent("幂等测试");
        CommentDTO comment = commentService.create(articleId, req);

        commentService.delete(comment.getId());
        // 再次删除不抛异常
        assertDoesNotThrow(() -> commentService.delete(comment.getId()));
    }

    @Test
    @DisplayName("XSS 内容过滤")
    void create_sanitizesXss() {
        setup();
        CommentCreateRequest req = new CommentCreateRequest();
        req.setContent("<script>alert('xss')</script>正常内容");
        CommentDTO comment = commentService.create(articleId, req);
        assertFalse(comment.getContent().contains("<script>"));
        assertTrue(comment.getContent().contains("正常内容"));
    }

    @Test
    @DisplayName("文章不存在时返回404")
    void listByArticle_notFound() {
        setup();
        assertThrows(BusinessException.class, () -> commentService.listByArticle(99999L));
    }
}
