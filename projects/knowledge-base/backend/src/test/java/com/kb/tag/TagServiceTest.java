package com.kb.tag;

import com.kb.auth.service.AuthService;
import com.kb.auth.dto.LoginRequest;
import com.kb.common.BusinessException;
import com.kb.tag.dto.TagCreateRequest;
import com.kb.tag.dto.TagUpdateRequest;
import com.kb.tag.entity.Tag;
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
class TagServiceTest {

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

    @Test
    @DisplayName("创建标签")
    void create_success() {
        loginAsAdmin();
        TagCreateRequest req = new TagCreateRequest();
        req.setName("Java");
        req.setColor("#4361ee");
        Tag tag = tagService.create(req);
        assertNotNull(tag.getId());
        assertEquals("Java", tag.getName());
        assertEquals("#4361ee", tag.getColor());
    }

    @Test
    @DisplayName("创建重复名称标签抛异常")
    void create_duplicateName() {
        loginAsAdmin();
        TagCreateRequest req = new TagCreateRequest();
        req.setName("重复标签");
        tagService.create(req);

        TagCreateRequest req2 = new TagCreateRequest();
        req2.setName("重复标签");
        assertThrows(BusinessException.class, () -> tagService.create(req2));
    }

    @Test
    @DisplayName("标签列表")
    void list() {
        loginAsAdmin();
        TagCreateRequest req = new TagCreateRequest();
        req.setName("列表标签");
        tagService.create(req);

        List<Tag> tags = tagService.list();
        assertFalse(tags.isEmpty());
    }

    @Test
    @DisplayName("更新标签")
    void update_success() {
        loginAsAdmin();
        TagCreateRequest req = new TagCreateRequest();
        req.setName("原标签");
        Long id = tagService.create(req).getId();

        TagUpdateRequest update = new TagUpdateRequest();
        update.setName("新标签");
        update.setColor("#ff0000");
        Tag updated = tagService.update(id, update);
        assertEquals("新标签", updated.getName());
        assertEquals("#ff0000", updated.getColor());
    }

    @Test
    @DisplayName("更新不存在的标签抛异常")
    void update_notFound() {
        loginAsAdmin();
        TagUpdateRequest update = new TagUpdateRequest();
        update.setName("不存在");
        assertThrows(BusinessException.class, () -> tagService.update(99999L, update));
    }

    @Test
    @DisplayName("更新标签名重复抛异常")
    void update_duplicateName() {
        loginAsAdmin();
        tagService.create(new TagCreateRequest() {{ setName("标签A"); }});
        Long id = tagService.create(new TagCreateRequest() {{ setName("标签B"); }}).getId();

        TagUpdateRequest update = new TagUpdateRequest();
        update.setName("标签A");
        assertThrows(BusinessException.class, () -> tagService.update(id, update));
    }

    @Test
    @DisplayName("删除标签")
    void delete_success() {
        loginAsAdmin();
        Long id = tagService.create(new TagCreateRequest() {{ setName("可删除"); }}).getId();
        assertDoesNotThrow(() -> tagService.delete(id));
    }
}
