# T-1023-OC-01·①功能打磨批 编码审查判词（Ruby）

- **对象**：commit e93ccc1（10 files +22/-17），HEAD=origin/m1 亲证一致
- **日期**：2026-10-28 ｜ **审查者**：Ruby ｜ **模式**：只读审查（零 commit）
- **结论**：**代码面通过，不阻塞合入。无方案级问题。**

## 变更清单独立验证

git show e93ccc1 --name-status 亲证：10 files 与 Cody 申报一一对应，无漏报无多报（GameRailView 实路径 Views/Game/GameRailView.swift）。行数账目：11+7+5+2+2+1+6+1+2+2=39=22+17 亲证。src/ working tree 干净（未提交变更仅 docs 面他人件）。

## 逐审查点核验

### ① CheckmateSearch 全量校验（P3-N1 清偿）— 成立
- 正确性：全量遍历消 prefix(8) 假阳性域；moveScore 排序保留仅改校验顺序不改判定完备性（先验高分应将的效率语义保留）
- 性能兜底亲证：dfs :39-41 超时守卫在案；AIEngine :363/:593 killTimeLimit=750 显式常量两处（iOS 两支同值）；maxDepth=12
- 最坏路径=超时返回 nil（不误报），失败方向安全

### ② os_log 常开化 — 成立，日志量无风险
- AppLog=标准 os.Logger（com.chinesechess.app/engine），error 级 Release 天然常开持久化
- 三处变更均在失败路径（isReady 守卫×2 / pikafish_eval 失败 / getEngine 失败），非热路径

### ③ F5 字号 11/13pt — 裁量认可
- HIG 无硬性下限；caption2 辅助语境 11pt monospaced 可读；13pt 达常规辅助文本水位

### ④ keyboardShortcut 跨平台 — 无副作用确认成立
- ReplayControlView 仅 ReplayView:91 回放场景消费；方向键步进与回放语义一致
- iOS 硬件键盘面：回放视图无 TextField（搜索框为 macOS-only 独立视图），无输入冲突；disabled 态快捷键不触发

### ⑤ F6 豁免 / P3-1 不迁移 — 两处处置裁量认可
- P3-1：ChineseChessApp :280-281 亲证=P13 锚图 harness 面（"无章节=全部残局池"），无章节消费点，不迁移成立
- F6：docs/audits/t1023-dim4-ui.md :22/:35 亲证 F6 列跟踪项（ChapterSelectView 空态残留，降级跟踪非回潮），豁免与审计口径一致

### ⑥ 红线 — 全部零触碰
- L10n/xcstrings 零新增亲证（10 文件全 .swift；a11y 复用既有 key board.legalMove*）
- Enums +2 行纯注释亲证；s2Spec 注记纯文档；F7 撤除有双端全局深色背书（ChineseChessApp:512 + ChineseChessiOSApp:413 亲证），行为不变

## 问题清单

### 🟡 P2-1（测试面）：P3-N1 清偿无回归锚
CheckmateSearchTests 现有 4 例无一构造 ≥9 应将局面验证"第 9+ 应将破杀不被误判"——修复核心场景零覆盖；用例 3/4 断言均为 `_ = result`（仅验不 crash）。剪枝若回潮，现套件照绿。建议随批补一例：黑方 ≥9 应将且含一手破杀局面，断言返回 nil；用例 4 名"剪枝后仍能找到"语境已过时（剪枝已撤），随批改名。

### 🟡 P3-1（诊断面）：os_log privacy 缺省吞掉 fenPrefix
`fenPrefix=\(fen.prefix(40))` String 插值默认 privacy=.private——Release 显示 `<private>`，诊断价值折损（r/depth/timeMs 数值可见不受影响）。FEN 无敏感数据，建议 `privacy: .public`；PositionAnalyzer engineType 同理。

### 🟡 P3-2（布局面，pre-existing 加剧）：GameRailView 三位数回合号溢出
回合号 frame width:28 固定 + 13pt monospaced，"100."≈31pt 溢出（12.5pt 时代已溢，本次余量再缩 1.2pt）。非本次引入，100+ 回合对局可现，随下批布局项处理。

### 🟡 P3-3（登记面）：KI 三笔注记落仓外件
~/DevTeam/knowledge/known-issues.md 仓外登记可接受，建议 remediation plan 索引留路径指针，避免不可寻址。

## 证据文件
- 构建/测试申报：BUILD_RC=0（t1023-fp-build-1028.log）+ CheckmateSearchTests 4/4 + A3r2FirstCauseTests 5/5（t1023-fp-tests-1028.log，计数行齐）——审查只读纪律未重跑，依赖申报计数行
- 通知：依 2026-10-18 丹妮协议，判词落盘即完成，三方通知由 lead sweep 代行
