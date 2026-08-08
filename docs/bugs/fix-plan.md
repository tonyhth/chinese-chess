# 11 问题修复计划

## Phase 1: P0 快速修复（确定方案，低风险）

| Task | 文件 | 改动 |
|------|------|------|
| P0-1 | OpeningCoachSelectView.swift | NavigationLink(isActive:) → navigationDestination(isPresented:) |
| P0-4 | MasterGameBrowserView.swift | browserLayout iOS 分支条件加 selectedSubcategory == nil |
| P0-9 macOS | MasterGameBrowserView.swift | macosPlayLayout 加 ZStack + CommentaryOverlay |
| P1-2 | MasterGameBrowserView.swift 等 | 所有 List Button HStack 加 contentShape(Rectangle()) |
| P2-6 | StudyHubView.swift | iOSLayout VStack → LazyVGrid 2 列 |

## Phase 2: P1 数据 + 代码修复

| Task | 文件 | 改动 |
|------|------|------|
| P1-10 | DemoViewModel.swift | moveNotations 改用 NotationGenerator |
| P1-3 | MasterGameStore.swift + OpeningCategories.swift | 子分类排他匹配 + "其他应手"兜底 |
| P1-11 类型2 | puzzles.json | 36 局 maxMoves 上调 |
| P1-11 类型1 | Puzzle.swift + puzzles.json | effectiveMode 逻辑修改 + 56 局 JSON 改 freePlay |
| P1-8 | TutorialViewModel/InteractiveView | 复现第7课第2步 bug + 修复 |

## Phase 3: P0 复杂修复（需排查/新功能）

| Task | 文件 | 改动 |
|------|------|------|
| P0-5 | AnalysisView/AnalysisViewModel/PositionAnalyzer | 引擎链路排查 + UI 错误反馈 |
| P0-7 | CommentaryEngine + DemoViewModel | 轻量级同步点评扩展（吃子/攻击/交换） |
| P0-9 iOS | DemoViewModel/DemoConfig | 排查 showCommentary 持久化 + 回调 |
