package com.kb.auth.security;

import com.kb.user.entity.User;
import com.kb.user.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * JWT 无状态认证不依赖 UserDetailsService.loadUserByUsername，
 * 此类仅用于 Spring Security 框架要求（如 DaoAuthenticationProvider 备用）。
 * 实际认证逻辑在 JwtFilter 中完成。
 */
@Service
@RequiredArgsConstructor
public class CustomUserDetailsService implements UserDetailsService {

    private final UserMapper userMapper;

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        User user = userMapper.selectActiveByIdentifier(username);
        if (user == null) {
            throw new UsernameNotFoundException("用户不存在: " + username);
        }
        return new CustomUserDetails(user);
    }

    public UserDetails loadUserById(Long userId) {
        User user = userMapper.selectActiveById(userId);
        if (user == null) {
            throw new UsernameNotFoundException("用户不存在: " + userId);
        }
        return new CustomUserDetails(user);
    }
}
