package com.kb.auth.service;

import com.kb.auth.dto.*;
import com.kb.auth.jwt.JwtUtil;
import com.kb.common.BusinessException;
import com.kb.common.ErrorCode;
import com.kb.user.entity.User;
import com.kb.user.mapper.UserMapper;
import io.jsonwebtoken.Claims;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final StringRedisTemplate redisTemplate;

    public TokenResponse register(RegisterRequest request) {
        // 检查用户名是否已存在
        User existing = userMapper.selectActiveByIdentifier(request.getUsername());
        if (existing != null) {
            throw new BusinessException(ErrorCode.USER_ALREADY_EXISTS);
        }

        // 检查邮箱是否已存在
        if (request.getEmail() != null) {
            User byEmail = userMapper.selectActiveByEmail(request.getEmail());
            if (byEmail != null) {
                throw new BusinessException(ErrorCode.BAD_REQUEST, "邮箱已被注册");
            }
        }

        User user = new User();
        user.setUsername(request.getUsername());
        user.setPasswordHash(passwordEncoder.encode(request.getPassword()));
        user.setEmail(request.getEmail());
        user.setRole("READER");
        user.setStatus(1);
        userMapper.insert(user);

        return generateTokenPair(user);
    }

    public TokenResponse login(LoginRequest request) {
        User user = userMapper.selectActiveByIdentifier(request.getUsername());
        if (user == null || !passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "用户名或密码错误");
        }

        if (user.getStatus() != 1) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "账号已禁用");
        }

        return generateTokenPair(user);
    }

    public TokenResponse refresh(RefreshRequest request) {
        // 校验 refresh_token 有效性
        if (!jwtUtil.isRefreshToken(request.getRefreshToken())) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "无效的 refresh_token");
        }

        Claims claims;
        try {
            claims = jwtUtil.parseClaims(request.getRefreshToken());
        } catch (Exception e) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "refresh_token 已过期或无效");
        }

        // 检查黑名单
        String jti = claims.getId();
        Boolean blacklisted = redisTemplate.hasKey("token:blacklist:" + jti);
        if (Boolean.TRUE.equals(blacklisted)) {
            throw new BusinessException(ErrorCode.UNAUTHORIZED, "refresh_token 已失效");
        }

        Long userId = Long.parseLong(claims.getSubject());
        User user = userMapper.selectActiveById(userId);
        if (user == null) {
            throw new BusinessException(ErrorCode.USER_NOT_FOUND);
        }

        if (user.getStatus() != 1) {
            throw new BusinessException(ErrorCode.FORBIDDEN, "账号已禁用");
        }

        // 旧 refresh_token 加入黑名单
        addToBlacklist(request.getRefreshToken());

        return generateTokenPair(user);
    }

    public void logout(String accessToken, String refreshToken) {
        // access_token 加入黑名单
        addToBlacklist(accessToken);

        // refresh_token 也加入黑名单（如果前端传了）
        if (refreshToken != null && !refreshToken.isBlank()) {
            addToBlacklist(refreshToken);
        }
    }

    private TokenResponse generateTokenPair(User user) {
        String accessToken = jwtUtil.createAccessToken(user.getId(), user.getUsername(), user.getRole());
        String refreshToken = jwtUtil.createRefreshToken(user.getId(), user.getUsername(), user.getRole());
        long expiresIn = jwtUtil.getRemainingMs(accessToken) / 1000;
        return new TokenResponse(accessToken, refreshToken, expiresIn);
    }

    private void addToBlacklist(String token) {
        try {
            String jti = jwtUtil.getJti(token);
            long remainingMs = jwtUtil.getRemainingMs(token);
            if (remainingMs > 0) {
                redisTemplate.opsForValue().set(
                        "token:blacklist:" + jti, "1",
                        java.time.Duration.ofMillis(remainingMs)
                );
            }
        } catch (Exception e) {
            log.warn("Failed to blacklist token: {}", e.getMessage());
        }
    }
}
