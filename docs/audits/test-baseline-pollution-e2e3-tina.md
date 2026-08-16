# 测试基线污染 E2/E3 取证报告（Tina）

**日期**: 2026-08-16（date 取系统钟）
**指令链**: 洪涛 → Luke 派单（E2 配对二分 + E3 机制实验，与 Cody E1 并行）
**基线**: 主树 clean HEAD **54752ed**（p2c2-baseline-full.log，08:29 起跑，22 失败 suite）
**实验环境**: 隔离 worktree /tmp/e2-wt @54752ed（零接触主树，known-issues:261 规约）+ 独立 DD /tmp/e2-dd
**日志索引**: /tmp/e2-S*.log（R1 单跑）/ e2-R*.log（R2）/ e2-T-*.log（R3+补测）/ e2-M1v2|e2-M2v2-*.log（R4 机制）/ 汇总 e2-summary / e2-r2-summary / e2-r3-summary / e2-r4v2-summary

## 一、总结论（一段话）

22 个失败 suite 解构完成：**真污染受害者 1 个（B3S4），污染源 4 个（跨进程语言态泄漏），flaky 1 个（Replay 暂停续播），存量断言债 20 个（单跑确定性红，与 v6.2 断言清偿高度同族）**。"慢性污染守口失效"的主体不是污染，是未合入的断言债；污染真实存在但面窄，机制已实验铁证。

## 二、机制实验（E3 升级版——跨进程持久化泄漏，铁证）

**假设演进**: Luke 原 E3 假设"英文 UI 单跑若绿→坐实泄漏"——实测英文 UI 单跑**不绿**（2 issue 为内容债，与语言态无关）；泄漏机制改由 B3S4 受害者反推 + 直接实验证明：

1. **M1v2（证明）**: `defaults write com.chinesechess.app chinesechess.language en` → B3S4 单跑 **FAILED，2 issues，全部 displayName 英文化**（"Xu Yinchuan"≠"许银川" / "National Individual"≠"全国个人赛"）——与全量基线指纹**逐字一致**。机制实锤：L10n 经 UserDefaults.standard（键 `chinesechess.language`，宿主域 com.chinesechess.app）**跨进程持久化**，上一批次的 en 残留被下一批次启动时读入（L10n.swift:22）。
2. **M2v2（泄漏源普查）**: 8 个 setLanguage 使用类逐一单跑后读残留语言态：

| 类 | 跑后残留 | 判定 |
|---|---|---|
| D5I18nAuditVerificationTests | **en** | ❌ 泄漏源 |
| I18nKeyCompletionTests | **en** | ❌ 泄漏源 |
| MasterGameFixTests | **en** | ❌ 泄漏源 |
| TutorialI18nTests | **en** | ❌ 泄漏源 |
| UXAdaptationTests | zh-Hans | ✓ 自清洁（multipleSwitches 末态恰好 zh，运气非设计） |
| P0ChapterUnlockFormatTests | zh-Hans | ✓ |
| V2215Tests | zh-Hans | ✓ |
| V2218GuidedPuzzleTests | zh-Hans | ✓ |

3. **受害几何**: 全量单进程内泄漏同样生效（同进程同 standard defaults）。B3S4 字母序靠前，起跑态=上次运行残留或进程内早期 en-setter；后续语言敏感 suite 被中途 setLanguage 自愈，故受害面收窄到"敏感且时序 unlucky"的 B3S4 一族。
4. **主树结构性缺口（E3 直接回答 Luke）**: 主树**无 TestL10nSupport 基建**（v6.2 专属未合入），setLanguage 用户 8 类零还原约束。v6.2 侧基建也未全覆盖（MasterGameFix/TutorialI18n 在 v6.2 同样未接线）。

## 三、分类总表（22 suite 全解构）

| 分类 | Suite | 单跑 | 全量 | 备注 |
|---|---|---|---|---|
| **污染受害者** | B3S4 MasterGameSearch | ✅ 绿 | ❌ 2 | M1v2 精确复现，唯一实锤 |
| **flaky** | P0: Replay No Auto-Restart | 3 跑 2红1绿 | ❌ 1 | "中途暂停后再播放" isAutoPlaying 时序竞态（:842） |
| **存量债-i18n 内容** | UX 适配/英文 UI 显示验证 | ❌ 2 | 2 | 翻译长度 337>300 / en 值含中文（v6.2 同族已修） |
| | D5 i18n 审计验证 | ❌ 3 | 3 | difficulty rawValue 命名 / zh-en 键数 794≠796 |
| **存量债-逻辑/演进** | StatsManager Tests | ❌ 4 | 4 | 桶名体系（v6.2 Task I A 类同族） |
| | PositionAnalyzer 走法质量分级 | ❌ 5* | 5 | depth=0 引擎浅返回（*首轮 3 nil 系我方环境伪影，见五） |
| | BoardPlayer Board State Consistency | ❌ 1 | 1 | |
| | DemoViewModel Delegation | ❌ 10 | 10 | 级联单跑即现 |
| | R1 功能完整性 | ❌ 1 | 1 | AIDifficulty.allCases 10≠5 |
| | P3 Batch 2 | ❌ 3 | 3 | |
| | AIDifficulty Tests | ❌ 1 | 1 | |
| | CoachSessionView 集成 | ❌ 1 | 1 | |
| | Phase 2a UCIMoveConverter | ❌ 2 | 2 | |
| | Phase 3 #5 和棋规则 | ❌ 1 | 1 | |
| | Phase 3.5 Tests | ❌ 5 | 5 | Phase35Tests |
| | Phase6: Enum Tests | ❌ 1 | 1 | |
| | iOS 工具栏与状态栏适配（v3.1/基础 两 suite） | ❌ 1 / ❌ 1 | 1 / 1 | |
| | v2.2.3 遗留问题修复 | ❌ 5 | 5 | |
| | v4.0 #4 AI 时间管理 | ❌ 1 | 1 | |
| | v4.0 P0 走棋挂起 | ❌ 2 | 2 | |

**配对二分（E2 按 Luke 矩阵实测，无交叉污染）**: UX×SmartCommentary（2=2 自身债）/ PA×M1Phase1（5=5）/ PA×SearchBoardV2（5=5）/ Replay×ChessClock（ChessClock 绿；红的是 Replay 自身 flaky）——主树进程内 suite 间无观测到语言外的新型污染配对。

## 四、修复建议（按 Luke 三类归档，供 Alex L2 结构设计）

1. **reset registry（首推，对症语言泄漏）**: 每 suite 入口快照+出口恢复 `chinesechess.language`——TestL10nSupport（v6.2）即此型最小实现，建议：① 推主树 ② 4 个泄漏源类接线 ③ B3S4 类语言敏感 suite 入口显式 setLanguage("zh-Hans") 自防御 ④ L2 若做全局 registry，覆盖点=UserDefaults 语言键（跨进程持久化是它的特殊性，同进程 restore 不够——上批次的残留仍会进下批次）。
2. **环境注入（资产完整性）**: 隔离/新生 DD 缺 pikafish.nnue 会让引擎测试静默变 nil-failure（本次实踩，见五）——建议测试宿主启动时资产自检（nnue 存在性 assert 或 TestPlan 预检）。
3. **串行/结构化标记**: Replay flaky 归 Ruby P2 指引同款（.serialized/时序改造，不是加宽窗口）；已在我 P2 挂账。
4. **存量债 20 suite**: 不属污染治理——**v6.2 断言清偿（Task I）已修同族**（rawValue/翻译长度/门禁放宽等），v6.2 合入主树即自动清偿大头；残余走断言清偿通道。

## 五、方法论附记（本次自踩两坑，记录防重蹈）

1. **defaults 域语义**: `defaults write chinesechess.language en` 把键名当域写——第一轮 M1 无效+普查全 UNSET。正确：`defaults write <bundle-id> <key> <value>`。无效实验的特征（读数全 UNSET）当场识破重跑，未污染结论。
2. **隔离环境资产完整性**: worktree 缺 gitignored 资产（Accessibility 源目录/data JSON/Pikafish 库/nnue）分四轮才补齐；PositionAnalyzer 首轮单跑 3 个 nil-failure 即伪影信号（全量指纹是 depth=0 而非 nil）——**单跑失败模式必须与全量指纹比对**，模式错位=先查环境再下结论。
