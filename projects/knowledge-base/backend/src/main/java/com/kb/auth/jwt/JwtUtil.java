package com.kb.auth.jwt;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import lombok.Getter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.UUID;

@Component
public class JwtUtil {

    private final SecretKey key;
    private final long accessExpire;
    private final long refreshExpire;

    public JwtUtil(
            @Value("${jwt.secret}") String secret,
            @Value("${jwt.access-expire}") long accessExpire,
            @Value("${jwt.refresh-expire}") long refreshExpire) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.accessExpire = accessExpire * 1000;
        this.refreshExpire = refreshExpire * 1000;
    }

    public String createAccessToken(Long userId, String username, String role) {
        return createToken(userId, username, role, accessExpire, "access");
    }

    public String createRefreshToken(Long userId, String username, String role) {
        return createToken(userId, username, role, refreshExpire, "refresh");
    }

    private String createToken(Long userId, String username, String role, long expireMs, String type) {
        return Jwts.builder()
                .id(UUID.randomUUID().toString())
                .subject(String.valueOf(userId))
                .claim("username", username)
                .claim("role", role)
                .claim("type", type)
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + expireMs))
                .signWith(key)
                .compact();
    }

    public Claims parseClaims(String token) {
        return Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    public boolean isAccessToken(String token) {
        try {
            Claims claims = parseClaims(token);
            return "access".equals(claims.get("type", String.class));
        } catch (Exception e) {
            return false;
        }
    }

    public boolean isRefreshToken(String token) {
        try {
            Claims claims = parseClaims(token);
            return "refresh".equals(claims.get("type", String.class));
        } catch (Exception e) {
            return false;
        }
    }

    public String getJti(String token) {
        Claims claims = parseClaims(token);
        return claims.getId();
    }

    public long getRemainingMs(String token) {
        Claims claims = parseClaims(token);
        return claims.getExpiration().getTime() - System.currentTimeMillis();
    }
}
