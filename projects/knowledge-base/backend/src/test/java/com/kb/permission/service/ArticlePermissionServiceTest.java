package com.kb.permission.service;

import com.kb.common.BusinessException;
import com.kb.common.ErrorCode;
import com.kb.permission.dto.PermissionDTO;
import com.kb.permission.dto.PermissionGrantRequest;
import com.kb.permission.entity.ArticlePermission;
import com.kb.permission.mapper.ArticlePermissionMapper;
import com.kb.user.entity.User;
import com.kb.user.mapper.UserMapper;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.*;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ArticlePermissionServiceTest {

    @Mock private ArticlePermissionMapper articlePermissionMapper;
    @Mock private UserMapper userMapper;
    @Mock private com.kb.common.security.PermissionService permissionService;

    @InjectMocks private ArticlePermissionService articlePermissionService;

    private User adminUser;
    private User editorUser;
    private User readerUser;

    @BeforeEach
    void setUp() {
        adminUser = new User(); adminUser.setId(1L); adminUser.setUsername("admin"); adminUser.setRole("ADMIN");
        editorUser = new User(); editorUser.setId(2L); editorUser.setUsername("editor1"); editorUser.setRole("EDITOR");
        readerUser = new User(); readerUser.setId(3L); readerUser.setUsername("reader1"); readerUser.setRole("READER");
    }

    // --- setPermissions ---

    @Test
    @DisplayName("ADMIN 授权用户 VIEW 权限 - 成功")
    void admin_grantView() {
        when(permissionService.currentUserId()).thenReturn(1L);
        when(permissionService.isAdmin()).thenReturn(true);
        when(userMapper.selectActiveById(3L)).thenReturn(readerUser);
        when(articlePermissionMapper.findByArticleAndUser(100L, 3L)).thenReturn(null);

        List<PermissionGrantRequest> reqs = List.of(
            new PermissionGrantRequest() {{ setUserId(3L); setPermission("VIEW"); }}
        );
        List<PermissionDTO> result = articlePermissionService.setPermissions(100L, reqs);
        assertThat(result).isNotEmpty();
        verify(articlePermissionMapper).insert(any(ArticlePermission.class));
    }

    @Test
    @DisplayName("通过 username 授权 - 成功")
    void grantByUsername() {
        when(permissionService.currentUserId()).thenReturn(1L);
        when(permissionService.isAdmin()).thenReturn(true);
        when(userMapper.selectActiveByIdentifier("reader1")).thenReturn(readerUser);
        when(articlePermissionMapper.findByArticleAndUser(100L, 3L)).thenReturn(null);

        List<PermissionGrantRequest> reqs = List.of(
            new PermissionGrantRequest() {{ setUsername("reader1"); setPermission("EDIT"); }}
        );
        List<PermissionDTO> result = articlePermissionService.setPermissions(100L, reqs);
        assertThat(result).hasSize(1);
        verify(articlePermissionMapper).insert(any(ArticlePermission.class));
    }

    @Test
    @DisplayName("不能对自己授权 - 抛出异常")
    void cannotGrantSelf() {
        when(permissionService.currentUserId()).thenReturn(1L);
        when(permissionService.isAdmin()).thenReturn(true);
        when(userMapper.selectActiveById(1L)).thenReturn(adminUser);

        List<PermissionGrantRequest> reqs = List.of(
            new PermissionGrantRequest() {{ setUserId(1L); setPermission("VIEW"); }}
        );
        assertThatThrownBy(() -> articlePermissionService.setPermissions(100L, reqs))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    @DisplayName("缺少 userId 和 username - 抛出异常")
    void missingIdentifier() {
        when(permissionService.currentUserId()).thenReturn(1L);
        when(permissionService.isAdmin()).thenReturn(true);

        List<PermissionGrantRequest> reqs = List.of(
            new PermissionGrantRequest() {{ setPermission("VIEW"); }}
        );
        assertThatThrownBy(() -> articlePermissionService.setPermissions(100L, reqs))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    @DisplayName("无效权限级别 - 抛出异常")
    void invalidPermissionLevel() {
        when(permissionService.currentUserId()).thenReturn(1L);
        when(permissionService.isAdmin()).thenReturn(true);
        when(userMapper.selectActiveById(3L)).thenReturn(readerUser);

        List<PermissionGrantRequest> reqs = List.of(
            new PermissionGrantRequest() {{ setUserId(3L); setPermission("OWNER"); }}
        );
        assertThatThrownBy(() -> articlePermissionService.setPermissions(100L, reqs))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    @DisplayName("用户不存在 - 抛出异常")
    void userNotFound() {
        when(permissionService.currentUserId()).thenReturn(1L);
        when(permissionService.isAdmin()).thenReturn(true);
        when(userMapper.selectActiveById(999L)).thenReturn(null);

        List<PermissionGrantRequest> reqs = List.of(
            new PermissionGrantRequest() {{ setUserId(999L); setPermission("VIEW"); }}
        );
        assertThatThrownBy(() -> articlePermissionService.setPermissions(100L, reqs))
                .isInstanceOf(BusinessException.class);
    }

    @Test
    @DisplayName("非 ADMIN 且无 MANAGE 权限 - 403")
    void noManagePermission_forbidden() {
        when(permissionService.currentUserId()).thenReturn(2L);
        when(permissionService.isAdmin()).thenReturn(false);
        when(articlePermissionMapper.getPermissionLevel(100L, 2L)).thenReturn(null);

        List<PermissionGrantRequest> reqs = List.of(
            new PermissionGrantRequest() {{ setUserId(3L); setPermission("VIEW"); }}
        );
        assertThatThrownBy(() -> articlePermissionService.setPermissions(100L, reqs))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo(ErrorCode.FORBIDDEN);
    }

    @Test
    @DisplayName("已有权限时更新 (upsert) - 成功")
    void updateExistingPermission() {
        when(permissionService.currentUserId()).thenReturn(1L);
        when(permissionService.isAdmin()).thenReturn(true);
        when(userMapper.selectActiveById(3L)).thenReturn(readerUser);
        ArticlePermission existing = new ArticlePermission();
        existing.setId(10L); existing.setArticleId(100L); existing.setUserId(3L);
        existing.setPermission("VIEW");
        when(articlePermissionMapper.findByArticleAndUser(100L, 3L)).thenReturn(existing);

        List<PermissionGrantRequest> reqs = List.of(
            new PermissionGrantRequest() {{ setUserId(3L); setPermission("EDIT"); }}
        );
        List<PermissionDTO> result = articlePermissionService.setPermissions(100L, reqs);
        assertThat(result).hasSize(1);
        verify(articlePermissionMapper).updateById(any(ArticlePermission.class));
        verify(articlePermissionMapper, never()).insert(any());
    }

    // --- listPermissionsWithCheck ---

    @Test
    @DisplayName("listPermissionsWithCheck - 非 ADMIN 无 MANAGE 权限 403")
    void listPermissions_forbidden() {
        when(permissionService.currentUserId()).thenReturn(3L);
        when(permissionService.isAdmin()).thenReturn(false);
        when(articlePermissionMapper.getPermissionLevel(100L, 3L)).thenReturn(null);

        assertThatThrownBy(() -> articlePermissionService.listPermissionsWithCheck(100L))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode())
                .isEqualTo(ErrorCode.FORBIDDEN);
    }

    // --- removePermission ---

    @Test
    @DisplayName("ADMIN 移除权限 - 成功")
    void admin_removePermission() {
        when(permissionService.currentUserId()).thenReturn(1L);
        when(permissionService.isAdmin()).thenReturn(true);
        ArticlePermission ap = new ArticlePermission();
        ap.setId(10L); ap.setArticleId(100L); ap.setUserId(3L);
        when(articlePermissionMapper.findByArticleAndUser(100L, 3L)).thenReturn(ap);

        assertThatNoException().isThrownBy(() -> articlePermissionService.removePermission(100L, 3L));
        verify(articlePermissionMapper).deleteById(10L);
    }

    @Test
    @DisplayName("权限不存在 - 不报错（幂等）")
    void removeNonExistentPermission() {
        when(permissionService.currentUserId()).thenReturn(1L);
        when(permissionService.isAdmin()).thenReturn(true);
        when(articlePermissionMapper.findByArticleAndUser(100L, 3L)).thenReturn(null);

        assertThatNoException().isThrownBy(() -> articlePermissionService.removePermission(100L, 3L));
        verify(articlePermissionMapper, never()).deleteById(anyLong());
    }

    // --- hasPermission ---

    @Test
    @DisplayName("VIEW 权限满足 EDIT 要求 - false")
    void viewDoesNotSatisfyEdit() {
        when(articlePermissionMapper.getPermissionLevel(100L, 3L)).thenReturn("VIEW");
        assertThat(articlePermissionService.hasPermission(100L, 3L, "EDIT")).isFalse();
    }

    @Test
    @DisplayName("EDIT 权限满足 VIEW 要求 - true")
    void editSatisfiesView() {
        when(articlePermissionMapper.getPermissionLevel(100L, 3L)).thenReturn("EDIT");
        assertThat(articlePermissionService.hasPermission(100L, 3L, "VIEW")).isTrue();
    }

    @Test
    @DisplayName("MANAGE 权限满足所有要求 - true")
    void manageSatisfiesAll() {
        when(articlePermissionMapper.getPermissionLevel(100L, 3L)).thenReturn("MANAGE");
        assertThat(articlePermissionService.hasPermission(100L, 3L, "VIEW")).isTrue();
        assertThat(articlePermissionService.hasPermission(100L, 3L, "EDIT")).isTrue();
        assertThat(articlePermissionService.hasPermission(100L, 3L, "MANAGE")).isTrue();
    }

    @Test
    @DisplayName("无权限 - false")
    void noPermission() {
        when(articlePermissionMapper.getPermissionLevel(100L, 3L)).thenReturn(null);
        assertThat(articlePermissionService.hasPermission(100L, 3L, "VIEW")).isFalse();
    }

    // --- batchQuery ---

    @Test
    @DisplayName("ADMIN batchQuery 全部返回 MANAGE")
    void admin_batchQuery() {
        when(permissionService.currentUserId()).thenReturn(1L);
        when(permissionService.isAdmin()).thenReturn(true);
        Map<Long, String> result = articlePermissionService.batchQuery(List.of(100L, 101L));
        assertThat(result).hasSize(2);
        assertThat(result.get(100L)).isEqualTo("MANAGE");
    }

    @Test
    @DisplayName("普通用户 batchQuery 只返回有权限的")
    void user_batchQuery() {
        when(permissionService.currentUserId()).thenReturn(3L);
        when(permissionService.isAdmin()).thenReturn(false);
        ArticlePermission ap = new ArticlePermission();
        ap.setArticleId(100L); ap.setUserId(3L); ap.setPermission("VIEW");
        when(articlePermissionMapper.listByArticleIds(3L, List.of(100L, 101L))).thenReturn(List.of(ap));
        Map<Long, String> result = articlePermissionService.batchQuery(List.of(100L, 101L));
        assertThat(result).containsEntry(100L, "VIEW");
        assertThat(result).doesNotContainKey(101L);
    }
}
