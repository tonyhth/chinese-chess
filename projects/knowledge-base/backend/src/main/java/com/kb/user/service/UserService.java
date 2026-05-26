package com.kb.user.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.kb.common.BusinessException;
import com.kb.common.ErrorCode;
import com.kb.common.PageResult;
import com.kb.common.security.PermissionService;
import com.kb.user.dto.UserCreateRequest;
import com.kb.user.dto.UserDTO;
import com.kb.user.dto.UserUpdateRequest;
import com.kb.user.entity.User;
import com.kb.user.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class UserService {

    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;
    private final PermissionService permissionService;

    public PageResult<UserDTO> list(int page, int size) {
        permissionService.checkAdminOnly();

        Page<User> p = new Page<>(page, size);
        LambdaQueryWrapper<User> wrapper = new LambdaQueryWrapper<>();
        wrapper.isNull(User::getDeletedAt)
                .orderByDesc(User::getCreatedAt);
        Page<User> result = userMapper.selectPage(p, wrapper);

        List<UserDTO> records = result.getRecords().stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
        return new PageResult<>(records, result.getTotal(), page, size);
    }

    @Transactional
    public UserDTO create(UserCreateRequest request) {
        permissionService.checkAdminOnly();

        // 校验角色
        validateRole(request.getRole());

        // 检查用户名唯一
        long count = userMapper.selectCount(
                new LambdaQueryWrapper<User>()
                        .eq(User::getUsername, request.getUsername())
                        .isNull(User::getDeletedAt));
        if (count > 0) {
            throw new BusinessException(ErrorCode.USER_ALREADY_EXISTS);
        }

        User user = new User();
        user.setUsername(request.getUsername());
        user.setPasswordHash(passwordEncoder.encode(request.getPassword()));
        user.setEmail(request.getEmail());
        user.setRole(request.getRole());
        user.setStatus(1);
        userMapper.insert(user);

        log.info("管理员创建用户: {} ({})", user.getUsername(), user.getRole());
        return toDTO(user);
    }

    @Transactional
    public UserDTO update(Long id, UserUpdateRequest request) {
        permissionService.checkAdminOnly();
        User user = userMapper.selectActiveById(id);
        if (user == null) {
            throw new BusinessException(ErrorCode.USER_NOT_FOUND);
        }

        if (StringUtils.hasText(request.getUsername())) {
            // 校验用户名唯一性（排除自身）
            long count = userMapper.selectCount(
                    new LambdaQueryWrapper<User>()
                            .eq(User::getUsername, request.getUsername())
                            .isNull(User::getDeletedAt)
                            .ne(User::getId, id));
            if (count > 0) {
                throw new BusinessException(ErrorCode.USER_ALREADY_EXISTS);
            }
            user.setUsername(request.getUsername());
        }
        if (request.getEmail() != null) {
            user.setEmail(request.getEmail());
        }
        if (request.getAvatarUrl() != null) {
            user.setAvatarUrl(request.getAvatarUrl());
        }
        userMapper.updateById(user);
        return toDTO(user);
    }

    @Transactional
    public void delete(Long id) {
        permissionService.checkAdminOnly();
        User user = userMapper.selectActiveById(id);
        if (user == null) {
            throw new BusinessException(ErrorCode.USER_NOT_FOUND);
        }

        // 不能删除自己
        if (user.getId().equals(permissionService.currentUserId())) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "不能删除自己");
        }

        user.setDeletedAt(LocalDateTime.now());
        userMapper.updateById(user);
        log.info("管理员删除用户: {}", user.getUsername());
    }

    @Transactional
    public UserDTO updateRole(Long id, String role) {
        permissionService.checkAdminOnly();
        validateRole(role);

        User user = userMapper.selectActiveById(id);
        if (user == null) {
            throw new BusinessException(ErrorCode.USER_NOT_FOUND);
        }

        if (user.getId().equals(permissionService.currentUserId())) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "不能修改自己的角色");
        }

        String oldRole = user.getRole();
        user.setRole(role);
        userMapper.updateById(user);
        log.info("管理员修改用户 {} 角色: {} -> {}", user.getUsername(), oldRole, role);
        return toDTO(user);
    }

    public long count() {
        return Math.toIntExact(userMapper.selectCount(new com.baomidou.mybatisplus.core.conditions.query.QueryWrapper<User>().isNull("deleted_at")));
    }

    public UserDTO getMe(Long userId) {
        User user = userMapper.selectActiveById(userId);
        if (user == null) {
            throw new com.kb.common.BusinessException(com.kb.common.ErrorCode.UNAUTHORIZED);
        }
        return toDTO(user);
    }

    /**
     * 搜索用户（模糊匹配 username 或 email），用于权限管理对话框
     */
    public PageResult<UserDTO> searchUsers(String keyword, int page, int size) {
        if (!StringUtils.hasText(keyword)) {
            return new PageResult<>(List.of(), 0L, page, size);
        }
        String pattern = "%" + keyword + "%";
        LambdaQueryWrapper<User> wrapper = new LambdaQueryWrapper<>()
                .isNull(User::getDeletedAt)
                .and(w -> w.like(User::getUsername, keyword).or().like(User::getEmail, keyword))
                .orderByAsc(User::getUsername);

        Page<User> p = new Page<>(page, size);
        Page<User> result = userMapper.selectPage(p, wrapper);

        List<UserDTO> records = result.getRecords().stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
        return new PageResult<>(records, result.getTotal(), page, size);
    }

    private void validateRole(String role) {
        if (!List.of("ADMIN", "EDITOR", "READER").contains(role)) {
            throw new BusinessException(ErrorCode.BAD_REQUEST, "无效的角色: " + role);
        }
    }

    private UserDTO toDTO(User user) {
        UserDTO dto = new UserDTO();
        dto.setId(user.getId());
        dto.setUsername(user.getUsername());
        dto.setEmail(user.getEmail());
        dto.setAvatarUrl(user.getAvatarUrl());
        dto.setRole(user.getRole());
        return dto;
    }
}
