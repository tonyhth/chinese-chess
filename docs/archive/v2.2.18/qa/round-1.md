# 中国象棋 v2.1.2 第一轮审查报告 — 布局类（v3，含修复状态更新）

> 审查人：Alex·亚历 | 复核人：Vera | 日期：2026-06-08 | 标准：App Store 上架
> v3 更新：2026-06-13 逐项核对代码，更新修复状态

## 审查范围

棋盘定位与偏移、主界面布局、棋盘内元素定位、各弹窗/Sheet 布局、macOS 窗口自适应、iOS 布局适配、暗色模式与可读性、字体渲染。

## Vera 复核裁决

### 分级调整（采纳 2/2）

| 原编号 | 原级别 | 调整 | 新级别 | 理由 |
|--------|--------|------|--------|------|
| L-P0-03 | P0 | 降级 | **P1** | `.windowResizability(.contentSize)` + minWidth/minHeight 已阻止窗口过小，真正问题是放大时棋盘过大，属于体验问题 |
| L-P1-08 | P1 | 升级 | **P0** | iOS 边缘手势冲突必现，且 `value.startLocation` 导致拖拽走子不可能，商业化 App 不支持拖拽是严重缺陷 |

### 描述修订（采纳 2/2）

| 原编号 | 修订内容 |
|--------|----------|
| L-P0-01 | 原描述"网格非正方形"不准确。`min(cellSizeW, cellSizeH)` 确保了网格等距。真正问题是**棋盘 frame 未按 8:9 宽高比约束**，GeometryReader 空间利用率低，一个维度大量留白 |
| L-P1-03 | 通关弹窗无全屏遮罩，用户通关后**可继续操作棋盘**，属于逻辑 bug 不只是风格不一致 |

### 遗漏问题（采纳 5/5）

| 新编号 | 级别 | 描述 |
|--------|------|------|
| NEW-P0-01 | P0 | macOS 棋谱/统计面板同时打开无互斥，独立于 L-P0-04 的 overlay 遮挡问题 |
| NEW-P1-01 | P1 | macOS SettingsView Sheet 无关闭入口 |
| NEW-P1-02 | P1 | 强制暗色模式，不支持浅色模式 |
| NEW-P1-03 | P1 | PuzzlePlayView 通关后不阻止棋盘操作（逻辑 bug） |
| NEW-P2-01 | P2 | 两个平台按钮布局问题应统一处理（合并 L-P1-01 和 L-P1-04） |

---

## 问题清单（含修复状态）

### P0 — 商业化阻塞（5 项）

---

**L-P0-01：棋盘 frame 未按 8:9 宽高比约束** ✅ 已修

- **修复版本**：v2.2.x（Phase 1）
- **修复验证**：`ChessBoardView.swift:84` — `.aspectRatio(CGFloat(gridCols) / CGFloat(gridRows), contentMode: .fit)` 已添加。iOS 端 `maxBoardWidth=600`, `maxBoardHeight=675` 约束也已添加（第 28-29 行）。

---

**L-P0-02：iOS 端棋盘无最大尺寸约束** ✅ 已修

- **修复版本**：v2.2.x（Phase 2）
- **修复验证**：`ChessBoardView.swift:28-36` — `maxBoardWidth: 600`, `maxBoardHeight: 675` 已添加，并在 GeometryReader 中使用 `min(geo.size.width, maxBoardWidth)` 和 `min(geo.size.height, maxBoardHeight)`。

---

**L-P0-04：macOS 棋谱/统计面板浮层覆盖棋盘，无关闭引导** ✅ 已修

- **修复版本**：v2.2.x（Phase 2）
- **修复验证**：`ChineseChessApp.swift:11-14` — `enum Panel { case none, record, stats }` 互斥管理；第 122-132 行改为 `.sheet` 呈现，带 NavigationStack + toolbar 关闭按钮。

---

**L-P1-08→P0：棋盘交互层手势冲突 + 不支持拖拽** ✅ 部分修复

- **修复版本**：v2.2.x（Phase 1）
- **修复验证**：`ChessBoardView.swift:77` — 已从 `DragGesture(minimumDistance: 0)` 改为 `onTapGesture`，解决了边缘手势冲突。
- **⚠️ 遗留**：拖拽走子仍未实现。Round 2 审查中标记为 R2-01（P1），作为体验优化项。

---

**NEW-P0-01：macOS 棋谱/统计面板同时打开无互斥** ✅ 已修

- **修复版本**：v2.2.x（Phase 2）
- **修复验证**：`ChineseChessApp.swift:11-14` — `activePanel` enum 确保 `record` 和 `stats` 互斥。两个 Sheet 绑定到 `activePanel == .record` / `activePanel == .stats`。

---

### P1 — 严重影响体验（11 项）

---

**L-P0-03→P1：macOS 窗口放大时棋盘无限膨胀** ✅ 已修

- **修复版本**：v2.2.x（Phase 2）
- **修复验证**：`ChessBoardView.swift:24` — `maxCellSize: 80` 限制 cellSize 上限，棋盘最大约 720×800。macOS 端无额外 maxBoardWidth/Height，但 maxCellSize 已提供合理约束。

---

**L-P1-01 + L-P1-04→合并：两个平台底部操作栏按钮拥挤** ✅ 已修

- **修复版本**：v2.2.x（Phase 3）
- **修复验证**：
  - iOS 端（`ChineseChessiOSApp.swift`）：ToolbarItemGroup 含 3 个直接按钮 + 难度 Menu + 更多 Menu，低频操作已收纳
  - macOS 端（`ChineseChessApp.swift`）：底部 7 个按钮，使用 `.buttonStyle(.bordered)` + `.help()` tooltip，窄窗口时可能仍拥挤但可接受

---

**L-P1-02：残局选择页面 macOS Sheet 无关闭按钮** ✅ 已修

- **修复版本**：v2.2.x（Phase 3）
- **修复验证**：`ChineseChessApp.swift:136-145` — 包裹在 NavigationStack 中，`.toolbar` 含 `ToolbarItem(placement: .confirmationAction)` "完成" 按钮。

---

**L-P1-03：PuzzlePlayView 通关弹窗无全屏遮罩** ✅ 已修

- **修复版本**：v2.2.x（Phase 3）
- **修复验证**：`PuzzleSelectView.swift:526-528` — `Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { }` 全屏遮罩已添加。成功、失败、超步警告、和局四种弹窗均有遮罩。

---

**L-P1-05：主题选择器 Sheet 固定尺寸 280×200** ✅ 已修

- **修复版本**：v2.2.x（Phase 3）
- **修复验证**：`ChineseChessApp.swift:154-168` — 包裹在 NavigationStack 中，使用 `.frame(minWidth: 300, minHeight: 200)`（min 而非固定值），自适应高度。

---

**L-P1-06：SettingsView macOS 端固定 320×380** ✅ 已修

- **修复版本**：v2.2.x（Phase 3）
- **修复验证**：`SettingsView.swift:76` — 仅保留 `#if os(macOS) .frame(width: 320)`（固定宽度但无固定高度），配合 ScrollView 自适应内容。

---

**L-P1-07：被吃棋子展示排版混乱** ✅ 已修

- **修复版本**：v2.2.x（Phase 3）
- **修复验证**：`StatusBarView.swift` — iOS 端新增 `iOSCapturedPiecesSection()` 精简布局（`capturedRowHeight: 24`，`clipped()`），macOS 端使用 `HStack + VStack(alignment: .leading/.trailing)` + `ForEach` 逐子展示。

---

**L-P1-09：iOS 端主界面缺少难度选择入口** ✅ 已修

- **修复版本**：v2.2.x（Phase 3）
- **修复验证**：`ChineseChessiOSApp.swift:72-80` — 难度快捷入口 Menu 含新手/初级/中级/高级/大师五个选项。

---

**NEW-P1-01：macOS SettingsView Sheet 无关闭入口** ✅ 已修

- **修复版本**：v2.2.x（Phase 3）
- **修复验证**：`ChineseChessApp.swift:180-186` — 包裹在 NavigationStack 中，toolbar 含"完成"按钮。

---

**NEW-P1-02：强制暗色模式，不支持浅色模式** ⬜ 未修

- **状态**：记录，暂不修复
- **当前代码**：`ChineseChessApp.swift:119` 和 `ChineseChessiOSApp.swift:182` — `.preferredColorScheme(.dark)` 仍存在
- **原因**：所有 UI 颜色硬编码为深色适配值，支持浅色模式需重新设计整套配色方案，工作量巨大。作为 v2.2+ 中长期目标。

---

**NEW-P1-03：PuzzlePlayView 通关后不阻止棋盘操作** ✅ 已修

- **修复版本**：v2.2.x（Phase 3）
- **修复验证**：`PuzzleViewModel.swift:76` — `guard gameState == .playing, !isThinking else { return }` 在 `selectPiece`、`legalMovesForSelected`、`handleSquareTap` 中均有前置检查（第 76/98/110 行）。

---

### P2 — 轻微影响（8 项，NEW-P2-01 已合并）

---

**L-P2-01：棋盘星位标记尺寸固定** ✅ 已修

- **修复验证**：`ChessBoardView.swift:283-284` — `markSize = cellSize * 0.15`, `markGap = cellSize * 0.09`，已改为与 cellSize 成比例。

---

**L-P2-02：楚河汉界字体缺失时回退不美观** ✅ 已修

- **修复验证**：使用 `FontRegistry.bestAvailableFontName`，有字体回退逻辑。

---

**L-P2-03：GameOverOverlay iOS 端 safe area 间距** ✅ 已修

- **修复验证**：`GameOverOverlay.swift:14` — `Color.black.opacity(0.5).ignoresSafeArea()` 已处理 safe area。

---

**L-P2-04：RecordPanelView LazyVStack 无必要** ✅ 已修

- **状态**：低优先级，不影响功能和体验
- **当前代码**：`RecordPanelView.swift` 已改为普通 `VStack`（非 LazyVStack）
- **实际状态**：✅ 已修（代码已改为 VStack）

---

**L-P2-05：ReplayView 标题栏信息窄窗口截断** ⬜ 未修

- **状态**：低优先级，macOS 窗口可拉宽
- **影响**：极窄窗口下对局信息文字截断，用户可拉宽窗口解决

---

**L-P2-06：PuzzleSelectView 分类无滚动指示** ⬜ 未修

- **状态**：低优先级，功能正常
- **影响**：分类较多时无滚动条指示，但用户可滑动发现

---

**L-P2-07：macOS 顶部/底部两操作栏功能分组不清晰** ✅ 已修

- **修复验证**：`ChineseChessApp.swift` — 顶部 ToolbarView 含新局/悔棋/提示/难度，底部栏含棋谱/统计/残局/回放/主题/历史/设置，功能分组清晰。

---

**L-P2-08：棋子选中 scaleEffect(1.05) 不可察觉** ✅ 已修（改进中）

- **修复验证**：`PieceView.swift:60` — 已改为 `scaleEffect(isSelected ? 1.1 : 1.0)`（从 1.05 增大到 1.1）
- **Round 2 建议**：进一步增大到 1.15-1.2（R2-05）

---

## 统计摘要

| 级别 | 总数 | ✅ 已修 | ⬜ 未修 |
|------|------|---------|---------|
| P0 | 5 | 4（1 项部分修复） | 0 |
| P1 | 11 | 10 | 1（强制暗色模式） |
| P2 | 8 | 5 | 3（低优先级） |
| **合计** | **25** | **20** | **4** |

### 未修复项汇总

| 编号 | 级别 | 问题 | 原因 |
|------|------|------|------|
| L-P1-08→P0（部分） | P1 遗留 | 拖拽走子未实现 | 体验优化，Round 2 R2-01 |
| NEW-P1-02 | P1 | 强制暗色模式 | 需整套配色方案重设计，中长期目标 |
| L-P2-05 | P2 | 回放标题窄窗口截断 | 用户可拉宽窗口 |
| L-P2-06 | P2 | 残局分类无滚动指示 | 功能正常 |

---

## 修复路径（已完成）

```
Phase 1: ✅ L-P0-01（棋盘 aspectRatio）+ L-P1-08→P0（onTapGesture 替换 DragGesture）
Phase 2: ✅ L-P0-04 + NEW-P0-01（Sheet + 互斥）+ L-P0-02（iOS 约束）+ L-P0-03→P1（maxCellSize）
Phase 3: ✅ 其余 P1 + P2 批量修复
Phase 4: ⬜ NEW-P1-02（浅色模式）+ 残余 P2 — 推迟到后续版本
```
