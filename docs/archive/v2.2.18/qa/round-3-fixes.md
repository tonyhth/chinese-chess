# 中国象棋 v2.x — 统一实施计划

> 架构师：Alex·亚历 | 日期：2026-06-13 | 整合 Round 2 + Round 3 修复项

## 洪涛决策

| 决策项 | 结果 |
|--------|------|
| App Store Connect | 免费 Personal Team，无法上架。付费账号待加入。代码修复先行，上架操作等账号 |
| 应用名称 | "中国象棋" |
| 定价 | 付费 |
| 发布范围 | 首发中国/亚太 |
| 国际化 | 先中国区（中→中提取），英文翻译推迟 |

---

## 修复项总览

所有 Round 2 + Round 3 修复项，按实施优先级排序。

| 编号 | 来源 | 问题 | 级别 | 状态 | 阻塞项 |
|------|------|------|------|------|--------|
| R3-06a | R3 | 国际化中文提取 | P1 | 可启动 | 无 |
| R3-07 | R3 | 日期格式 Locale | P1 | 可启动 | 无 |
| R2-01 | R2 | 不支持拖拽走子 | P1 | 可启动 | 无 |
| R2-08 | R2 | 非法走法无提示 | P1 | 可启动 | 无 |
| R2-04 | R2 | 残局无目标说明 | P1 | 可启动 | 无 |
| R3-03 | R3 | VoiceOver 标签 | P1 | 可启动 | 无 |
| R3-04 | R3 | 动态字体支持 | P1 | 可启动 | 无 |
| R2-02 | R2 | 悔棋禁用无原因说明 | P2 | 可启动 | 无 |
| R2-03 | R2 | 提示结果无文字说明 | P2 | 可启动 | 无 |
| R2-05 | R2 | 选中放大效果微弱 | P2 | 可启动 | 无 |
| R2-06 | R2 | 游戏结束 emoji 无障碍 | P2 | 可启动 | 无 |
| R2-07 | R2 | AI 思考无耗时提示 | P2 | 可启动 | 无 |
| R2-09 | R2 | 缺少回放快捷键 | P2 | 可启动 | 无 |
| R3-01 | R3 | 隐私政策 HTML 托管 | P1 | ⏳ 等账号 | App Store Connect |
| R3-02 | R3 | 隐私数据声明 | P1 | ⏳ 等账号 | App Store Connect |
| R3-05 | R3 | App Store 元数据 | P1 | ⏳ 等账号 | App Store Connect + 截图 |

---

## 实施分期

### Phase 1：国际化 + 合规基础（R3-06a + R3-07）

> **目标**：完成中文国际化框架搭建，满足审核对本地化的要求。

| 任务 | 编号 | 工作量 | 文件 |
|------|------|--------|------|
| 创建 Localizable.xcstrings（zh-Hans + en） | R3-06a | 0.5 天 | `Resources/Localizable.xcstrings` |
| 提取所有硬编码中文字符串 → `String(localized:)` | R3-06a | 2-3 天 | 全项目 30+ 处（映射表见 `round3-appstore-compliance-fixes.md` §4a~4h） |
| NotationGenerator locale 处理 | R3-06a | 0.5 天 | `NotationGenerator.swift` |
| 日期格式 → `.formatted()` | R3-07 | 0.5 天 | `GameHistoryView.swift` + `GameRecord` |
| zh-Hans 显示回归验证 | R3-06a | 0.5 天 | — |

**Phase 1 合计**：4-5 天

**交付标准**：
- 所有 UI 文本通过 `String(localized:)` 读取
- zh-Hans locale 下显示与当前完全一致
- ICCS 棋谱格式不受影响

---

### Phase 2：交互体验关键修复（R2-01 + R2-08）

> **目标**：解决影响用户首次操作体验的两个核心问题。

| 任务 | 编号 | 工作量 | 文件 |
|------|------|--------|------|
| 拖拽走子：DragGesture + 视觉反馈 | R2-01 | 2 天 | `ChessBoardView.swift` |
| 非法走法提示：MoveValidator 返回原因枚举 + UI 提示 | R2-08 | 1.5 天 | `MoveValidator.swift` + `ChessBoardView.swift` |
| iOS 震动反馈 | R2-08 | 0.5 天 | `ChessBoardView.swift` |

**Phase 2 合计**：3-4 天

**R2-01 拖拽走子实现要点**：
```swift
// 与 onTapGesture 并存
.gesture(
    DragGesture(minimumDistance: 10)
        .onChanged { value in
            // 实时拖拽：棋子跟随手指移动
            dragOffset = value.translation
        }
        .onEnded { value in
            // 松手：计算目标格，执行走子
            handleDrag(from: value.startLocation, to: value.location)
            dragOffset = .zero
        }
)
```

**R2-08 非法走法实现要点**：
- MoveValidator 新增 `enum RejectionReason { case blocked, knightLeg, facingGenerals, suicidal }`
- `selectPiece` 点击非法目标时返回原因
- StatusBarView 短暂显示原因文字（2 秒后消失）
- iOS: `UIImpactFeedbackGenerator(style: .light).impactOccurred()`

**交付标准**：
- 拖拽走子：选中棋子后拖到目标格完成走子，拖拽中棋子跟随手指
- 非法走法：点击非法目标格时显示原因文字 + 震动（iOS）

---

### Phase 3：无障碍（R3-03 + R3-04）

> **目标**：满足 Apple 审核对 VoiceOver 和动态字体的要求。

| 任务 | 编号 | 工作量 | 文件 |
|------|------|--------|------|
| PieceView accessibilityLabel/Hint/isButton | R3-03 | 0.5 天 | `PieceView.swift` |
| ChessBoardView accessibility 容器 | R3-03 | 0.5 天 | `ChessBoardView.swift` |
| 选中棋子自定义 accessibilityAction（合法走法列表） | R3-03 | 1 天 | `ChessBoardView.swift` |
| 走棋/将军/游戏结束状态播报 | R3-03 | 0.5 天 | `GameViewModel.swift` + `ChessBoardView.swift` |
| GameOverOverlay/通关弹窗无障碍标签 | R3-03 | 0.5 天 | `GameOverOverlay.swift` + `PuzzleSelectView.swift` |
| 棋谱/历史 VoiceOver | R3-03 | 0.5 天 | `RecordPanelView.swift` + `GameHistoryView` |
| 非棋盘区域字体替换为语义字体 | R3-04 | 1 天 | StatusBarView/StatsPanelView/PuzzleSelectView 等（25-30 处） |

**Phase 3 合计**：4-5 天

**交付标准**：
- VoiceOver：可滑动浏览棋子、双击选中、浏览合法走法 action、双击走子
- 动态字体：系统字体放大/缩小时，非棋盘区域文字跟随变化，棋盘不受影响

---

### Phase 4：残局体验 + 细节打磨（R2-04 + P2 项）

> **目标**：完善残局模式体验，打磨交互细节。

| 任务 | 编号 | 工作量 |
|------|------|--------|
| 残局目标说明 | R2-04 | 0.5 天 |
| 悔棋禁用原因说明 | R2-02 | 0.5 天 |
| 提示结果文字说明 | R2-03 | 0.5 天 |
| 选中放大 1.1→1.15 | R2-05 | 极小 |
| 游戏 emoji 无障碍处理 | R2-06 | 0.5 天 |
| AI 思考耗时显示 | R2-07 | 0.5 天 |
| ⌘R 回放快捷键 | R2-09 | 0.5 天 |

**Phase 4 合计**：2-3 天

---

### Phase 5：上架操作（R3-01 + R3-02 + R3-05）⏳ 等付费账号

> **前提**：洪涛获得 Apple Developer 付费账号。

| 任务 | 编号 | 工作量 | 执行人 |
|------|------|--------|--------|
| 隐私政策 HTML 托管（GitHub Pages） | R3-01 | 0.5 天 | Cody |
| App Store Connect 隐私数据声明 | R3-02 | 0.5 小时 | 洪涛 |
| App Store 元数据准备（描述/关键词/分类/年龄分级） | R3-05 | 0.5 天 | Cody |
| 截图（6.7" iPhone + 5.5" iPhone + 12.9" iPad） | R3-05 | 1 天 | Cody |
| 提交审核 | R3-05 | 0.5 天 | 洪涛 |

**Phase 5 合计**：2-3 天

---

## 时间线总览

```
Phase 1（国际化）      4-5 天    ← 可立即启动
Phase 2（拖拽+非法提示） 3-4 天    ← 可与 Phase 1 并行（不同文件）
Phase 3（无障碍）       4-5 天    ← Phase 2 完成后启动（ChessBoardView 有依赖）
Phase 4（残局+打磨）    2-3 天    ← Phase 3 完成后启动
Phase 5（上架）         2-3 天    ← 等付费账号

总编码工作量：13-17 天
```

### 并行建议

```
Week 1-2:  Phase 1（国际化）+ Phase 2（交互修复）并行
Week 2-3:  Phase 3（无障碍）
Week 3:    Phase 4（打磨）
Week 3+:   Phase 5（等账号，随时可插）
```

---

## 风险项

| 风险 | 影响 | 缓解 |
|------|------|------|
| 拖拽走子与 onTapGesture 手势冲突 | Phase 2 | 使用 `.simultaneousGesture` 或 `.highPriorityGesture`；需实机验证 |
| Phase 1 国际化提取遗漏 | Phase 1 | 运行时全 locale 切换验证，遗漏的 key 会在 Xcode 编译时报 warning |
| NotationGenerator locale 处理复杂度 | Phase 1 | ICCS 分支不受影响，仅中文传统棋谱需 locale 感知 |
| VoiceOver 自定义 action 在旧 iOS 版本兼容 | Phase 3 | `accessibilityAction` iOS 14+ 支持，与项目 target 一致 |

---

## UI 布局优化方案状态

UI 棋盘布局优化方案（`docs/ui-board-layout-optimization.md` v1.2）已通过 Vera 审查，可随时纳入实施计划。建议与 Phase 2 或 Phase 4 并行实施（改动文件重叠少）。

---

## 给 Luke 的调度建议

1. **立即启动**：Phase 1 + Phase 2 并行派发 Cody
2. **Phase 1 优先完成**：国际化是后续所有修复的基础（字符串提取后才能验证 VoiceOver 标签等）
3. **Phase 2 可独立验证**：拖拽和非法提示不依赖国际化
4. **付费账号到位后随时插入 Phase 5**
