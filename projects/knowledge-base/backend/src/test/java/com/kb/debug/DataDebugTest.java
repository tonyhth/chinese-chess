package com.kb.debug;

import com.kb.user.entity.User;
import com.kb.user.mapper.UserMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import com.kb.test.TestRedisConfig;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.jdbc.Sql;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@Import(com.kb.test.TestRedisConfig.class)
@ActiveProfiles("test")
@Sql("/test-data.sql")
class DataDebugTest {

    @Autowired
    private UserMapper userMapper;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Test
    void generateHash() {
        String hash = passwordEncoder.encode("admin123");
        System.out.println("BCrypt hash for admin123: " + hash);
        assertTrue(passwordEncoder.matches("admin123", hash));
    }

    @Test
    void testDataExists() {
        User admin = userMapper.selectActiveByIdentifier("admin");
        assertNotNull(admin, "admin user should exist");
        assertEquals("ADMIN", admin.getRole());
        System.out.println("Stored hash: " + admin.getPasswordHash());
        System.out.println("Matches admin123: " + passwordEncoder.matches("admin123", admin.getPasswordHash()));
    }

    @Test
    void testRawSelect() {
        var users = userMapper.selectList(null);
        System.out.println("Total users: " + users.size());
        for (var u : users) {
            System.out.println("  - " + u.getId() + ": " + u.getUsername() + " (" + u.getRole() + ")");
        }
        assertFalse(users.isEmpty(), "should have at least one user");
    }
}
