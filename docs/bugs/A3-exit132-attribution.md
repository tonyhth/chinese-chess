# A3 自对弈 EXIT:132 (SIGILL) 崩溃归因 Memo

- 日期：2026-08-15
- 作者：Cody（P0 插队任务，Luke 派单，丹妮任务包）
- 状态：根因链闭环；防御 + 遥测已交付待审；第一因（陈旧候选来源）已布防位置保真断言，待下次运行捕获

## 一行根因

`MoveValidator.countPiecesBetween` 无 `from == to` 防御：当棋盘已含重叠棋子（对方攻击者与己方将同格）时，`canAttack` 以 `piece.position == target` 直通车分支，行分支 `(minC+1)..<maxC` 退化为 `(c+1)..<c` → Swift runtime trap "Range requires lowerBound <= upperBound" → SIGILL (EXIT:132)。

## 崩溃事实（2026-08-14 晚 A3 重跑）

- 启动命令（Tina session 日志逐字提取）：
  `cd ~/DevTeam/projects/chinese-chess && IDS_DEPTH_LOG=1 caffeinate -dims build/Release/ChineseChess.app/Contents/MacOS/ChineseChess --calibrate-native 3 4 15 500 > /tmp/v43-a3.log 2>&1`
- binary：HEAD=1d2fdd1，Release，22:23:28Z 启动（与 binary mtime 同分钟，确系新产物）
- 22:57（第 11 局）进程 SIGILL，全程 34 分钟；同 binary A2/A4 各 15 局全通过 → 数据依赖性 bug

## 符号化过程（方法论记录）

- 系统 .ips 内嵌符号指向 **Aug 8 旧 dSYM（UUID 不匹配）**，直接符号化结果错乱（Pikafish 符号等）——不可信
- 正确做法：`dwarfdump --uuid` 匹配 build/Release/ChineseChess.app 的 binary，`atos --offset` 重符号化
- 实锤帧：`countPiecesBetween (MoveValidator.swift:285)` ← `isValidChariotMove` ← `isMovePatternValid` ← `canAttack` ← `isInCheck` ← `wouldBeInCheck` ← `isLegal` ← `legalMoves` ← `rootSearchScored` ← `mediumSearchScored(+919, AIEngine.swift:260)` ← `bestMoves(+664, AIEngine.swift:144)`

## 触发路径（丹妮指定归因项）

**mediumSearchScored → legalMaps 触发路径确认**：重叠出现在候选执行后的 `wouldBeInCheck` 内部（`makeSearchBoard()+execute(move)` 后的子局面）——与"captured 缺失"假设方向吻合。更精确地说（probe 实证）：重叠棋子来自上游棋盘腐败，`wouldBeInCheck` 是第一个以重叠对（攻击者, 将）调用 `canAttack` 的位置，trap 在此引爆。重叠由**陈旧快照 move 在游戏 Board 上的 execute/undo** 制造（见"机制闭环"）。

## 机制闭环（probe 实证 + 确定性单测证明）

**腐败机制（已证明，testStaleCandidateFilterPatternTeleportsPiece/TeleportsVictim）**：

`SelfPlayRunner.softmaxSelect` 的 C1 重复过滤循环在**游戏 Board 本体**上对引擎候选逐个 execute → 读 FEN → undo。若候选是陈旧快照（from/captured 落后实际局面）：
- execute：按 id 移动棋子到陈旧 to / 按 id 移除陈旧 captured 指向的受害者
- undo：按 move 快照把棋子放回**陈旧 from** / 让受害者**复活在陈旧 captured 位置**
- 结果：棋子"传送"，真实位置被清空，历史计数不变——位置级腐败、对 moveHistory 不可见

**probe 运行实测链条（Release, lvl3 vs lvl4, /tmp/a3probe）**：

1. ply#62：`C1 from(6,4) 无棋子，move.piece=id28`——首个陈旧候选（histCount=61 与本地 ply 完全同步，排除外部改历史）
2. ply#64：`C3 重复位置(9,3): id16 与 id7`——teleport 已发生，真实重叠出现
3. ply#68：`C3 重复位置(7,5): id6 与 id7` + postExecute 同格——腐败在无 unchecked 执行下持续存在
4. 对局正常结束（黑胜 68 步）——旧 binary 在此局面大概率已 SIGILL；防御生效

**陈旧候选的来源（第一因，待捕获）**：Debug make/unmake 计数断言未触发（game1+game2 跑完无计数不平衡）→ 若存在不平衡是**位置级**的（undo 恢复到错误坐标但计数平衡）。已在 rootSearchScored 布防**位置保真断言**（Debug，入口/出口逐子 id:row,col 快照比对），下次 Debug 运行即锁定。

## 修复清单（本改动集）

1. `countPiecesBetween` from==to 防御：先 dump 再返回 0（同格间棋子数数学上为 0）
2. `canAttack` 同格 guard：`piece.position == target` 返回 false（棋子不攻击自己所在格）
3. `BoardIntegrityLogger`：OVERLAP dump（重叠对 + 双方棋盘全量 + 最近 10 步含 captured + lvl 上下文 + 调用栈），单文件 `overlap-dumps/illegal-position-dump.log`，60s 同 reason 去抖，dump-继续不吞
4. playGame 边界检查点 C0/C1/C2/C3（pre/post execute，Release 生效）
5. 搜索热路径仅 Debug assert（含位置保真断言），Release 零开销
6. 回归测试 15 用例（同格防御/重叠棋盘不 trap/teleport 机制确定性证明/随机与嵌套 make-unmake 完整性/历史 A34 重放/dump 格式与去抖/落盘格式）

## A3 为何无 move-history 落盘（P0-3 结论）

- A3 用 `--calibrate-native`：旧代码在**全部局数跑完后**才统一写 move-history → 第 11 局崩溃 = 进程死 = 前 10 局全部丢失（calibration-results/move-history/ 中 A34 在 08-14 零文件佐证）
- A2/A4 有文件是因为它们**跑完了**（写盘发生在 run 返回后）——不是命令行差异，是"跑完才写"的设计缺陷
- 修复：`--calibrate-native` 与 `--selfplay` 均改为**逐局即时落盘**（progressCallback 内写）；`--selfplay` 新增默认开启的走法落盘（`--no-save-moves` 显式关闭）

## 遗留事项

- 第一因捕获：下次 Debug 运行触发位置保真断言 → 定位搜索内部不平衡点（根因修复另行立项）
- 防御语义边界：from==to 返回 0 对车分支是数学正确；炮分支同格目标由 canAttack guard 拦截，语义一致
- A2/A4 结果不重跑（Luke 裁决：防御只在重叠非法局面改变行为，那 30 局没触雷）
