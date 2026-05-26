package com.kb.user;

import com.kb.auth.service.AuthService;
import com.kb.auth.dto.LoginRequest;
import com.kb.common.BusinessException;
import com.kb.user.dto.UserCreateRequest;
import com.kb.user.dto.UserDTO;
import com.kb.user.dto.UserUpdateRequest;
import com.kb.user.dto.RoleUpdateRequest;
import com.kb.user.entity.User;
import com.kb.user.mapper.UserMapper;
import com.kb.user.service.UserService;
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

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@Import(com.kb.test.TestRedisConfig.class)
    @Sql("/test-data.sql")
@ActiveProfiles("test")
@Transactional
class UserServiceTest {

    @Autowired
    private UserService userService;

    @Autowired
    private UserMapper userMapper;

    @Autowired
    private AuthService authService;

    private String adminToken;
    private Long adminId;

    private void loginAsAdmin() {
        CustomUserDetails admin = new CustomUserDetails(1L, "admin", "ADMIN");
        var auth = new UsernamePasswordAuthenticationToken(admin, null, admin.getAuthorities());
        SecurityContextHolder.getContext().setAuthentication(auth);
    }
    @Test
    @DisplayName("创建用户")
    void create_success() {
        loginAsAdmin();
        UserCreateRequest req = new UserCreateRequest();
        req.setUsername("newuser_" + System.currentTimeMillis());
        req.setPassword("Test@1234");
        req.setEmail("new@test.com");
        req.setRole("READER");

        UserDTO dto = userService.create(req);
        assertNotNull(dto.getId());
        assertEquals("READER", dto.getRole());
    }

    @Test
    @DisplayName("创建用户 — 用户名已存在")
    void create_duplicateUsername() {
        loginAsAdmin();
        UserCreateRequest req = new UserCreateRequest();
        req.setUsername("admin");
        req.setPassword("Test@1234");
        assertThrows(BusinessException.class, () -> userService.create(req));
    }

    @Test
    @DisplayName("创建用户 — 无效角色")
    void create_invalidRole() {
        loginAsAdmin();
        UserCreateRequest req = new UserCreateRequest();
        req.setUsername("roleuser_" + System.currentTimeMillis());
        req.setPassword("Test@1234");
        req.setRole("SUPERADMIN");
        assertThrows(BusinessException.class, () -> userService.create(req));
    }

    @Test
    @DisplayName("用户列表")
    void list_success() {
        loginAsAdmin();
        var result = userService.list(1, 20);
        assertNotNull(result.getRecords());
        assertTrue(result.getTotal() > 0);
    }

    @Test
    @DisplayName("更新用户信息")
    void update_success() {
        loginAsAdmin();
        UserCreateRequest create = new UserCreateRequest();
        create.setUsername("updateuser_" + System.currentTimeMillis());
        create.setPassword("Test@1234");
        Long id = userService.create(create).getId();

        UserUpdateRequest update = new UserUpdateRequest();
        update.setEmail("updated@test.com");
        UserDTO dto = userService.update(id, update);
        assertEquals("updated@test.com", dto.getEmail());
    }

    @Test
    @DisplayName("更新用户 — 用户名唯一性")
    void update_duplicateUsername() {
        loginAsAdmin();
        UserCreateRequest create = new UserCreateRequest();
        create.setUsername("unique_" + System.currentTimeMillis());
        create.setPassword("Test@1234");
        Long id = userService.create(create).getId();

        UserUpdateRequest update = new UserUpdateRequest();
        update.setUsername("admin");
        assertThrows(BusinessException.class, () -> userService.update(id, update));
    }

    @Test
    @DisplayName("删除用户")
    void delete_success() {
        loginAsAdmin();
        UserCreateRequest create = new UserCreateRequest();
        create.setUsername("deluser_" + System.currentTimeMillis());
        create.setPassword("Test@1234");
        Long id = userService.create(create).getId();

        assertDoesNotThrow(() -> userService.delete(id));
        assertNull(userMapper.selectActiveById(id));
    }

    @Test
    @DisplayName("不能删除自己")
    void delete_self() {
        loginAsAdmin();
        assertThrows(BusinessException.class, () -> userService.delete(adminId));
    }

    @Test
    @DisplayName("修改角色")
    void updateRole_success() {
        loginAsAdmin();
        UserCreateRequest create = new UserCreateRequest();
        create.setUsername("rolechange_" + System.currentTimeMillis());
        create.setPassword("Test@1234");
        Long id = userService.create(create).getId();

        UserDTO dto = userService.updateRole(id, "EDITOR");
        assertEquals("EDITOR", dto.getRole());
    }

    @Test
    @DisplayName("不能修改自己的角色")
    void updateRole_self() {
        loginAsAdmin();
        assertThrows(BusinessException.class, () -> userService.updateRole(adminId, "READER"));
    }
}
