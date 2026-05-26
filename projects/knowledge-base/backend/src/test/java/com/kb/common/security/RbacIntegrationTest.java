package com.kb.common.security;

import com.kb.auth.dto.LoginRequest;
import com.kb.auth.dto.RegisterRequest;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.kb.user.entity.User;
import com.kb.user.mapper.UserMapper;
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
import org.springframework.transaction.annotation.Transactional;
import com.fasterxml.jackson.databind.JsonNode;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@Import(com.kb.test.TestRedisConfig.class)
    @Sql("/test-data.sql")
@ActiveProfiles("test")
@AutoConfigureMockMvc
@Transactional
class RbacIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserMapper userMapper;

    private String uniqueSuffix() {
        return String.valueOf(System.currentTimeMillis());
    }

    /**
     * 注册用户并修改为指定角色，然后登录
     */
    private String registerLoginWithRole(String baseName, String role) throws Exception {
        String username = baseName + "_" + uniqueSuffix();

        // 注册
        RegisterRequest reg = new RegisterRequest();
        reg.setUsername(username);
        reg.setPassword("Test@12345");
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(reg)))
                .andExpect(status().isOk());

        // 修改角色（直接操作数据库，绕过权限校验）
        User user = userMapper.selectActiveByIdentifier(username);
        user.setRole(role);
        userMapper.updateById(user);

        // 登录
        LoginRequest login = new LoginRequest();
        login.setUsername(username);
        login.setPassword("Test@12345");
        String loginResp = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(login)))
                .andReturn().getResponse().getContentAsString();

        return objectMapper.readTree(loginResp).get("data").get("accessToken").asText();
    }

    @Test
    @DisplayName("未认证访问受保护接口 - 401")
    void unauthenticated_access() throws Exception {
        mockMvc.perform(get("/api/v1/users/me"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("READER 访问 /users/me - 成功")
    void reader_access_me() throws Exception {
        String token = registerLoginWithRole("reader_test", "READER");
        mockMvc.perform(get("/api/v1/users/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.role").value("READER"));
    }

    @Test
    @DisplayName("EDITOR 访问 /users/me - 成功")
    void editor_access_me() throws Exception {
        String token = registerLoginWithRole("editor_test", "EDITOR");
        mockMvc.perform(get("/api/v1/users/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.role").value("EDITOR"));
    }

    @Test
    @DisplayName("ADMIN 访问 /users/me - 成功")
    void admin_access_me() throws Exception {
        String token = registerLoginWithRole("admin_test", "ADMIN");
        mockMvc.perform(get("/api/v1/users/me")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.role").value("ADMIN"));
    }

    @Test
    @DisplayName("不同角色返回各自信息")
    void different_roles_me() throws Exception {
        String token1 = registerLoginWithRole("editor_a", "EDITOR");
        String token2 = registerLoginWithRole("reader_b", "READER");

        String resp1 = mockMvc.perform(get("/api/v1/users/me")
                        .header("Authorization", "Bearer " + token1))
                .andReturn().getResponse().getContentAsString();

        String resp2 = mockMvc.perform(get("/api/v1/users/me")
                        .header("Authorization", "Bearer " + token2))
                .andReturn().getResponse().getContentAsString();

        String username1 = objectMapper.readTree(resp1).get("data").get("username").asText();
        String username2 = objectMapper.readTree(resp2).get("data").get("username").asText();
        assertThat(username1).isNotEqualTo(username2);
    }

    @Test
    @DisplayName("公开路径不需要认证")
    void public_endpoints_no_auth() throws Exception {
        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());
    }
}
