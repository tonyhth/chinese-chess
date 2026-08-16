# L2 结构修复快审 — Alex 意见

**日期**: 2026-08-16（session_status 核钟 14:05）
**输入**: docs/audits/test-baseline-pollution-e2e3-tina.md（dc4653d）全文精读
**实核**: L10n.swift:22 启动读键 / v6.2 TestL10nSupport 形态与接线状态 / 主树 setLanguage 分布
**性质**: 结构形态快审（Luke 授权你审我裁代表），非重设计，半天封顶

## 裁定总表

| # | 类 | 三选一裁定 | 量级 |
|---|---|---|---|
| 1 | reset registry | **同意**（Tina 方案+形态细化：最小双侧接线；全局 TestStateRegistry **否决**） | 小时级 |
| 2 | 环境注入 | **修改**：in-test 显式 skip + gating 脚本预检；启动 assert **否决**；配 skip==0 门规 | 小时级 |
| 3 | flaky 标记 | **同意**（skip 条件注记）；隔离批 **否决** | 分钟级 |
| — | 流程 | 同意豁免 Vera 环节（附熔断条件） | — |

## 1. reset registry — 最小双侧接线，不做全局 registry

**事实核**（审点支撑）：
- L10n 单例 `init` 即读 `UserDefaults("chinesechess.language")`，跨批次残留进启动态——报告机制成立
- v6.2 TestL10nSupport 形态 = `injectZhHans()`（**入口注入** zh-Hans + 快照）/ `restore()`（出口恢复）。入口注入本身就是跨进程防御，强于"同进程 restore"
- v6.2 接线实核：D5 / I18nKeyCompletion / TutorialI18n **已接**（:10-11 init/deinit）；**MasterGameFix 未接**。报告 §二.4 称 TutorialI18n 未接线系过时信息——Tina 按 **1 文件** delta 修正工单

**裁定理由**：
1. **双侧接线互为冗余 = 崩溃安全组合**。源侧出口 restore 防本批外泄；受害侧（B3S4 族）入口注入防三类上游残留：上批泄漏、进程被杀未走 restore、**app 真机运行残留**（TEST_HOST=app，开发者切 en 后跑测试同样中招——M1v2 实验的 defaults write 即此场景模拟）
2. registry 的核心卖点（跨进程覆盖）实际由入口注入交付，不需要 registry 结构。纯出口型 registry 防不住进程死亡，卖点是虚的
3. 证据边界：配对二分未见语言外污染配对、受害面 1 suite、键 1 个——全局 TestStateRegistry 是对未观测问题的泛化，YAGNI；且它是设计项（状态分类/顺序保证/单例 reset 协议），量级差一个数量级，属 M1 P3/P4 窗口议题而非本单

**执行要点**（Luke 拆单用）：
1. `TestL10nSupport.swift` 从 v6.2 **字节级** cherry 到主树（合入零冲突）
2. 主树接线：4 泄漏源 + B3S4 全量（B3S4 照抄 v6.2 已有接线形态）——主树是基线守门面，不等 v6.2 合入
3. v6.2 侧仅补 MasterGameFixTests（合入侧唯一缺口；合入冲突 Tina 机械解）
4. 接线形态：新接线优先 setUp/tearDown（契约钩子、确定性）；v6.2 已落 init/deinit 不回改（免 churn）
5. 规约登记：测试触 setLanguage 必经 TestL10nSupport——新泄漏源零容忍，列入 Ruby 审查清单

**重开条件（显式）**：下次归因发现非语言类跨进程键，或已接线类再发泄漏 → 升级 registry 设计议题（届时挂 M1 P3/P4 窗口）。

## 2. 环境注入 — skip 标记 + 脚本预检，否决启动 assert

- **否决启动 assert**：nnue 缺失时非引擎 suite 全陪葬——把"静默红"换成"整体红"，对并行归因是倒退
- **in-test**：共享 preflight helper（如 `TestEnvPreflight.requireNNUE()`）挂引擎 suite setUp，缺失 → `XCTSkip`。skip 是第三态（非红非绿），不会被指纹比对误读为产品缺陷——正对 Tina 方法论五.2
- **脚本级**：baseline/gating 起跑前预检四类 gitignored 资产（nnue / Pikafish 库 / data JSON / Accessibility 源），缺即独立退出码终止——不烧 20 分钟批次（Tina 四轮补资产的真实成本在此偿还）
- ⚠️ **配套门规（必带，否则 skip 形态反成漏洞）**：gating/baseline 有效性判据加 **skip 计数 == 0**。skip>0 = 环境破缺、批次作废——防静默绿
  - 版本注记（08-16 晚，Tina 执行发现）：本版 swift-testing ① XCTSkip 在 async test 记红（弃用）② .disabled trait 确定性排除但 xcresult/stdout 零痕迹——skip 计数不可观测，门规改载体：**Test run 计数比对**（缺资产 → 引擎用例不起跑 → run 计数低于同 commit 套件清单锚点 → 批次作废；gating 资产预检拦截为主，计数比对为网内兑底）。防静默绿效力等价且覆盖面更广（任何确定性排除形态均掉计数）

## 3. flaky 标记 — skip 条件注记，否决隔离批

- **隔离批否决**：Tina 自测 3 跑 2红1绿即在隔离单跑态——隔离不消除时序竞态，只把噪声挪个批次；且 Ruby P2 指引是时序改造（.serialized），真修复落地时隔离基建即拆 = 纯浪费
- **形态**：Replay isAutoPlaying 用例无条件 XCTSkip，reason 带 Ruby P2 工单引用；修复落地**同 commit** 移除（写入 P2 验收项，不靠记忆）
- **守门原则入档**：基线成员必须确定性（绿或 skip），永远不掷硬币

## 4. 流程裁定 — 同意豁免，附熔断

小时级 + 实验铁证 + 随 v6.2 合入（Ruby 回归审查本就覆盖该合入）→ 你审我裁足额，洪涛"评审后落地"满足。**熔断**：Tina 执行中发现非小时级（接线扩散 >10 文件、或现第二个污染键、或任何 src/ 改动需求）→ 停手上报转完整评审链。

## 5. 范围确认

- 本单半天封顶；M1 P3/P4 设计不因此插队 ✓
- 存量债 20 suite 不属污染治理：同意报告 §4.4——v6.2 断言清偿合入自动清大头，残余走断言清偿通道
