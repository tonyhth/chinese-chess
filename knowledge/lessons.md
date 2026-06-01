# 经验教训

## #057 — 残局视图坐标映射未验证导致 P0 级 bug

**日期：** 2026-06-01
**项目：** chinese-chess v2.0

### 问题描述
残局模式三个 P0 bug：棋子不在正确位置、无法走子、sheet 首次空白。

### 根因分析

1. **P0-A（sheet 空白）**：`sheet(isPresented:)` + `if let selectedPuzzle` 两个 @State 竞态。SwiftUI 在 `isPresented` 变 true 时预渲染 content，此时 `selectedPuzzle` 可能仍为 nil。
2. **P0-B（棋子偏移）**：`ChessBoardCanvas` 网格用 `w/8` 画列线、`h/9` 画行线，但 `posToCGPoint` 用 `w/9` 定位棋子。两个不同的坐标系统导致棋子中心偏离交叉点。
3. **P0-C（无法走子）**：`handleTap` 的坐标转换也用 `w/9`，导致点击位置映射到错误行列，`selectPiece` 找不到棋子。

### 为什么测试没发现

- 单元测试只验证了 FEN 解析和 Board 模型的逻辑正确性
- 没有视图层的布局测试（SwiftUI 视图坐标映射不在测试范围内）
- 没有端到端 UI 测试验证"点击 → 选中棋子"的完整流程

### 防范措施

1. **视图坐标映射必须与渲染一致**：提取 `posToCGPoint` 和 `pointToPos` 为成对的工具方法，共享同一个 `cellWidth/cellHeight` 定义
2. **sheet 优先用 `sheet(item:)`**：避免 `isPresented` + 数据源的竞态，单一绑定项更安全
3. **复用主视图组件**：残局棋盘不应独立实现渲染和交互，应复用主棋盘视图（BoardView 的渲染逻辑经过验证）
4. **新增视图时做手动验证**：坐标映射类代码单元测试覆盖不到，交付前必须手动运行验证

---

## #056 — pipeline-stall-ruby-review-pass 根因修复

**日期：** 2026-06-01
**项目：** chinese-chess v2.0

### 问题描述
Ruby 审查通过后 Cody 未交下游给 Tina，导致流水线中断。

### 防范措施
- AGENTS.md 明确规定：Ruby 发来的任何消息（审查清单或复查通过）都必须交下游给 Tina
- 自查清单：收到 Ruby 消息后立即检查 sessions_send + message 两条是否都完成
