package com.kb.auth.controller;

import com.kb.common.Result;
import com.kb.auth.dto.LoginRequest;
import com.kb.auth.dto.LogoutRequest;
import com.kb.auth.dto.RegisterRequest;
import com.kb.auth.dto.RefreshRequest;
import com.kb.auth.dto.TokenResponse;
import com.kb.auth.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
@Tag(name = "认证", description = "用户注册、登录、刷新、登出")
public class AuthController {

    private final AuthService authService;

    @PostMapping("/register")
    @Operation(summary = "用户注册")
    public Result<TokenResponse> register(@Valid @RequestBody RegisterRequest request) {
        return Result.ok(authService.register(request));
    }

    @PostMapping("/login")
    @Operation(summary = "用户登录")
    public Result<TokenResponse> login(@Valid @RequestBody LoginRequest request) {
        return Result.ok(authService.login(request));
    }

    @PostMapping("/refresh")
    @Operation(summary = "刷新 Token")
    public Result<TokenResponse> refresh(@Valid @RequestBody RefreshRequest request) {
        return Result.ok(authService.refresh(request));
    }

    @PostMapping("/logout")
    @Operation(summary = "用户登出（需认证）")
    public Result<Void> logout(
            @RequestHeader("Authorization") String bearerToken,
            @RequestBody(required = false) LogoutRequest request) {
        String accessToken = bearerToken.startsWith("Bearer ") ? bearerToken.substring(7) : bearerToken;
        authService.logout(accessToken, request != null ? request.getRefreshToken() : null);
        return Result.ok();
    }
}
