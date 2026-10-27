# T-1023-OC-01·P4·Batch3 首项验证（Tina）— Enums.swift 渐升梯三轴单源表（d8d951f + c700bd4）

- **验证人**：Tina｜**日期**：2026-10-25 00:23-00:45｜**链**：编码（Cody）→ Ruby 审（P4B3-review 通过）→ **Tina 验（本件）** → 门禁 → tag
- **对象**：d8d951f（首项，6 files +190/-98）+ c700bd4（Ruby P1-1 返工，6 files +87/-59），基座 b172bc3；区间内另有 b5a9357（release-notes docs，非验证面）
- **结论**：**验收通过（PASS）**——静态核对全项 ✅；独立复验链 12/13 PASS 计数全对账；CalibrationV3Tests zero-run 为 KI-2026-0922-01 独立实证（预期内，非本批致红）；锚勘误 1 处（SkillLevel→Fallback 归属错位）；观察 3 条不阻塞

---

## 一、锚定与产物真实性

- HEAD=c700bd4（m1），tracked 面净（untracked 仅 docs 审查/审计件）
- d8d951f stat 与申报逐字全等（6 files +190/-98）；c700bd4 stat 与申报逐字全等（6 files +87/-59）✅
- 产物真实性：Enums.swift mtime 10-24 23:37:13 < 测试二进制 mtime 10-25 00:24:21（/tmp/xc-mutex-dd），构建含最新源 ✅

## 二、静态核对（验收重点①②③）

### 1. 三轴定稿表逐格对齐（重点③）✅
Enums.swift s2Spec（:172-184）＝ t1023-remediation-plan v1.1 §五首项表＝ T1023P4B3LadderTableTests ladderRows 常量，三方逐格全等：

| 档 | skill | movetime(ms) | ladderElo |
|---|---|---|---|
| lvl1 novice（豁免位，b 形态） | 0 | 1000 | 1000 |
| lvl2 beginner | 2 | 500 | 1338 |
| lvl3 amateurLow | 4 | 700 | 1712 |
| lvl4 amateurMid | 5 | 1000 | 1801 |
| lvl5 amateurHigh | 7 | 1400 | 2056 |
| lvl6 amateurDan | 9 | 2000 | 2336 |
| lvl7 proApprentice | 11 | 2800 | 2473 |
| lvl8 proExpert | 14 | 3600 | 2627 |
| lvl9 proMaster | 17 | 4400 | 2700 |
| lvl10 grandmaster | 20 | 5000 | 3170 |

lvl1 豁免位 movetime 首值 1000 系丹妮 10-24 定稿澄清（注记①在案）；缺省 a 形态 novice=selfResearch skill=nil@2000。

### 2. P2-2 派生消费点登记核对 ✅
SelfPlayRunner:1106-1107 `redSkill/blackSkill = override ?? difficulty.skillLevel ?? 0`——无字面量、走单源派生；自弈历史基线换轨备注已随 Ruby P2-2 登记（老数据锚旧刻度，跨版本对比需换轨说明）。

### 3. P1-1 修复面（重点②）✅
- CalibrationV3Tests skillMap×7 断言（8 输入）：0→beginner / 4→amateurLow / 5·6→amateurMid / 7→amateurHigh / 10→amateurDan / 13→proExpert / 20→grandmaster，与 Ruby 判词表逐格合，20 精确档维持
- skillToDifficulty 实现新态：`allCases.filter { $0.s2Spec.skill != nil }.min(by: 距离) ?? .beginner`——旧硬编码五档 mapping（0/4/7/10/20→amateurDan/proApprentice/proExpert/proMaster/grandmaster）退役，单源转正
- 八映射独立推演全过：候选序 [2,4,5,7,9,11,14,17,20]；skill 6 与 10 两处并列由 min(by:<) 序先语义落 amateurMid/amateurDan（AIDifficulty case 声明序 :31-42 亲验）
- 证据测替位：LadderTable.skillToDifficultyNearestMapping（8 映射同口径）实跑在 6/6 内 ✅

### 4. 扩圈清偿定谳 ✅
- DifficultyV42Tests §四：五钉 9/11/14/17/20 + 业余档 novice nil / lvl2-5=2/4/5/7（v4.2 旧值钉全数退役为梯表派生钉）
- V60Phase3Tests：skillLevelValues 五钉（amateurDan=9/proApprentice=11/proExpert=14/proMaster=17/gm=20）、业余 nil 口径×2（amateurSkillLevelNil/amateurNoSkillLevel）、s9 回归钉两处（:161/:359）
- V60Phase6Tests：regressionPhase1to5 amateurDan 0→9
- RouterTests routeAmateurToNative：新契约 novice（缺省 a 形态）→AIEngine + lvl2-10→EmbeddedPikafishEngine；原"业余级全走 native"自 T-1013 S2 载体换轨起陈旧，失败模式 4 issues 恰 lvl2-5 四档——**存量陈旧定谳，非本批致红** ✅

### 5. P2-1 注释勘误 ✅
SelfPlayRunner 三处（:935-937 / :1244-1245 / :1653-1655）旧"skillLevel=nil/depth=10"口径→override 守卫+s2LockTable depth=0 现行口径，纯注释零行为变更。

### 6. 首项测试面重锚 ✅
- T1013OC03S2RelevelTests：段距 ≥100 门→全梯非降（方案 A 裁定 2026-10-24）+ lvl2-5 逐档对表（s2@500/s4@700/s5@1000/s7@1400）+ 过渡位转正（s9@2000/s11@2800/s14@3600/s17@4400，transitionSlot 标志保留=UI 分组语义）+ 尾锚 lvl5 2056 < lvl10 3170
- SelectionConsistencyTests：①-7 口径改载体自洽（skillLevel≠nil ⇔ usesPikafishEngine）+ isProfessional 五档 UI 分组显式维持

### 7. 红线自查 ✅
L10n 锁表/xcstrings 零触碰；定稿件（ChineseChess-iOS/）零触碰；s2MigrationMap/Codable 本体零变更；测试单通道（flock owner=tina 获锁 00:24:11）；树净。

## 三、独立复验链（重点①+返工终轮，Tina 00:24:11-00:26:49）

python-setsid 双脱离（PID 81914，PPID=1，PGID=自 PID）；runner 互斥+语言锁+dd 自检全过；日志 /tmp/t1023-b3-verify/chain.log + 逐套件 ~/DevTeam/workdirs/logs/h1/：

| # | Suite | 实跑 | 锚 | 判 |
|---|---|---|---|---|
| 1 | T1023P4B3LadderTableTests | 6 | 6 | ✅（完整性四门+证据测） |
| 2 | DifficultyV42Tests | 29 | 29 | ✅ |
| 3 | V60Phase3RouterTests | 6 | 6 | ✅ |
| 4 | V60Phase3FallbackTests | 4 | — | ✅ |
| 5 | V60Phase3SkillLevelTests | 3 | 4* | ✅（*锚勘误见下） |
| 6 | V60Phase3ToolbarTests | 3 | — | ✅ |
| 7 | V60Phase3RegressionTests | 5 | — | ✅ |
| 8 | V60Phase3P1FixTests | 9 | — | ✅ |
| 9 | V60Phase6Tests | 19 | 19 | ✅ |
| 10 | SelectionConsistencyTests | 26 | 26 | ✅ |
| 11 | T1013OC03S2RelevelTests | 15 | 15 | ✅ |
| 12 | GameViewModelTests | 7 | 7 | ✅ |
| 13 | CalibrationV3Tests | 0 | — | FAIL(zero-run)＝KI 实证位（预期） |

- **锚勘误（归属错位，随单勘误）**：派单"SkillLevel 4"实为 Fallback 套件计数——SkillLevel 套件源码恰 3 个 @Test（V60Phase3Tests.swift:157-189），实跑 3；Fallback 实跑 4。V60Phase3 六套件合计 30 全绿不变，勿硬凑口径。
- **KI-2026-0922-01 独立实证**：CalibrationV3Tests 定向批命令行同时含 `-skip-testing:ChineseChessTests/CalibrationV3Tests`（skip_args() awk 对状态列"skip（全量批）"无差别消费）与 `-only-testing:ChineseChessTests/CalibrationV3Tests` → Executed 0 tests + **TEST SUCCEEDED** 假绿，runner 零跑门禁拦截 FAIL(zero-run)。与 Cody 批内 H-1 汇总同源；隔离复跑同遇，非本批零跑。断言面以 §二.3 推演+LadderTable 证据测替位核验。
- **验收重点④（在盘 log）**：~/DevTeam/logs/t1023p4-b3-rework-tests3-1024.log 00:11:39 `** TEST SUCCEEDED **` + PASS V60Phase3RouterTests + 锁释放 rc=0 ✅。

## 四、用户路径覆盖审查

本批零 View 变更（Enums 数据表+AI 消费面+测试），用户可见链路为数据层间接影响，按链路逐条核：

| # | 用户操作 | 入口/数据查询 | 空数据保护 | 错误处理 | 用户反馈 | 覆盖证据 |
|---|---|---|---|---|---|---|
| 1 | 选难度→AI 载体路由 | EngineRouter.engineFor(difficulty) | lvl1 缺省 a 形态自研兜底（novice skill=nil 不崩） | Pikafish 不可用 fallback（routeProFallbackToNative） | 横幅占位档显示 | Router 6/6 + Selection 26 |
| 2 | 难度刻度展示 | skillLevel≡s2Spec.skill 派生 | novice a 形态 nil 不参与刻度 | — | 梯表值显示 | SkillLevel 3 + DifficultyV42 29 |
| 3 | 难度渐升强度 | s2Spec 三轴（skill/movetime/ladderElo） | lvl1 豁免位锁值 ≤1000 | — | 段位体感非降 | LadderTable 6 + S2Relevel 15 |
| 4 | 自弈/校准 CLI | SelfPlayRunner:1106-1107 派生消费 | override 优先守卫 | 换手随槽位交换颜色归属 | 批头 movetime 文案 | Ruby harness 亲验 + P2-2 复核 |

缺失项：**无 P1**。（override 活性期横幅显示占位 .amateurLow 为 Ruby 审查四.4 已验等价面，非缺失。）

## 五、观察（不阻塞，候池）

- **O-T1** Enums.swift:38-42 enum case 尾注旧刻度（amateurDan "(Skill 0)"、proApprentice "(Skill 4)" 等）为前批遗留（d8d951f 未触碰 case 行），与现行梯表 s9/s11/s14/s17 矛盾——建议随下一 docs 批清偿，防误导后来者。
- **O-T2** CalibrationV3Tests skillMap10 失败消息"比距 proMaster(s17)=7 近"措辞不准（真正并列对手是 proApprentice s11 距 1），断言值正确——KI 修复解封该套件时顺手更正。
- **O-T3（KI-2026-0922-01 修复建议）**：skip_args() awk（$3 ~ /skip/ 无差别匹配）与 skip-registry"单跑/定向批不受限"注记脱节，定向批被误伤零跑。修法三选一：①awk 状态列精确匹配 ②状态列改"skip-full"并同步 awk ③skip_args 仅 --full 模式注入。修复落地同 commit 更新 skip-registry（单源纪律）。

## 六、判定

**验收通过（PASS）**：d8d951f+c700bd4 三轴单源表落地精确（三方逐格全等）、P1-1 返工清偿彻底、存量陈旧钉清偿定谳、独立复验 12/13 全绿计数对账（1 锚勘误随单）。Batch 3 C 包排程不受阻。

—— Tina｜2026-10-25｜复验链证据 /tmp/t1023-b3-verify/（chain.log + verify.done DONE_RC=1[预期：KI 实证位 FAIL 所致]）+ ~/DevTeam/workdirs/logs/h1/ 逐套件日志
