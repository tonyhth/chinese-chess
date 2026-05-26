package com.kb.dashboard;

import com.kb.auth.service.AuthService;
import com.kb.auth.dto.LoginRequest;
import com.kb.user.dto.UserCreateRequest;
import com.kb.user.service.UserService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import com.kb.test.TestRedisConfig;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.jdbc.Sql;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import com.kb.auth.security.CustomUserDetails;
import org.springframework.transaction.annotation.Transactional;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@Import(com.kb.test.TestRedisConfig.class)
    @Sql("/test-data.sql")
@ActiveProfiles("test")
@AutoConfigureMockMvc
@Transactional
class DashboardControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private AuthService authService;

    @Autowired
    private UserService userService;

    private String adminToken;

    private void loginAdmin() {
        LoginRequest login = new LoginRequest();
        login.setUsername("admin");
        login.setPassword("admin123");
        adminToken = authService.login(login).getAccessToken();
    }

    @Test
    @DisplayName("ADMIN 可以访问 Dashboard")
    void admin_canAccess() throws Exception {
        loginAdmin();
        mockMvc.perform(get("/api/v1/dashboard/stats")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.articleCount").isNumber())
                .andExpect(jsonPath("$.data.userCount").isNumber());
    }

    @Test
    @DisplayName("EDITOR 不能访问 Dashboard 返回 403")
    void editor_forbidden() throws Exception {
        loginAdmin();
        // 创建 EDITOR 用户
        UserCreateRequest req = new UserCreateRequest();
        req.setUsername("editor_dashboard_" + System.currentTimeMillis());
        req.setPassword("Editor@1234");
        req.setRole("EDITOR");
        var editor = userService.create(req);

        LoginRequest editorLogin = new LoginRequest();
        editorLogin.setUsername(editor.getUsername());
        editorLogin.setPassword("Editor@1234");
        String editorToken = authService.login(editorLogin).getAccessToken();

        mockMvc.perform(get("/api/v1/dashboard/stats")
                        .header("Authorization", "Bearer " + editorToken))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("未登录访问 Dashboard 返回 401")
    void unauthenticated_401() throws Exception {
        mockMvc.perform(get("/api/v1/dashboard/stats"))
                .andExpect(status().isUnauthorized());
    }
}
