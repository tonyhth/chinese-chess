package com.kb.auth.jwt;

import com.kb.auth.security.CustomUserDetails;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnBean(StringRedisTemplate.class)
public class JwtFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;
    private final StringRedisTemplate redisTemplate;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String token = extractToken(request);
        if (token != null) {
            try {
                Claims claims = jwtUtil.parseClaims(token);

                // refresh token 只允许 /api/v1/auth/refresh
                String tokenType = claims.get("type", String.class);
                String path = request.getRequestURI();
                if ("refresh".equals(tokenType) && !path.equals("/api/v1/auth/refresh")) {
                    log.debug("Rejected refresh token on path={}", path);
                    filterChain.doFilter(request, response);
                    return;
                }

                // 检查黑名单
                String jti = claims.getId();
                Boolean blacklisted = redisTemplate.hasKey("token:blacklist:" + jti);
                if (Boolean.TRUE.equals(blacklisted)) {
                    log.debug("Token blacklisted jti={}", jti);
                    filterChain.doFilter(request, response);
                    return;
                }

                // 从 claims 直接构造 CustomUserDetails，不查库
                Long userId = Long.parseLong(claims.getSubject());
                String username = claims.get("username", String.class);
                String role = claims.get("role", String.class);
                var userDetails = new CustomUserDetails(userId, username, role);

                var auth = new UsernamePasswordAuthenticationToken(
                        userDetails, null, userDetails.getAuthorities()
                );
                SecurityContextHolder.getContext().setAuthentication(auth);
            } catch (ExpiredJwtException e) {
                log.debug("Token expired: {}", e.getMessage());
            } catch (JwtException e) {
                log.debug("Invalid token: {}", e.getMessage());
            } catch (Exception e) {
                log.warn("JWT filter error: {}", e.getMessage());
            }
        }
        filterChain.doFilter(request, response);
    }

    private String extractToken(HttpServletRequest request) {
        String bearer = request.getHeader("Authorization");
        if (StringUtils.hasText(bearer) && bearer.startsWith("Bearer ")) {
            return bearer.substring(7);
        }
        return null;
    }
}
