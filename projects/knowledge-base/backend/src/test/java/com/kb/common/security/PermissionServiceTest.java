package com.kb.common.security;

import com.kb.article.entity.Article;
import com.kb.article.mapper.ArticleMapper;
import com.kb.auth.security.CustomUserDetails;
import com.kb.common.BusinessException;
import com.kb.common.ErrorCode;
import com.kb.permission.service.ArticlePermissionService;
import com.kb.permission.service.CategoryPermissionService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PermissionServiceTest {

    @Mock
    private ArticleMapper articleMapper;
    @Mock
    private ArticlePermissionService articlePermissionService;
    @Mock
    private CategoryPermissionService categoryPermissionService;

    @InjectMocks
    private PermissionService permissionService;

    private CustomUserDetails admin;
    private CustomUserDetails editor;
    private CustomUserDetails reader;
    private CustomUserDetails otherEditor;

    private Article publishedArticle;
    private Article draftArticle;
    private Article archivedArticle;
    private Article editorsArticle;
    private Article othersArticle;

    @BeforeEach
    void setUp() {
        admin = new CustomUserDetails(1L, "admin", "ADMIN");
        editor = new CustomUserDetails(2L, "editor1", "EDITOR");
        reader = new CustomUserDetails(3L, "reader1", "READER");
        otherEditor = new CustomUserDetails(4L, "editor2", "EDITOR");

        publishedArticle = new Article();
        publishedArticle.setId(100L);
        publishedArticle.setStatus("PUBLISHED");
        publishedArticle.setAuthorId(2L);

        draftArticle = new Article();
        draftArticle.setId(101L);
        draftArticle.setStatus("DRAFT");
        draftArticle.setAuthorId(2L); // editor1 的草稿

        archivedArticle = new Article();
        archivedArticle.setId(102L);
        archivedArticle.setStatus("ARCHIVED");
        archivedArticle.setAuthorId(2L);

        editorsArticle = new Article();
        editorsArticle.setId(103L);
        editorsArticle.setStatus("PUBLISHED");
        editorsArticle.setAuthorId(2L); // editor1 的文章

        othersArticle = new Article();
        othersArticle.setId(104L);
        othersArticle.setStatus("PUBLISHED");
        othersArticle.setAuthorId(4L); // editor2 的文章
    }

    private void loginAs(CustomUserDetails user) {
        var auth = new UsernamePasswordAuthenticationToken(user, null, user.getAuthorities());
        SecurityContextHolder.getContext().setAuthentication(auth);
    }

    @Test
    @DisplayName("ADMIN 查看已发布文章 - 成功")
    void admin_viewPublished() {
        loginAs(admin);
        when(articleMapper.selectActiveById(100L)).thenReturn(publishedArticle);
        assertThatNoException().isThrownBy(() -> permissionService.checkArticleVisible(100L));
    }

    @Test
    @DisplayName("EDITOR 查看已发布文章 - 成功")
    void editor_viewPublished() {
        loginAs(editor);
        when(articleMapper.selectActiveById(100L)).thenReturn(publishedArticle);
        assertThatNoException().isThrownBy(() -> permissionService.checkArticleVisible(100L));
    }

    @Test
    @DisplayName("READER 查看已发布文章 - 成功")
    void reader_viewPublished() {
        loginAs(reader);
        when(articleMapper.selectActiveById(100L)).thenReturn(publishedArticle);
        assertThatNoException().isThrownBy(() -> permissionService.checkArticleVisible(100L));
    }

    @Test
    @DisplayName("EDITOR 查看自己的草稿 - 成功")
    void editor_viewOwnDraft() {
        loginAs(editor);
        when(articleMapper.selectActiveById(101L)).thenReturn(draftArticle);
        assertThatNoException().isThrownBy(() -> permissionService.checkArticleVisible(101L));
    }

    @Test
    @DisplayName("ADMIN 查看他人草稿 - 成功")
    void admin_viewOthersDraft() {
        loginAs(admin);
        when(articleMapper.selectActiveById(101L)).thenReturn(draftArticle);
        assertThatNoException().isThrownBy(() -> permissionService.checkArticleVisible(101L));
    }

    @Test
    @DisplayName("READER 查看他人草稿 - 403")
    void reader_viewOthersDraft_forbidden() {
        loginAs(reader);
        when(articleMapper.selectActiveById(101L)).thenReturn(draftArticle);
        assertThatThrownBy(() -> permissionService.checkArticleVisible(101L))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode().getCode())
                .isEqualTo(403);
    }

    @Test
    @DisplayName("ADMIN 查看归档文章 - 成功")
    void admin_viewArchived() {
        loginAs(admin);
        when(articleMapper.selectActiveById(102L)).thenReturn(archivedArticle);
        assertThatNoException().isThrownBy(() -> permissionService.checkArticleVisible(102L));
    }

    @Test
    @DisplayName("EDITOR 查看归档文章 - 403")
    void editor_viewArchived_forbidden() {
        loginAs(editor);
        when(articleMapper.selectActiveById(102L)).thenReturn(archivedArticle);
        assertThatThrownBy(() -> permissionService.checkArticleVisible(102L))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode().getCode())
                .isEqualTo(403);
    }

    @Test
    @DisplayName("READER 查看归档文章 - 403")
    void reader_viewArchived_forbidden() {
        loginAs(reader);
        when(articleMapper.selectActiveById(102L)).thenReturn(archivedArticle);
        assertThatThrownBy(() -> permissionService.checkArticleVisible(102L))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode().getCode())
                .isEqualTo(403);
    }

    @Test
    @DisplayName("EDITOR 编辑自己的文章 - 成功")
    void editor_editOwnArticle() {
        loginAs(editor);
        when(articleMapper.selectActiveById(103L)).thenReturn(editorsArticle);
        assertThatNoException().isThrownBy(() -> permissionService.checkArticleEditable(103L));
    }

    @Test
    @DisplayName("EDITOR 编辑他人文章 - 403")
    void editor_editOthersArticle_forbidden() {
        loginAs(editor);
        when(articleMapper.selectActiveById(104L)).thenReturn(othersArticle);
        assertThatThrownBy(() -> permissionService.checkArticleEditable(104L))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode().getCode())
                .isEqualTo(403);
    }

    @Test
    @DisplayName("ADMIN 编辑他人文章 - 成功")
    void admin_editOthersArticle() {
        loginAs(admin);
        when(articleMapper.selectActiveById(104L)).thenReturn(othersArticle);
        assertThatNoException().isThrownBy(() -> permissionService.checkArticleEditable(104L));
    }

    @Test
    @DisplayName("checkAdminOnly - ADMIN 成功")
    void adminOnly_admin() {
        loginAs(admin);
        assertThatNoException().isThrownBy(() -> permissionService.checkAdminOnly());
    }

    @Test
    @DisplayName("checkAdminOnly - EDITOR 403")
    void adminOnly_editor_forbidden() {
        loginAs(editor);
        assertThatThrownBy(() -> permissionService.checkAdminOnly())
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode().getCode())
                .isEqualTo(403);
    }

    @Test
    @DisplayName("checkAdminOnly - READER 403")
    void adminOnly_reader_forbidden() {
        loginAs(reader);
        assertThatThrownBy(() -> permissionService.checkAdminOnly())
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode().getCode())
                .isEqualTo(403);
    }

    @Test
    @DisplayName("删除自己的评论 - 成功")
    void deleteOwnComment() {
        loginAs(editor);
        assertThatNoException().isThrownBy(() -> permissionService.checkCommentDeletable(2L));
    }

    @Test
    @DisplayName("ADMIN 删除他人评论 - 成功")
    void admin_deleteOthersComment() {
        loginAs(admin);
        assertThatNoException().isThrownBy(() -> permissionService.checkCommentDeletable(2L));
    }

    @Test
    @DisplayName("删除他人评论 - 403")
    void deleteOthersComment_forbidden() {
        loginAs(editor);
        assertThatThrownBy(() -> permissionService.checkCommentDeletable(4L))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode().getCode())
                .isEqualTo(403);
    }

    @Test
    @DisplayName("文章不存在 - 404")
    void articleNotFound() {
        loginAs(editor);
        when(articleMapper.selectActiveById(999L)).thenReturn(null);
        assertThatThrownBy(() -> permissionService.checkArticleVisible(999L))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode().getCode())
                .isEqualTo(2001);
    }

    // ========== 并集策略：资源权限 ==========

    @Test
    @DisplayName("READER + EDIT 资源权限 可编辑他人文章 - 成功")
    void readerWithEditPermission_canEdit() {
        loginAs(reader);
        when(articleMapper.selectActiveById(104L)).thenReturn(othersArticle);
        when(articlePermissionService.hasPermission(104L, 3L, "EDIT")).thenReturn(true);
        assertThatNoException().isThrownBy(() -> permissionService.checkArticleEditable(104L));
    }

    @Test
    @DisplayName("READER + VIEW 资源权限 不可编辑 - 403")
    void readerWithViewPermission_cannotEdit() {
        loginAs(reader);
        when(articleMapper.selectActiveById(104L)).thenReturn(othersArticle);
        when(articlePermissionService.hasPermission(104L, 3L, "EDIT")).thenReturn(false);
        assertThatThrownBy(() -> permissionService.checkArticleEditable(104L))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode().getCode())
                .isEqualTo(403);
    }

    @Test
    @DisplayName("READER + MANAGE 资源权限 可删除他人文章 - 成功")
    void readerWithManagePermission_canDelete() {
        loginAs(reader);
        when(articleMapper.selectActiveById(104L)).thenReturn(othersArticle);
        when(articlePermissionService.hasPermission(104L, 3L, "MANAGE")).thenReturn(true);
        assertThatNoException().isThrownBy(() -> permissionService.checkArticleDeletable(104L));
    }

    @Test
    @DisplayName("READER + VIEW 资源权限 可查看他人草稿 - 成功")
    void readerWithViewPermission_canViewDraft() {
        loginAs(reader);
        when(articleMapper.selectActiveById(101L)).thenReturn(draftArticle);
        when(articlePermissionService.hasPermission(101L, 3L, "VIEW")).thenReturn(true);
        assertThatNoException().isThrownBy(() -> permissionService.checkArticleVisible(101L));
    }

    @Test
    @DisplayName("READER + VIEW 资源权限 可查看归档文章 - 成功")
    void readerWithViewPermission_canViewArchived() {
        loginAs(reader);
        when(articleMapper.selectActiveById(102L)).thenReturn(archivedArticle);
        when(articlePermissionService.hasPermission(102L, 3L, "VIEW")).thenReturn(true);
        assertThatNoException().isThrownBy(() -> permissionService.checkArticleVisible(102L));
    }

    @Test
    @DisplayName("READER + MANAGE 资源权限 可变更文章状态 - 成功")
    void readerWithManagePermission_canChangeStatus() {
        loginAs(reader);
        when(articleMapper.selectActiveById(104L)).thenReturn(othersArticle);
        when(articlePermissionService.hasPermission(104L, 3L, "MANAGE")).thenReturn(true);
        assertThatNoException().isThrownBy(() -> permissionService.checkArticleStatusChangeable(104L));
    }

    @Test
    @DisplayName("EDITOR + MANAGE 资源权限 可编辑分类 - 成功")
    void editorWithManagePermission_canEditCategory() {
        loginAs(editor);
        when(categoryPermissionService.hasPermission(10L, 2L, "EDIT")).thenReturn(true);
        assertThatNoException().isThrownBy(() -> permissionService.checkCategoryEditable(10L));
    }

    @Test
    @DisplayName("READER 无分类资源权限不可编辑 - 403")
    void readerNoCategoryPermission_cannotEdit() {
        loginAs(reader);
        when(categoryPermissionService.hasPermission(10L, 3L, "EDIT")).thenReturn(false);
        assertThatThrownBy(() -> permissionService.checkCategoryEditable(10L))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).getErrorCode().getCode())
                .isEqualTo(403);
    }
}
