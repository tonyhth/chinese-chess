# v2.2.21 新增 Bug 8: macOS 残局获胜后回放不正常

## 报告时间
2026-06-20 06:13（洪涛反馈）

## 现象
macOS 端，残局通关后点击「查看解法」按钮，回放视图表现异常。

## 需要排查的方向

### 1. sheet 嵌套问题（历史教训）
- v2.2.18/v2.2.19 修过双 sheet 崩溃（`.sheet(isPresented:)` 嵌套）
- 当前代码 `PuzzleSelectView.swift` line 614: `.sheet(isPresented: $showSolutionReplay)` 嵌套在 success overlay（条件渲染层）内
- success overlay 本身不是 sheet，是 ZStack 层叠，所以理论上不构成双 sheet——但需确认

### 2. ReplayView 布局变更
- v2.2.21 Cody 对 ReplayView.swift 有改动：合并了标题栏和对局信息为一行
- ReplayControlView.swift 也重排了：控制按钮、步数信息、速度选择合并重排
- macOS 上 sheet 的 frame 约束：原 `.frame(minWidth: 600, minHeight: 750)` 是否还有效

### 3. ReplayBoardView iOS 改动可能影响 macOS
- Bug 3 修复改了 `maxBoardHeight: 675 → 850`，但这在 `#if os(iOS)` 块内，macOS 不受影响
- macOS 端棋盘自适应逻辑：`availableWidth/Height = geo.size.width/height`（无上限），sheet 600×750 是否足够

## 相关文件
- `PuzzleSelectView.swift` — 残局通关弹窗 + 解法回放 sheet 触发
- `ReplayView.swift` — 回放视图主容器
- `ReplayBoardView.swift` — 回放棋盘
- `ReplayControlView.swift` — 回放控制条
- `PuzzleViewModel.swift` — `buildSolutionRecord()` 方法

## 排查要求
1. **先确认现象**：洪涛说「不正常」需要进一步确认——是崩溃？显示空白？棋盘太小？控制条不可用？
2. **检查 Cody 的 v2.2.21 改动是否引入回归**：`git diff c9316fb..HEAD -- ReplayView.swift ReplayControlView.swift`
3. **macOS sheet frame**：确认 ReplayView 在残局解法回放场景下的 sheet 尺寸是否合理

## 临时处理
在确认具体现象前，先不要改代码。让 Cody 先 build + 在 macOS 上跑一遍残局通关→查看解法，确认问题。
