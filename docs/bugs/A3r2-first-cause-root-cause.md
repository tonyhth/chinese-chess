# A3 r2 棋盘腐败第一因：根治立项分析

- 日期：2026-08-15
- 作者：Cody（Luke 裁定独立立项："陈旧候选根治修复不进本次交付，独立 fix 走完整流程"）
- 状态：**第一因已定位并实验证明**（3/3 单测复现），待 Luke 批准立项进入 fix 流程
- 证据基础：A3 r2 run（HEAD=dd94f15，Tina 执行，12:10 启动）overlap-dumps 7 条现场 + 日志时序 + 源码走读 + 复现单测 `A3r2FirstCauseTests`（3/3 绿）

## 一行根因

**CheckmateSearch 命中时返回整个杀法序列 `killMoves.prefix(topK)`（AIEngine.swift:289-290），其中第 2+ 步是"未来局面"的着法；softmaxSelect 的 C1 过滤循环（SelfPlayRunner.swift:200-205）对这些"陈旧候选"逐个 execute/undo，而 Board.execute/undoLastMove 按 id 盲操作且 undo 把棋子放回 move.from（声称为）、captured 复活到快照 position——每对 execute/undo 将 1-2 个棋子永久漂移到"未来位置"，主棋盘就此腐败。**

## 证据链（四层闭环）

### 1. 现场层（overlap-dumps，7 条，两局）

- **game#4 ply#83**（12:26:45，turn=lvl4）：C1+C2 双命中——move 声称 id0 chariot from(1,4)，棋盘 id0 实际在 (1,3)，且 to 位站着 id0 自己
- **game#13 ply#56-58**（13:01:24，turn=lvl4 三连）：C3 双红仕 id6/id7 同格 (8,4)；ply#58 C2——move.captured=id7 但棋盘 to 位=id6；post#58 id30 卒与 id6 仕同格（id7 被误删）
- 两局首中均在 **lvl4 回合**；boardId 探针三连同值（同一 Board 实例）→ 排除多对象分叉

### 2. 时序层（/tmp/v43-a3-r2.log）

- game#4 ply#83 与 game#13 ply#58 的 OVERLAP dump **之前均无该回合 lvl4 的 [IDS] 输出**（正常 lvl4 搜索耗时数百~数千 ms 并打印 completedDepth；现场毫秒级静默通过）
- → 唯一无 [IDS] 输出的路径：`hardSearchScored` 的 **CheckmateSearch 快速返回**（AIEngine.swift:289，命中即 return，不走 IDS）
- game#13 首因窗口进一步收窄：ply#56 pre 已重叠（histCount=55）→ 分叉发生在 ply#56 黑方(lvl4)回合内的候选处理阶段

### 3. 代码层（污染机制）

```swift
// AIEngine.swift:289 —— 序列当候选集返回
if let killMoves = CheckmateSearch.search(...) {
    return killMoves.prefix(topK).map { ($0, 0) }   // ⚠️ topK=3 时含 m2/m3（未来着法）
}

// SelfPlayRunner.swift:200-205 —— 过滤循环对主 Board execute/undo
let nonRepeating = candidates.filter { candidate in
    board.execute(candidate.move)          // 按 id teleport + 按 id 删 captured（不校验 from/to 占用）
    let fen = FENParser.generate(board: board)
    _ = board.undoLastMove()               // 棋子放回 move.from（非真实原位）；captured 复活到快照 position
    return fenCounts[fen, default: 0] == 0
}
```

- m1（序列第一步）与主棋盘一致 → execute/undo 净零
- m2/m3（未来着法）→ execute 按 id 盲搬、undo 按"未来坐标"回放 → **净漂移**，且 execute/undo 配对完整、栈空、无任何失败信号（`_ =` 丢弃 undo 返回值亦无感）

### 4. 实验层（A3r2FirstCauseTests，3/3 绿，xcodebuild 专项）

| 用例 | 机制 | 对应现场 |
|---|---|---|
| 漂移A | 陈旧 from 经 execute/undo 对 → 棋子漂到 move.from，真实原位失守 | game#4：id0 丢 (1,4) 现身 (1,3)，C1/C2 双中 |
| 漂移B | captured 复活到快照 position 而非消亡前真实位置 | game#13：id7 从 (9,5) 漂到 (8,4) |
| 漂移C | 两次漂移B → 双子同格 | game#13 ply#56 pre：id6+id7 双仕同格 (8,4)，1:1 复现 |

## game#13 全程复演（一致性验证）

1. ply#56 lvl4 CheckmateSearch 命中 → 返回 [m1,m2,m3]；过滤循环中 m2/m3 的 execute/undo 分别把 id7、id6 漂到 (8,4)（各自 captured 快照位）→ **双仕同格**（=ply#56 pre C3 现场）
2. 执行 m1（horse e6g7）正常；ply#57 红帅 f9e9（lvl3 在坏棋盘上的"合法"着法）
3. ply#58 lvl4 再命中 CheckmateSearch（副本拷贝自主棋盘，看到 (8,4)=id7）→ m1'=soldier e7e8 吃 id7；过滤循环继续漂移；pre 检查点 C2 命中（captured=id7 vs to 位=id6）→ execute 按 id 删 id7 → **post：id30 卒与 id6 仕同格**（=post#58 现场，16 子）
4. 坏棋盘上卒 e8 将军红帅 e9、黑马 g7 保护 → 判将死 → "黑胜 58 步 normal"（**该局结果无效**）

## 定性

- **设计缺陷**（非竞态/非内存安全问题）：把"序列"当"候选集"传给了只理解"当前局面着法"的 softmaxSelect
- 触发面：**lvl4/lvl5 专属**（CheckmateSearch 仅此两档）→ 与 A34/A45 口径必现、lvl3 从不首发的观测一致；7 次 completedDepth=0（lvl3×5+lvl4×2）为腐败下游效应（坏棋盘上搜索退化），非原因
- 影响：自对弈数据污染（腐败后对局结果不可信，game#13 黑胜即无效）；EXIT:132 崩溃的前置条件制造者（本 run 防御生效未崩）
- 昨晚 .ips 的 `undoLastMove ← softmaxSelect` 调用栈与此完全吻合——当时是"机制"，如今"来源"也已锁定

## 修复方案（立项建议，A+B 组合）

- **A（治本，一行级）**：CheckmateSearch 命中时只返回第一步 `[killMoves[0]]`——后续杀着由后续 ply 搜索自然走出（连将杀每步重新命中 CheckmateSearch，行为等价、语义正确）
- **B（兜底防御，~15 行）**：softmaxSelect 过滤循环前置一致性校验——候选 from 必须等于主棋盘该 id 棋子真实位置、captured 必须与 to 位实际占用一致，不一致直接跳过（不 execute）。防一切未来来源的陈旧候选
- 测试：A3r2FirstCauseTests 3 用例转为 B 的回归用例（修复后 B 应拒绝漂移候选）；CheckmateSearch 序列返回形态加断言
- 回归：15 用例专项 + 全量（-skip-testing:EloBaselineTests）+ A34 口径抽样重跑对账（修复后 overlap-dumps 应零新增）
- 风险：A 改变 lvl4/lvl5 候选分布（原来 topK=3 有 2 个是未来着法，实际从未被合法执行过——softmax 可能选中它们造成 teleport 执行，即 game#4 的 move 正是 m1 以外的可能）→ 修复后 lvl4 行为更稳定，ELO 曲线需 Tina 重测对账

## 附：文件清单

- 现场证据：`overlap-dumps/illegal-position-dump.log`（原样保留）、`/tmp/v43-a3-r2.log`（:1089 起 game#4、:3358-3364 game#13）、`calibration-results/move-history/A34_game13_lvl3vslvl4_58.txt`
- 复现测试：`src/ChineseChessTests/A3r2FirstCauseTests.swift`（本立项新增，未 commit——待立项批准随 fix 一并提交）
- 关键源码：`AIEngine.swift:276-298`、`SelfPlayRunner.swift:189-227`、`Board.swift:116-160`
