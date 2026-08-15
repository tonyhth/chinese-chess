# A3 EXIT:132 上游排查分析（P0-2，不动码）

- 日期：2026-08-15（同日升级：机制从"最可能路径"升格为"已证明"——确定性单测 + 运行时断言现场双证据）
- 范围约束：纯分析文档，不改源码，不阻塞 P0-1/P0-3 交付

## 结论（已证明，非推测）

**已证明机制（双证据）**：搜索返回陈旧候选 → softmaxSelect 的 C1 过滤循环在游戏 Board 本体上 execute/undo 陈旧快照 → undo 按快照坐标传送棋子（真实位置清空）→ 位置级重叠 → 车将同格时 canAttack 直通 → （旧 binary）SIGILL /（修复后）防御 + dump。

- 证据一（确定性单测）：`A3Exit132CrashTests.testStaleCandidateFilterPatternTeleportsPiece` / `testStaleCapturedFilterPatternTeleportsVictim`——同过滤模式下棋子 teleport 的因果链可复现、可断言
- 证据二（运行时断言现场，2026-08-15 10:58）：Debug 断言版自对弈第 1 局触发 `Board.undoLastMove 后棋盘腐败: [重复位置(9,2): id=16 与 id=4]`，系统 .ips（ChineseChess-2026-08-15-105830）调用栈实锤：`Board.undoLastMove ← closure #1 in softmaxSelect ← playGame`——**决定性现场，机制 100% 闭环**
- 佐证（Release probe，/tmp/a3probe）：ply#62 首现陈旧候选（C1 检出，histCount 与本地 ply 同步——排除外部改历史）→ ply#64 真实重叠出现（teleport 已发生）→ 对局正常结束（防御生效，旧 binary 大概率已崩）

## 三条嫌疑路径逐条评估

### 1. SelfPlayRunner 放行非法局面 ✅ 已排除（作为第一因）

- 候选全部来自 `MoveValidator.allLegalMoves`（含 wouldBeInCheck 全校验）或开局库（`ICCSParser.parse` 内含 isLegal 校验）
- 随机/嵌套/重放 fuzz（12 局 × 100 ply + depth-3 嵌套 + 历史 A34 全量重放含 421 步局）零腐败
- probe 实测：腐败**只在引擎调用之后**的检查点出现，pre-preExecute（上一 ply 的 post）时刻棋盘总是干净的

### 2. captured 生成缺陷 ⚠️ 部分成立（作为放大器，非第一因）

- `candidateMoves` 在同一 Board 快照内生成 piece+captured，生成时自洽
- 但陈旧 move 的 captured 字段会让 undo **复活受害者在陈旧位置**（确定性单测证明）——即 captured 快照失效是 teleport 的两种形态之一
- 与丹妮指定归因方向吻合：重叠出现在候选执行后的 wouldBeInCheck 内部（子局面视角）

### 3. execute 残留被吃子 ❌ 未观测到

- postExecute 检查点（C3 完整性）在正常路径零命中；出现的重叠全部可归因于 teleport 序列
- SearchBoard.execute/undo 的 removeAll/append 按 id 配对，静态审查无残留路径

## 陈旧候选来源（第一因分析，待运行时捕获）

### 已布防的捕获手段

`rootSearchScored` 入口/出口**位置保真断言**（Debug）：逐子 `id:row,col` 快照比对。计数断言已证明不充分（Debug 两局跑完计数平衡但 game2 仍现陈旧候选）——存在**位置级**不平衡（undo 恢复到错误坐标但 make/unmake 次数平衡）。

### 静态审查的候选疑点（按嫌疑排序，已部分收窄）

1. ~~时间管理器提前中断路径~~ —— make/unmake **计数**断言（Debug 两局全跑）未触发；已升级为**位置保真断言**（rootSearchScored 入口/出口逐子 id:row,col 快照比对，Debug-only）：计数平衡但位置漂移的不平衡只能由它抓。待下次 Debug 运行触发即锁定泄漏点
2. **lvl4 独有路径相关性强**：三次 probe/断言运行的首异常均发生在 lvl4 行棋步（turn=lvl4）——CheckmateSearch（lvl4+ 专用，4 处调用点 :289/:314/:522/:549）与 hardSearchScored 的杀棋搜索是嫌疑集中区，建议根治立项时优先排查
3. LMR/PVS 双调研递：两次递归间无 make/unmake（子调用自理），静态无泄漏——但静态结论不覆盖时间中断交叠场景，依赖位置保真断言做最终裁决
4. null-move toggleTurn：不产生 moveHistory 记录，无法造成 teleport（C0 检查点已覆盖 turn 语义）
5. CheckmateSearch.dfs（手写 undo 配对）：在 SearchBoard 副本上操作，与嫌疑 2 合并排查

### 关键观测（三次运行比对，已固化）

- 三次运行（probe×2 + fidelity×1）的首异常均在 **lvl4 行棋步**（turn=lvl4）
- 异常时间戳聚簇：一次 teleport 后连锁暴露，符合"单点腐坏 → 后续每 ply mismatch"
- Debug 计数断言两局未触发：不平衡（若存在）为位置级——位置保真断言已布防
- **10:58 断言现场（最强证据）**：undo 断言在 softmaxSelect 过滤闭包内引爆，机制链条不再有推测成分

## 下一步建议（不动码，另行立项——Luke 已裁定根治修复不进本次交付）

1. 根治立项时第一步：Debug + 位置保真断言跑 lvl3-vs-lvl4 直至触发 → 断言信息含入口/出口棋盘全量，直接指认泄漏函数（若 rootSearchScored 不触发但 C1 仍命中 → 候选生成于 SearchBoard 之外，查 openingBook.parseICCSMove 读取时序）
2. 修复方向预判（等实证后定）：① 搜索返回前按入口快照校验候选新鲜度（move.from 处棋子 id == move.piece.id，不匹配即 reject/regenerate）② softmaxSelect 改用 SearchBoard 副本做过滤（彻底隔离游戏 Board，O(1) 级开销）③ 两者可叠：防御性校验 + 结构隔离
3. 本改动集的 C1/C2 检查点会在 A3 重跑中持续抓现行（60s 去抖不丢首现场），根治数据不缺
