package com.kb.auth.security;

import com.kb.user.entity.User;
import lombok.Getter;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.List;

/**
 * 轻量 UserDetails，可从 JWT claims 直接构造（不查库），
 * 也可从数据库 User 实体构造。
 */
@Getter
public class CustomUserDetails implements UserDetails {

    private final Long id;
    private final String username;
    private final String passwordHash;
    private final String role;
    private final Integer status;
    private final List<SimpleGrantedAuthority> authorities;

    /**
     * 从 JWT claims 构造（不查库，用于 JwtFilter）
     */
    public CustomUserDetails(Long id, String username, String role) {
        this.id = id;
        this.username = username;
        this.passwordHash = null;
        this.role = role;
        this.status = 1;
        this.authorities = List.of(new SimpleGrantedAuthority("ROLE_" + role));
    }

    /**
     * 从数据库实体构造（用于需要完整用户信息的场景）
     */
    public CustomUserDetails(User user) {
        this.id = user.getId();
        this.username = user.getUsername();
        this.passwordHash = user.getPasswordHash();
        this.role = user.getRole();
        this.status = user.getStatus();
        this.authorities = List.of(new SimpleGrantedAuthority("ROLE_" + user.getRole()));
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return authorities;
    }

    @Override
    public String getPassword() {
        return passwordHash;
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return true;
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    @Override
    public boolean isEnabled() {
        return status != null && status == 1;
    }
}
