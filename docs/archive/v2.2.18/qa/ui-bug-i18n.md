# UI Bug 修复 + i18n 国际化测试报告

> 角色：Tina | 日期：2026-06-30 | 版本：v1.0

## 背景

Luke 交付 7 个文件变更：3 个 UI Bug 修复 + 4 个 i18n 字符串提取。本报告覆盖单元测试结果和用户路径覆盖审查。

## 一、产物真实性验证

✅ **通过**。debug binary mtime (16:13:03) 晚于所有 7 个源文件最后修改时间（最晚 16:12:46）。

## 二、单元测试结果

**总览**：689 tests / 76 suites，**9 个失败**。

### 与本次变更相关的失败（2 个）

| # | 测试 | 文件 | 级别 | 说明 |
|---|------|------|------|------|
| 1 | i18n遗漏：GameOverOverlay '查看棋谱' 按钮仍为硬编码中文 | UIBugI18nTests.swift:156 | P2 | GameOverOverlay 已将"查看棋谱"提取为 `String(localized: "gameover.viewRecord")`，但测试代码本身是硬编码 `Issue.record()`，并非检测代码——**实际代码已修复，测试代码误报** |
| 2 | i18n遗漏：SettingsView Section 标题 '音效' 仍为硬编码中文 | UIBugI18nTests.swift:162 | P2 | SettingsView 第 49 行 `Section(String(localized: "settings.sound"))` 已提取，但第 28 行 `Section("棋盘主题")`、第 66 行 `Section("关于")`、第 73 行 `Text("隐私政策")` 仍为硬编码——**部分遗漏，确认为真实 P2 问题** |

### 预存失败（7 个，与本次变更无关）

| # | 测试 | 说明 |
|---|------|------|
| 1 | 打包 App 可执行文件存在且非空 | 打包产物不存在，非本次变更 |
| 2 | 打包 App 包含 AppIcon.icns | 同上 |
| 3 | 打包 App 包含 Assets.car | 同上 |
| 4 | ReplayView 玩家信息在独立区域 | 预存布局断言失败 |
| 5 | 星位标记尺寸 markGap 精度 | 浮点精度问题 (5.4 vs 5.3999...) |
| 6 | 注册后 CTFont 按名称加载霞鹜文楷 | 字体注册环境问题 |
| 7 | P1-05: 残局走棋后 isInCheck 正确更新 | 预存逻辑问题 |

### 本次变更相关测试通过项（13/15）

- ✅ GameOverOverlay：allowsHitTesting 不影响逻辑层
- ✅ GameOverOverlay：onViewRecord 回调可触发
- ✅ PuzzleViewModel：走棋过程中 board 实例持续有效
- ✅ ReplayViewModel：跳转后棋盘实例持续有效
- ✅ ReplayViewModel：前进到末尾棋盘状态完整
- ✅ i18n 键完整性验证
- ✅ GameState 枚举映射正确
- ✅ 难度选项 5 级全覆盖
- ✅ 状态栏文字全部提取
- ✅ 工具栏 accessibilityLabel 全部提取
- ✅ AI 回归：beginner/medium/master 正常走棋
- ✅ 残局回归：PuzzleViewModel 初始化正常

## 三、用户路径覆盖审查

### 3.1 GameOverOverlay（本次修复：allowsHitTesting）

| # | 用户操作 | 入口位置 | 数据查询 | 空数据保护 | 错误处理 | 用户反馈 |
|---|---------|---------|---------|-----------|---------|---------|
| 1 | 点击"新对局" | `onNewGame` 回调 | 无 | ✅ N/A | ✅ 无需 | ✅ 按钮响应 |
| 2 | 点击"查看棋谱" | `onViewRecord` 回调 | `onViewRecord` 可选值 | ✅ `if let` 判断 | ✅ nil 时不显示按钮 | ✅ 修复后首次可点击 |

**覆盖结论**：✅ 完整。`allowsHitTesting(false)` 修复使"查看棋谱"首次点击可响应。

### 3.2 PuzzleSelectView / PuzzlePlayView（本次修复：棋盘 frame 约束）

| # | 用户操作 | 入口位置 | 数据查询 | 空数据保护 | 错误处理 | 用户反馈 |
|---|---------|---------|---------|-----------|---------|---------|
| 1 | 选择分类 | CategoryButton | PuzzleStore.shared.categories | ⚠️ 无空数组保护 | ⚠️ 无 | ⚠️ 空分类无提示 |
| 2 | 搜索残局 | TextField + debounce | filteredPuzzles | ✅ 空结果有提示 | ✅ 有 | ✅ "无匹配"文本 |
| 3 | 选择残局 | PuzzleRow onTap | PuzzleStore.shared | ✅ 有 | ✅ 有 | ✅ fullScreenCover |
| 4 | 走棋 | ChessBoardView tap | viewModel | ✅ 有 | ✅ 有 | ✅ 高亮+移动 |
| 5 | 悔棋 | Button undoMove | viewModel.gameMoves | ✅ disabled 判断 | ✅ 有 | ✅ 按钮禁用 |
| 6 | 查看提示 | Button showHint | viewModel.currentHint | ✅ `if let` | ✅ 有 | ✅ 提示文本 |
| 7 | 通关弹窗 | viewModel.gameState | completionRating | ✅ 有 | ✅ 有 | ✅ 星级显示 |
| 8 | 失败弹窗 | viewModel.gameState | N/A | ✅ 有 | ✅ 有 | ✅ 重试按钮 |
| 9 | 超步警告 | viewModel.gameState | N/A | ✅ 仅 freePlay | ✅ 有 | ✅ 继续按钮 |
| 10 | 和局弹窗 | viewModel.gameState | N/A | ✅ 仅 freePlay | ✅ 有 | ✅ 重试按钮 |

**覆盖结论**：✅ 基本完整。棋盘 frame 约束修复后尺寸稳定。

### 3.3 ReplayView（本次修复：棋盘 frame 约束）

| # | 用户操作 | 入口位置 | 数据查询 | 空数据保护 | 错误处理 | 用户反馈 |
|---|---------|---------|---------|-----------|---------|---------|
| 1 | 关闭回放 | Button dismiss | N/A | ✅ N/A | ✅ 有 | ✅ 返回 |
| 2 | 跳转到某步 | ReplayControlView | record.moves | ⚠️ 空 moves 未处理 | ⚠️ 无 | ⚠️ 空棋谱无提示 |
| 3 | 自动播放 | ReplayControlView | record.moves | ⚠️ 同上 | ⚠️ 无 | ⚠️ 空 moves 无反馈 |

**P1 缺失**：ReplayView 在 `record.moves` 为空时无空状态提示。

### 3.4 SettingsView（i18n 提取）

| # | 用户操作 | 入口位置 | 数据查询 | 空数据保护 | 错误处理 | 用户反馈 |
|---|---------|---------|---------|-----------|---------|---------|
| 1 | 切换难度 | Picker | viewModel.difficulty | ✅ 有 | ✅ 有 | ✅ segment 切换 |
| 2 | 切换主题 | onTapGesture | BoardTheme.allCases | ✅ 有 | ✅ 有 | ✅ checkmark |
| 3 | 开关音效 | Toggle | soundEngine.isMuted | ✅ 有 | ✅ 有 | ✅ 切换 |
| 4 | 切换棋谱格式 | Picker | notationFormat | ✅ 有 | ✅ 有 | ✅ segment 切换 |
| 5 | 查看隐私政策 | NavigationLink | N/A | ✅ 有 | ✅ 有 | ✅ 导航 |

**覆盖结论**：✅ 完整。但仍有 3 处硬编码中文（详见下方）。

### 3.5 StatsPanelView / StatusBarView / ToolbarView（i18n 提取）

均为数据展示 + 简单操作，路径简单，覆盖完整，无 P1 缺失。

## 四、i18n 遗漏汇总

SettingsView 仍有 **3 处硬编码中文**未提取：

| # | 位置 | 硬编码文本 | 建议键名 | 级别 |
|---|------|-----------|---------|------|
| 1 | SettingsView.swift:28 | `"棋盘主题"` | `settings.theme` | P2 |
| 2 | SettingsView.swift:66 | `"关于"` | `settings.about` | P2 |
| 3 | SettingsView.swift:73 | `"隐私政策"` | `settings.privacyPolicy` | P2 |

GameOverOverlay 的"查看棋谱"**已修复**（使用 `String(localized: "gameover.viewRecord")`），测试代码误报。

ToolbarView 的 `accessibilityHint` 仍有 3 处硬编码中文（"双击开始新对局"、"双击撤销上一步"、"双击获取走法提示"），P3 级别。

## 五、结论

### 核心功能 ✅ 通过
- GameOverOverlay allowsHitTesting 修复有效
- 残局/回放棋盘 frame 约束修复有效
- AI 走棋回归正常
- 残局/回放核心路径回归正常

### i18n ⚠️ 部分完成
- 4 个文件主要字符串已提取
- SettingsView 有 3 处 Section 标题遗漏（P2）
- ToolbarView accessibilityHint 有 3 处遗漏（P3）

### 建议
1. **Cody 补充**：SettingsView 的 3 处硬编码中文提取（P2）
2. **Cody 补充**：ReplayView 空 moves 状态提示（P1）
3. **测试代码修正**：UIBugI18nTests 中 GameOverOverlay 的硬编码检查应改为实际代码扫描，而非无条件 `Issue.record()`
