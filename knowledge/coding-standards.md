# 编码规范

## 项目目录结构

所有项目放在 `~/DevTeam/projects/<项目名>/` 下：

```
projects/<项目名>/
├── docs/           # 方案文档（Alex 产出）
│   └── archive/    # 历史方案归档
├── backend/        # 后端代码（Cody 产出）
├── frontend/       # 前端代码（Cody 产出）
├── tests/          # 测试代码（Tina 产出）
├── docker-compose.yml
└── README.md
```

## 路径约定

- Alex 方案文件：`projects/<项目名>/docs/<方案名>-v1.md`
- Cody 代码：`projects/<项目名>/backend/` 和 `projects/<项目名>/frontend/`
- Tina 测试：`projects/<项目名>/tests/`（或嵌入 backend/src/test/）
- Luke 派活时注明项目名，所有 agent 据此定位目录

## 全局目录（不在 projects/ 下）

```
~/DevTeam/
├── knowledge/          # 团队共享知识（全项目通用）
│   ├── coding-standards.md   ← 你在这里
│   ├── design-checklist.md
│   ├── review-checklist.md
│   └── known-issues.md
├── projects/           # 所有项目
├── run_tests.sh        # 全局工具
└── task_tracker.py     # 全局工具
```

## 文件编辑规范

- **优先用 `edit`（精确替换）修改已有文件，不用 `write` 全量重写**
- 一次 turn 内只修改一个文件，改完输出简短确认（"文件X已更新"），等下一 turn 再改下一个
- `edit` 的 tool result 远小于 `write`，减少 context 膨胀，降低各类超时/abort 概率
- 全量重写仅在创建新文件时使用

## Java 环境管理

- 使用 jenv 管理 Java 版本
- 项目级 `.java-version` 设为 Java 17
- 需要先 `eval "$(jenv init -)"` 才能生效
- CI/构建前确保 jenv 已初始化

## macOS 桌面应用交付标准：图标

所有 macOS .app 打包**必须**集成自定义图标，不允许出现默认空白图标：

1. **图标文件**：提供 `.icns` 格式（包含 16x16 到 1024x1024 全尺寸）
2. **Xcode 项目**：图标通过 `Assets.xcassets/AppIcon.appiconset` 集成，Contents.json 正确配置
3. **SwiftPM / 手工打包**：`.icns` 放入 `Contents/Resources/`，`Info.plist` 的 `CFBundleIconFile` 指向文件名（不含扩展名）
4. **验证**：打包后在 Finder 中确认图标显示正确，Dock 中拖入确认非默认图标
5. **适用范围**：所有项目（vocab-game、chinese-chess 及未来项目）

此标准由 Luke 于 2025-07-15 加入，作为交付门面硬性要求。
