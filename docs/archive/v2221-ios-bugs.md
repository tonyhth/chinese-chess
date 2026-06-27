# v2.2.21 Bug 分析与修复任务

## 背景
洪涛在 iOS 端实测后发现 7 个问题，部分可能是 iOS/macOS 通用问题。需要团队逐个分析根因并给出修复方案。

## Bug 列表

### Bug 1: 残局提示不友好，有时有目的位置提示，有时没有
**现象**：残局模式下点击"提示"按钮，有时显示目的位置高亮（蓝色 from→to），有时没有。
**优先级**：P0
**相关代码**：
- `PuzzleViewModel.swift` → `showHint()` 方法（line 548+）
- `hintMove` 属性：(from, to) 供 ChessBoardView 蓝色高亮
- `currentHint`：文字提示
- 提示逻辑分两种路径：
  - `solutionType == "hint"` → 纯文字提示，无位置高亮
  - `checkmate/sequence` → 先文字 hints，用完后 step-by-step 显示位置
**分析要求**：
1. 确认 inconsistent 行为的根因——是设计如此（hint 类型 vs sequence 类型差异）还是 bug
2. 如果是设计问题：建议统一为「文字提示 + 位置高亮」的组合方式，让所有提示都有目的位置高亮
3. 检查 hints 数组为空时的 fallback 行为

### Bug 2: 残局提示不是中文棋谱写法
**现象**：残局提示显示的不是中文棋谱（如"炮二平五"），而是其他格式（可能是 ICCS 如 h2e2）。
**优先级**：P0
**相关代码**：
- `NotationGenerator.swift` → `notation(for:on:)` 方法
- 棋谱格式通过 `UserDefaults.standard.string(forKey: "chinesechess.notationFormat")` 控制
- 默认值：测试显示 defaultFormatIsChinese，但需确认 PuzzleViewModel 中的提示文案是否调用 NotationGenerator
- `PuzzleViewModel.showHint()` 中 hints 来自 `puzzle.hints` 数组（数据层），step-by-step 使用 ICCS 解析
**分析要求**：
1. 检查提示文字是数据预设的 hints 文本还是动态生成的棋谱
2. 如果是动态生成：确认 NotationGenerator 默认格式在 iOS 上是否正确为中文
3. 如果是 hints 数据本身的问题：评估是否需要在显示时把 ICCS 格式转中文

### Bug 3: 回放棋盘仍然太小
**现象**：回放（Replay）视图的棋盘尺寸不够大，没有充分利用屏幕空间。
**优先级**：P0
**相关代码**：
- `ReplayBoardView.swift` → macOS maxCellSize 200（v2.2.20l 改动）
- `ReplayView.swift` → sheet frame: macOS 600×750
- iOS 端 ReplayBoardView 的 cellSize 计算逻辑
**分析要求**：
1. 检查 iOS 端 ReplayBoardView 的尺寸计算——是否使用了 maxCellSize 限制
2. 对比 ChessBoardView（对弈棋盘）的尺寸计算逻辑，找出差异
3. 回放棋盘应与对弈棋盘同等大小

### Bug 4: 上面按钮布局不合理，悔棋和新开一局挨得太近
**现象**：iOS 端顶部工具栏，"新开一局"(plus.circle) 和"悔棋"(arrow.uturn.backward) 按钮距离太近，容易误触。
**优先级**：P0
**相关代码**：
- `ToolbarView.swift` → iOS 分支：
  - `HStack(spacing: 0)` 三个按钮紧密排列
  - 每个按钮 `frame(width: 44, height: 44)`
  - 总容器 `.padding(.horizontal, 12)`
**分析要求**：
1. 在按钮间增加间距或分隔（如 Spacer 或增加 spacing）
2. 考虑将"新开一局"移到其他位置（如右端），与"悔棋"分开
3. iOS 适配方案：可能需要将部分操作移到底部 toolbar 或使用更合理的布局

### Bug 5: 级别选完之后在上面应该有更明显的显示
**现象**：选择难度后，当前难度在顶部状态栏的显示不够醒目。
**优先级**：P1
**相关代码**：
- `StatusBarView.swift` → 难度标签：
  ```swift
  Text(viewModel.difficulty.displayName)
      .font(.caption2)
      .foregroundColor(.white.opacity(0.9))
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Color.brown.opacity(0.3))
      .cornerRadius(4)
  ```
- `ToolbarView.swift` → iOS 端没有难度 Picker（仅 macOS 有）
**分析要求**：
1. 增大难度标签字号（caption2 → caption 或 subheadline）
2. 增加背景对比度（brown.opacity(0.3) → 更高的 opacity 或不同颜色）
3. iOS 端可能需要在 Toolbar 中也展示当前难度（只读标签，不是 Picker）

### Bug 6: 通关后的残局在哪里查看？
**现象**：残局通关后，不知道在哪里回顾已通关的残局。
**优先级**：P1
**相关代码**：
- `PuzzleSelectView.swift` → PuzzleRow 显示完成标记和星级
- `PuzzleStore.shared.progress(for:)` → 通关进度数据
- `PuzzleSelectView` 筛选逻辑：未完成排前面，但没有「已通关」筛选
**分析要求**：
1. 评估方案：
   - 方案 A：在 PuzzleSelectView 增加筛选选项（全部/未通关/已通关）
   - 方案 B：增加「已通关」分类标签
   - 方案 C：在通关弹窗增加「下一关」按钮引导
2. 推荐方案 A（筛选）+ 在列表中更突出已通关标识
3. 注意：通关后的残局在列表中已经显示绿色 ✓，但用户不知道怎么快速找到

### Bug 7: 棋谱记录格式太难看
**现象**：RecordPanelView 的棋谱记录视觉效果不好。
**优先级**：P1
**相关代码**：
- `RecordPanelView.swift` → moveRow 方法：
  - 回合号宽度 24，monospaced footnote
  - 棋谱 `font(.custom(FontRegistry.bestAvailableFontName, size: 13))`
  - 将军标记 `#` / `+` 跟在后面
- 整体背景 `Color(red: 40/255, green: 22/255, blue: 14/255)`
**分析要求**：
1. 问题可能在：
   - 字号太小（13pt 在 iOS 上偏小）
   - 布局太紧凑（spacing: 2）
   - 缺少红黑双方的视觉区分（仅颜色不同，但缩进/对齐可改善）
   - 没有"红." "黑." 前缀（只有数字回合号）
2. 参考标准象棋棋谱格式：
   - 回合号 + 红方走法 + 黑方走法（同一行）
   - 或：左右分列/缩进区分
3. 改善可读性：增大字号、增加行间距、优化颜色对比度

## 执行要求

### Phase 1: Alex 分析（方案设计）
对每个 Bug：
1. 确认根因（代码层还是设计层）
2. 判断 iOS 专属还是通用问题
3. 给出修复方案（最小改动原则）
4. 标注影响的文件清单

### Phase 2: Cody 修复
按 Alex 方案逐个修复，每个 Bug 一个 commit。

### Phase 3: Ruby 审查
验证变更与方案一致，无副作用。

### Phase 4: Tina 测试
- 每个 Bug 的修复验证
- 全量回归（确保 v2.2.20 的 932 项测试不回归）

## 注意事项
- 当前代码基线：v2.2.20n（git HEAD: c9316fb）
- iOS 和 macOS 双端都需验证
- 不要改 NotationGenerator 的核心逻辑（已有完整测试覆盖），只改显示层
- 项目使用 SPM + xcodegen，不要手动编辑 .pbxproj
