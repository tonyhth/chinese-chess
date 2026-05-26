package com.kb.dashboard.controller;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.kb.article.entity.Article;
import com.kb.article.mapper.ArticleMapper;
import com.kb.category.mapper.CategoryMapper;
import com.kb.tag.mapper.TagMapper;
import com.kb.user.entity.User;
import com.kb.user.mapper.UserMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/dashboard")
@RequiredArgsConstructor
@Tag(name = "仪表盘", description = "系统统计")
public class DashboardController {

    private final ArticleMapper articleMapper;
    private final UserMapper userMapper;
    private final CategoryMapper categoryMapper;
    private final TagMapper tagMapper;

    @GetMapping("/stats")
    @Operation(summary = "系统统计数据", description = "返回文章/用户/分类/标签数量")
    @PreAuthorize("hasRole('ADMIN')")
    public Map<String, Long> stats() {
        return Map.of(
                "articleCount", articleMapper.selectCount(new QueryWrapper<Article>().isNull("deleted_at")),
                "userCount", userMapper.selectCount(new QueryWrapper<User>().isNull("deleted_at")),
                "categoryCount", categoryMapper.selectCount(null),
                "tagCount", tagMapper.selectCount(null)
        );
    }
}
