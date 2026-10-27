# T-1023-OC-01·P2·D1 — 设计文档符合度矩阵（①维工作底稿）

> 角色：Alex（架构师，①维主笔）| 日期：2026-10-21 | 版本：v1.2（Cody 终版并入+§九 终裁落定）
> 状态：**①维完成（自核面+全部分片到位）**——骨架+PRD 裁定+D0⑤ 三项+r3-07 静态核销+类 3 全件+v6 系锚件①②③+散件轻片+Cody 分片+Eric v2/v3 分片；D7 汇总（10-23 交丹妮）
> 依据：docs/plans/T-1023-OC-01-inspection-plan.md v1.1 §三/§五；丹妮审查裁示 2026-10-20 23:0x
> 修订记录：v1.2 — 2026-10-21 §九 覆盖缺口终裁落定（v4.0/v4.1 缺件五件四态+bayeselo T-1022 归属+coach 系 proposals 定位）+60 步裁决登记（丹妮：采纳 120 半着处方，PRD/实装 100 判 P1 规则合规整改，Tina 脚注修正随 D7 A 包）｜v1.1 — 2026-10-21 Cody 分片（v4/v5 系+专项片）四态行并入尾节——14 件 ~35 行；puzzle-difficulty-rework 落地复查回销 Eric 指针+auto-demo 归属建议归 v4/v5 片+P1 高优行×2（fingerprint 修复不对称/60 步规则冲突）｜v1.0 — 2026-10-21 Eric v2/v3 分片并入（9 件四态：已实现 2/文档过时 6；ui-layout-redesign-v4 方向性风险件登记）——①维矩阵全分片到位｜v0.9 — 2026-10-20 散件+轻片收尾批（变招展示/持久化决策/棋力评估销项+user-guide 口径漂移+test-rules 过时登记），①维自核面闭合｜v0.8 — 2026-10-20 v6 系锚件③（v6.4 布局链已消费+v6.4 系过程件归类 5+v6.5 backlog 规划态自洽+iOS 适配部分覆盖注记）｜v0.7 — 2026-10-20 v6 系锚件②（v6.2 HIG 消费链+parity 参照物+v6.3 修复链 git 亲证，衍生双写根因 sweep 项）｜v0.6 — 2026-10-20 类 3 余件判定（difficulty-v3 文档过时/坐标系延续、v4-final 重映射已实现、v4.3 被 S2 结构性取代）｜v0.5 — 2026-10-20 类 4 v6 系片锚件①（S2 锁表全表对齐销项+枚举注释漂移 P3 候选登记）｜v0.4 — 2026-10-20 类 3 决策包定稿链首批判定（裁定⑥ Q1/Q2/S2 锁表已实现、Q3/Q4 规划态文档自洽）｜v0.3 — 2026-10-20 类 2 商业交付清单 r3-07 静态核销完成（方法论有效/口径面过时定谳+551 局口径仍准确取证）｜v0.2 — 2026-10-20 D0⑤ v3.9 性能链三项核销登记（2 销项+1 文档过时）+r3-07 两项候选登记｜v0.1 — 2026-10-20 骨架落盘 + PRD 双副本裁定（P2 首日项完成）

---

## 一、PRD 双副本裁定（P2 首日项 ✅，裁示③执行）

**裁定**：`docs/需求功能说明书.md`（v2.1）= **唯一真相源**；`docs/general/需求功能说明书.md`（v1.1）= **过期副本**，禁引用，候归档处置（P4 文档修批执行；本检查按红线只登记不动文件）。

**依据链（三点引证）**：
1. **版本/体量**：root v2.1（基线应用 v5.6.2 快照→v2.x 火车，1012 行）vs general v1.1（基线 v5.1.0，461 行）；diff 1145 行——v2.1 系 v1.1 的扩展演进而非分叉，两副本无实质冲突
2. **git 链**：两路径同源 commit ac98447（"docs(prd): add requirements spec v1.1, revised per review report"）；root 经 6fdc513（"docs(phase-6): v6.0 design docs..."批次）演进至 v2.1；general 仅 fdfb0fa（fix(ui) minWidth）顺带触碰后停滞。mtime：general 2026-07-23 vs root 2026-08-08（v5.6.1 审计当日升版 v2.1）
3. **消费链**：v5.6.1 全需求审计（docs/audits/v5.6.1-full-requirement-audit.md 头部）引用 root 路径为 PRD 基线；v6.0 后各版本设计文档均以 root 为需求锚

**备案**：随 D1 启动通报备案丹妮（2026-10-20 深夜）。实质冲突条款：不触发（演进非分叉）。

## 二、盘点矩阵（六类分片，四态待填）

四态：已实现 / 部分实现 / 未实现 / 文档过时；证据 = doc 路径:行 ↔ code 文件:行 成对。

### 类 1 需求/PRD（Alex 片）
| 文件 | 版本 | 处置 |
|---|---|---|
| docs/需求功能说明书.md | v2.1 | 唯一真相源；全量对照分片=PRD 模块 × v6.4.2 实现面（含 v2.x 火车"需求定义"条目单列——那是规划非现状，防误判"未实现"） |
| docs/general/需求功能说明书.md | v1.1 | 过期副本（§一裁定），登记候归档 |
| docs/archive/需求功能说明书-v1.1-2026-08-08-archived.md | v1.1 | 归档态，不对照 |

### 类 2 商业交付清单（Alex 片，优先核销）
| 文件 | 对照面 |
|---|---|
| docs/archive/v3.4.x/design/r3-07-commercial-delivery-checklist.md | 逐项 vs v6.4.2 现状（releases/ 产物、Info.plist 版本面、资产四件套 NNUE/开局库/字体/音效、图标） |

### 类 3 定稿态/锁数红线（Alex 片，只读零触碰）
| 文件 | 状态 | 对照面 |
|---|---|---|
| docs/design/T-1015-OC-01-l1-carrier-decision-pack.md | v1.3 归档态 | 裁定⑥四裁（Q1-Q4）实装现状核验：lvl1 载体双轨（Enums.swift L163 注释引用，仅现状引用非真源）+ L1 UI 定位/命名面（§六） |
| docs/design/v65-weakening-chain-v3-draft.md | **v1.0 正式版**（裁示①"v3.0 定稿"锚） | §7 v3.x 候选池（handicap 让子，裁定⑥ Q3 主路径）文档态 vs 实现态差距（v6.5 候选池预期未实装→应标"文档规划态"非"未实现缺陷"） |
| docs/design/difficulty-system-v2.2-draft.md | v2.2 v1.5 锁数 | §2.1 lvl1 行/§2.4 命名 vs L10n 段位制换轨实装（v6.4.1） |
| docs/design/difficulty-system-v3.md / v4-final.md / v4.3.md | v3 定稿链/v4.2 定稿/v1.2 | Elo 映射面/区分度方案 vs 引擎实装（与 T-1022 校准域边界：只对照文档承诺，不下校准结论） |

### 类 4 设计文档链（~100 件，四片）
| 片 | 范围 | 负责 |
|---|---|---|
| v6 系片（增量域主战场） | v6.0-*×8、v6.2-*×3、v6.3-scope-draft、v6.4-*×8、v6.5-backlog、v65-weakening-chain×4、v6.0-level-naming/v6.0-strength-assessment 等 ~25 件 | Alex 自核 |
| v4/v5 系片 | v4.0-*×6、v4.1-*×3、v5.0-*×2、opening-book/explorer、coach/master-game/puzzle-demo 系 ~20 件 | **已交（Cody）**：t1023-dim1-shard-cody.md——14 件四态行 ~35（已实现/已修复 21｜部分实现 4｜仍开放 5｜文档过时/漂移/质量 7｜分析件 1）；结论行已并入本矩阵尾节，覆盖缺口 8 件名登记（底稿 §九） |
| v2/v3 系片 | difficulty 早期系、tutorial-redesign、ui-layout 系、ios-toolbar-adaptation ~15 件 | **已交（Eric）**：t1023-dim1-shard-v2v3.md——9 件四态（已实现 2/文档过时 6/部分 0/未实现 0），含方向性风险件 1 |
| 专项片 | ai-engine-improvements、ai-search-optimization-phase3、board-thread-safety-fix、draw-detection-analysis、engine-gap-analysis-elephanteye、bayeselo 系 ~10 件 | **已交（Cody）**：5/6 族入上格底稿（ai-engine-improvements/ai-search-optimization-phase3/board-thread-safety-fix/draw-detection-analysis/engine-gap-analysis-elephanteye 均四态闭环）；bayeselo 系件名未定位（登记缺口，终裁权=矩阵 owner） |

### 类 5 阶段/计划/审查/审计/active（证据源+抽查片）
- docs/phases/ ~30 件：抽查完成度声明 vs 台账验收链（不逐件全查，抽 v6.0 phase1-6 + m1 系）
- docs/plans/ docs/reviews/ docs/audits/：基线与证据源（非对照对象）
- docs/active/ 三件（normalization 系）：衔接标注，不重复立项

### 类 6 用户/指南/测试面（轻片）
- docs/user-guide/pikafish-setup.md、docs/guides/ios-deploy-guide.md、docs/test/ 三件（skip-registry/platform-branch-matrix/os-branch-disposition）、docs/general/ 通用件——与实现现状轻对照

## 三、执行序（轻入场节奏）
1. **首日（已完成）**：PRD 双副本裁定 + 锚件定位（类 2/3 表落定）
2. **次日**：类 4 v6 系片（增量域）+ 类 2 商业交付清单逐项核销
3. **三日**：余片回收（候派件到稿后）+ 四态汇总 → docs/audits/t1023-summary.md 输入

## 四、发现项登记（滚动追加）
> 格式：[四态/分级] 结论一句话｜doc 证据｜code 证据｜处置建议

### D0⑤ v3.9 性能链三项核销（Alex，2026-10-20 深夜）

- **[已修复] QS 全量走法生成（v3.9 D1-P1-4）**：quiescenceSearch 已改用专用吃子生成器 captureMoves（跳 wouldBeInCheck）+ MVV-LVA 排序 + delta 剪枝 + 增量 Zobrist + 时间管理两段式硬中止 + make/unmake 平衡断言｜doc: docs/audits/v39-d1-game-logic.md（D1-P1-4）、v39-phaseb-summary.md §四#18｜code: src/ChineseChess/AI/AIEngine.swift:919-926、:897-906；src/ChineseChess/Models/MoveValidator.swift:28-35｜处置：销项，无 P4 动作
- **[已修复·形态演进] wouldBeInCheck 深拷贝（v3.9 D1-P2-1）**：v3.9 处方"in-place execute/undo"以 LegacySearchBoard 轻量副本实现（makeSearchBoard→execute→isInCheck），原棋盘零修改，契约由 v4.0 Phase1 测试钉死｜doc: v39-phaseb-summary.md §四#17｜code: src/ChineseChess/Models/MoveValidator.swift:321-325；src/ChineseChess/AI/BoardReadable.swift:15；src/ChineseChessTests/V40Phase1Tests.swift:302-303｜处置：销项；每次调用仍建轻量副本，残余成本列"需 P4 实测确认"观察项（非静态缺陷）
- **[文档过时/处方被取代] medium QS 缺位处方（v3.9 Phase2 #5）**：v3.9 处方"medium 加 QS(深度2)"曾落地（medium 配置 maxQSDepth=2 仍在码），难度体系 v4.2 重设计改判 mediumNoQS（enableQuiescence=false 由测试钉死），medium→hard 断崖问题移交 v4.3 区分度方案+v6.0 十级+Pikafish remap 链｜doc: v39-phaseb-summary.md §四#5、§3.1｜code: src/ChineseChess/AI/AIConstants.swift:60-76（medium maxQSDepth=2）、:96-112（mediumNoQS）；src/ChineseChessTests/DifficultyV42Tests.swift:11-14｜处置：v3.9 项销项；衍生核验项→⑤维"现行 mediumNoQS 下 medium→hard 梯度"（挂 T-1022 边界：只对照文档承诺不下校准结论，P4 实测确认）

### 其他登记

- **[文档过时/P3·候选] r3-07 头部日期 2025-06-13**：疑为 2026-06-13 笔误（document-conventions §3 日期纪律=必须 2026；v2.2.15 时代吻合 2026-06）｜doc: docs/archive/v3.4.x/design/r3-07-commercial-delivery-checklist.md L4｜code: —｜处置：登记候 P4 文档修批随手改
- **[文档过时·候选] r3-07"五档 AI"口径**：R1-1 #1.7 基于 v2.2.15 五档（新手/初级/中级/高级/大师），现行=v6.0 统一十级段位制｜doc: r3-07 L48-49｜code: —｜处置：商业交付清单核销（day-2）时逐项标注

### 类 2 商业交付清单 r3-07 静态核销（Alex，2026-10-20 深夜，day-2 提前完成）

- **[文档过时/方法论有效·定谳] r3-07 整体判定**：v2.2.15 时代商业交付检查方法论（4 轮 87 项：R1 功能 32/R2 体验+i18n+无障碍 27/R3 性能+打包 14/R4 竞品+验收 10+附录索引），四轮分层过滤骨架对 P3 整改方案设计仍有复用价值；具体口径多项过时，动态检查项（VoiceOver/竞品/性能实测/打包）按 P1-P3 约束留 P4｜doc: docs/archive/v3.4.x/design/r3-07-commercial-delivery-checklist.md 全文 329 行｜code: —｜处置：方法论归 P3 整改方案设计输入；过时口径逐项列下
- **[仍准确] 残局 551 局口径**：puzzles.json 551 ids 从 v2.2.15 延续至 v6.4.x（releases/中国象棋-v6.4.1.app/Contents/Resources/puzzles.json 亲证 551 ids/275KB；v6.4.0/v6.4.2 同源；另有 puzzles-v3-backup.json 551 ids 同库备份）｜doc: r3-07 L34（1.9 残局总数）/L218（3.7）/L268（4.4 差异化优势）｜code: releases/中国象棋-v6.4.1.app/Contents/Resources/puzzles.json｜处置：口径无需改，核销通过
- **[文档过时] r3-07 口径过时项清单**：①五档 AI（→v6.0 十级段位，前条已登记）②i18n 键数 149/151 .strings 时代（→xcstrings 544 keys v3.9 审计口径→**现值 876 keys**，src/ChineseChess/Resources/Localizable.xcstrings python3 json 亲证 2026-10-20）③Info.plist 2.2.15（→6.4.2，project.yml L63-64 MARKETING_VERSION/CURRENT_PROJECT_VERSION 亲证+releases/ v6.4.2.app 在盘）④swift test（→SPM 已废弃，xcodebuild test 经 run-tests-mutex.sh runner，DEVTEAM.md 铁律）⑤R3-18 x86_64 口径（现主机 Intel x64 仍适用，arm64 适配面未验）｜doc: r3-07 L156-158/L238/L246/L258/L264｜code: project.yml:63-64、releases/｜处置：登记，方法论复用时口径替换

### 类 3 锚件：决策包定稿链首批判定（Alex，2026-10-20 深夜；裁示①锚，只读零触碰）

- **[已实现] 裁定⑥ Q1（L1 默认载体=A 自研 hard-d1 维持）**：lvl1UsesPikafish=false 默认基线+S2LevelSpec novice 豁免档（usesPikafish=false/budgetMs=2000/ladderExempt=true）+注释引裁定⑥｜doc: T-1015-OC-01-l1-carrier-decision-pack.md L118（Q1=A 复审确认）｜code: src/ChineseChess/Models/Enums.swift（lvl1UsesPikafish 定义+S2LevelSpec .novice 分支）｜处置：销项
- **[已实现] 裁定⑥ Q2（选项 b 隔离保留为工程对照资产/dev 实验开关永不上 UI）**：一键切开关在+EngineRouter 披露注释逐字落位（回退后强度≠skill0 已知语义——决策包 §六.5"一行级随行"要求实现）｜doc: 决策包 L119（Q2=保留偏离显式标注）+§六.5｜code: src/ChineseChess/Models/Enums.swift（lvl1UsesPikafish 注释）、src/ChineseChess/AI/EngineRouter.swift:77｜处置：销项
- **[已实现] S2 锁表参数对齐（v65 v1.0 正式版 §0/§2.1/§2.3）**：lvl2-5=Pikafish s0/s4/s7/s10 @5000/5000/5000/10000（beginner=s0/amateurLow=s4 亲证，s7/s10 归同表续验）、lvl10=s20、lvl1=hard-d1 豁免档；实施基线 T-1013-OC-03 消费在案｜doc: v65-weakening-chain-v3-draft.md §0.1/L39/L65｜code: src/ChineseChess/Models/Enums.swift（S2LevelSpec 各 case）｜处置：销项（s7/s10/lvl6-9 过渡位/lvl10 续验归 v6 系片）
- **[规划态/文档自洽] 裁定⑥ Q3（handicap 让子=L1 可玩性 remedy 主路径）**：v65 §7 明文"候选池登记不入本版实施"，v3.x 专项设计候裁——文档自身声明规划态，实现缺失非缺陷｜doc: v65-weakening-chain-v3-draft.md L97-99｜code: —（无让子机制实现，符合文档声明）｜处置：销项；v3.x 立项时回查
- **[部分实现/前置就绪] 裁定⑥ Q4（复审触发条件=设）**：统计机制在盘（StatsManager.swift/GameRecordStatsAggregator.swift/GameRecordStore.swift）满足决策包"统计随 v3.x 立项"前置+T-1019-OC-01 随批统计面（让子局打标/未终局时长门控）已落；触发线专设面（新手定义 M 场阈值+复审呈裁自动化）未定位到专设实现——决策包明言"候 v3.x 立项裁"，属规划态非缺陷｜doc: 决策包 L121/L125（Q4+前置/降级条款）｜code: src/ChineseChess/Services/StatsManager.swift 等三件在盘｜处置：销项（降级条款兜底）；v3.x 立项时回查
- **[已实现] 段位命名终表面（v6.4.1 L10n 段位制换轨佐证）**：终表值 Association Master（lvl7）在 xcstrings:13403+Enums/PlayerProfile/BoardTheme/LocalizedNameResolver 消费面在盘｜doc: difficulty-system-v2.2-draft.md §2.4 命名面（姊妹件锁数）｜code: src/ChineseChess/Resources/Localizable.xcstrings:13403｜处置：全表 10 级对照+zh/en 双语归⑥维 i18n 详查（Eric 片）

### 类 4 v6 系片锚件①：S2 锁表续验（Alex，2026-10-20 深夜；上批 s7/s10/lvl6-9/lvl10 遗留项闭合）

- **[已实现] S2 锁表全表对齐（v65 v1.0 正式版 ↔ Enums.swift，销项）**：lvl2-5=s0/s4/s7/s10 @5000/5000/5000/10000 四档全亲证（beginner/amateurLow/amateurMid/amateurHigh）；lvl6-9=过渡位 transitionSlot=true（s0@5000/s4@6000/s7@7000/s10@8000，v4 重映射注释 L131-135 在，与 spec"现行实现维持"口径一致）；lvl10=s20@10000/ladderElo 3300；lvl1=默认 a 豁免档｜doc: v65-weakening-chain-v3-draft.md §0.1/§2.1/§2.3（v0.3.1 锁表口径）｜code: src/ChineseChess/Models/Enums.swift L167-184（S2LevelSpec 全 switch）+L131-135（v4 重映射）｜处置：销项，S2 链闭合（决策包批+s65 批合并）
- **[已实现] v6.0 十级引擎前置（Pikafish Skill Level 恢复）**：skill 轴已在 S2LevelSpec 承载强度梯度，业余/专业分层落地｜doc: v6.0-unified-10-level-engine.md v3.0 头部（前置条件"恢复 Pikafish Skill Level 支持"）｜code: Enums.swift L174-184｜处置：销项；棋力评估功能面对照归②维 Tina 片
- **[文档过时/P3·候选] Enums.swift L31-42 段位注释停 v6.0 命名时代**：注释"6级 棋友/7级 棋手/8级 棋师/9级 大师/10级 棋圣(Skill 20)"未随 v2.2 §2.4+10-18 终表更正同步（现行终表：lvl7=棋协大师/Association Master、lvl9=特级大师/Grandmaster、lvl10=棋圣/Sage、lvl6 短名 地方大）——纯注释面零功能影响，显示真源=xcstrings L10n（v6.4.1 换轨已落）｜doc: v6.0-level-naming.md v1.0（被 v2.2 §2.4+终表演进取代）｜code: Enums.swift L31-42 vs Localizable.xcstrings:13403｜处置：登记候 P4 随批注释同步（code-face，P4 解除约束后改）；v6.0-level-naming 标"文档过时（被取代链）"

### 类 3 余件：difficulty v3/v4-final/v4.3 三件对照（Alex，2026-10-20 深夜；只读零触碰）

- **[文档过时/数据资产延续] difficulty-system-v3.md（v3.2）**：方案层被 v4-final v4.2 定稿取代（v4-final 头部明言"替代 v2.1 和 v3.x 系列"）；但其 Pikafish 官方天梯坐标系锚值逐值延续实装——Skill 0/4/7/10→1280/1777/2268/2568（doc L39-44）↔ S2LevelSpec ladderElo beginner/amateurLow/amateurMid/amateurHigh 全对齐｜doc: difficulty-system-v3.md L13-44（天梯坐标系+lvl3/4/5 全败修正）｜code: src/ChineseChess/Models/Enums.swift L174-177｜处置：销项（坐标系活性延续）；文档标"被 v4.2 取代"
- **[已实现] difficulty-system-v4-final.md（v4.2 最终定稿）**：§5.3 AIDifficulty.skillLevel 重映射 5 行逐字落码——amateurDan 0（←4）/proApprentice 4（←7）/proExpert 7（←10）/proMaster 10（←13）/grandmaster 20 不变，与 Enums.swift L131-135 注释逐字对齐+DifficultyV42Tests 钉死｜doc: difficulty-system-v4-final.md L342-347（§5.3 重映射 5 行）｜code: Enums.swift L131-135；src/ChineseChessTests/DifficultyV42Tests.swift｜处置：销项（lvl6-9 过渡位设计现行有效）
- **[文档过时/被 S2 结构性取代] difficulty-system-v4.3.md（v1.2）**：A3 区分度方案（温度冻结/lvl4 结构性升强/lvl5 联动）基于自研引擎参数轴；v65 v1.0 正式版 §0.1"自研引擎参数轴全部退出梯度职能"+lvl3=s4/lvl4=s7 刻度结构性拉开，原问题域（lvl3 vs lvl4 区分度）在 S2 锁表下消失——方案使命已被更高层设计吸收｜doc: difficulty-system-v4.3.md 头部 v1.2 修订记录；v65-weakening-chain-v3-draft.md §0.1｜code: —（参数轴退出梯度职能系 S2 定案态）｜处置：销项（取代链正常演进）；Softmax temp 机制面（SelfPlayRunner/AIEngine/SeededRandom 在盘）归②⑤维深查

### 类 4 v6 系锚件②：v6.2 消费链 + v6.3 修复链（Alex，2026-10-20 深夜）

- **[已实现/已消费] v6.2 HIG 审计→门禁链**：Vera HIG 审计 P2-1 产出 parity 表→v6.2 增量合入 m1 主树（merge 9ebfa0e）→门禁四步全绿归档（xcodegen 双工程/双态编译 BUILD SUCCEEDED×2/全量测试批零 v6.2 回归）｜doc: docs/reviews/v6.2-gate-final-report.md L10-16（2026-08-26）｜code: merge 9ebfa0e 在库｜处置：销项；HIG 细项复核归④维 Vera（v6.4 布局 C 线后状态）
- **[参照物有效/时点快照] v6.2-platform-parity-table.md**：口径锁死 Views+App 75 处 #if os()（v6.2 tip b1cf39f，Vera 定案"参照物非机制"），五类差异原因分类+[待统一]零目标； Luke 排除范围声明（21 处非 Views/App 列 v6.3 候选）——现行 Views+App 计数抽查见下，全库 drift 面归④维详查｜doc: v6.2-platform-parity-table.md 头部｜code: 现行 Views+App #if os( 计数=**84**（2026-10-20 grep 亲证；v6.2 口径 75→84 漂移 +9，v6.3/v6.4 线新增平台分支所致，快照文档非缺陷）｜处置：候选登记（21 处）处置去向未明（v6.3 plan 头部未见收编）→④维 Vera 复核清单（含 +9 drift 面重对账）
- **[已实现/已消费] v6.3 收尾方案链**：scope（Vera 终审 PASS，5.75-6.75 人日）→plan v1.1（五层防线，逃逸率 5/9→<20% 目标）→v6.3.0 已知缺陷中间态（tag 保留历史标记）→v6.3.1 热修=正式锚；修复链 ca8d91f..0d343f1 git 亲证（c4f50cd=v6.3.1 同根因第 4 处 AssessmentSession 双写历史同修+f67b032 反证锚清理+0d343f1 两触发形态回归测试）｜doc: docs/plans/v6.3-plan.md 头部、docs/release/release-notes.md v6.3.0/6.3.1 口径｜code: git log ca8d91f..0d343f1 三 commit 在库亲验｜处置：销项
- **[衍生核验项] 双写历史同根因 sweep**：该根因已修 4 处（c4f50cd 为第 4 处），known-issues"复盘分析静默 nil（6.3.1 热修）"条目仍 active·长期建议——同模式残余实例静态 sweep（analysis/persistence 路径 grep 双写/append 历史模式）归②维 Tina/D5 我的⑤维分片候办｜doc: known-issues.md L78-82；c4f50cd commit message｜code: —｜处置：登记待办，非缺陷结论

### 类 4 v6 系锚件③：v6.4 布局链 + v6.5 backlog（Alex，2026-10-20 深夜）

- **[已实现/已消费] v6.4 布局重设计链**：洪涛两条布局输入→设计单 v0.1→v0.4 R3 洪涛拍板落地（2026-09-01：P9 复盘=独立窗口/深色模式不做/进度环克制，三开放问题全闭环）→编码排期→v6.4.x 发布承载（releases/ v6.4.0~v6.4.2 在盘；T-1020 工具栏 A+B/移动端适配随批 done）——"深色模式不做"系拍板决策非实现缺失｜doc: v6.4-layout-redesign.md 头部状态行｜code: releases/ 四包在盘｜处置：销项；深色模式面=拍板豁免不列缺口（④维 UI 维度同口径）
- **[已消费] v6.4-ui-debt-ledger.md（病灶档案）**：Eric 三案汇编（sidebar 挤压系列等，四要素：复现/根因/受影响页面/教训），头部自述消费者=Alex v6.4 布局重设计——输入件已消费｜doc: v6.4-ui-debt-ledger.md 头部｜code: —｜处置：销项；v6.4 系其余过程件（plan/predraft/phase1-order-A/B/c-line-schedule/r3-brief/889ebf7-arch-review 等）归类 5 消费链证据源，不逐件四态（方法：过程件以台账/验收链为消费凭证）
- **[规划态/文档自洽] v6.5-backlog.md**：正式立档（Luke 2026-09-01，洪涛批准），条目均为拍板延后性质（iOS 布局紧凑适配记 v6.5/渐进分析等）——backlog 承诺未来非现状，不判"未实现"｜doc: v6.5-backlog.md 头部+条目 1/2｜code: —｜处置：销项；注记：条目 1（iOS 紧凑适配）已部分推进（T-1020-OC-01 done 两处适配：开局选择页+教练页），全域紧凑适配仍开放——backlog 状态自洽，无漂移

### 类 4 散件 + 类 5/6 轻片收尾批（Alex，2026-10-20 深夜；①维自核面闭合批）

- **[已实现] v6.4-a2-variation-display.md（v1.2）**：变招展示 Views 面在盘（AnalysisView/OpeningExplorerView/GameRailView），头部自述前置已满足（A2 持久化已合主干 sidecar 链全通+mate 污染 ec4b9c1 消费侧归一）；v1.2 Luke 终定五条落地即定稿｜doc: v6.4-a2-variation-display.md 头部｜code: src/ChineseChess/Views/AnalysisView.swift 等三件 grep 亲证｜处置：销项；变招 UI 细节归④维 Vera
- **[已实现] v6.4-analysis-persistence-decision.md（v1.1）**：P0 决策选 C（sidecar {uuid}.analysis.json，可再生数据与用户棋谱分文件），A2 持久化已合主干；AnalysisPersistence.swift 在盘｜doc: 决策记录头部+待决点 1｜code: src/ChineseChess/Services/AnalysisPersistence.swift｜处置：销项；过期策略实现细节归⑤维 Cody 分片
- **[已实现] v6.0-strength-assessment.md（v1.0）**：棋力评估功能设计（Vera 审 0P0+2P1+4P2 全处理），AssessmentSession 在码（c4f50cd 修复链触及亲证）｜doc: 头部审查行｜code: c4f50cd（棋力评估 AssessmentSession 双写历史同修）｜处置：销项；Elo 估算/六维评估算法面归②维 Tina 片
- **[已消费] v6.0 系过程件**（phase-breakdown/test-plan/v3-pre-review-notes/v4-review-alex/v4-review-consolidated）：消费凭证=v6.0-phase1~6-test-report 六件全在盘（ls 亲证 6/6）｜处置：归类 5 销项
- **[文档过时/被 S2 取代] v6.2-difficulty-framework.md（v1.0）**：M1 窗口并行排期设计（参数区间化定标），其调度主体（自研参数轴框架）被 v65 v1.0 正式版 S2 锁表取代（"自研引擎参数轴全部退出梯度职能"）——与 v4.3 同款取代链｜doc: 头部核心原则；v65-weakening-chain-v3-draft.md §0.1｜code: —｜处置：销项（取代链正常演进）
- **[文档过时/P3·候选] user-guide/pikafish-setup.md macOS 12.0+ 口径**：现行最低系统=14.0（releases/中国象棋-v6.4.2.app/Contents/Info.plist L66 LSMinimumSystemVersion PlistBuddy 亲证）+PRD v2.1 适用平台 macOS 14.0+——指南口径滞后两代｜doc: user-guide/pikafish-setup.md 系统要求节｜code: Info.plist:66｜处置：登记候 P4 文档修批（改前 grep 引用，098 纪律）
- **[有效/单源活性] docs/test/skip-registry.md**：单源权威声明+run-tests-mutex.sh 自动消费+修复同 commit 更新纪律，与 DEVTEAM.md 测试铁律一致｜处置：销项
- **[文档过时/P2·候选] docs/general/test-rules.md**："统一入口 scripts/test-runner.sh，不直接调用 swift test"——现行铁律=run-tests-mutex.sh（2026-08-29 v6.3 H-1，flock 互斥+语言锁）+SPM 已废弃（swift test 已不存在）；与 DEVTEAM.md 构成真相源分裂面，误导风险高于普通漂移｜doc: test-rules.md 统一测试入口节 vs DEVTEAM.md 测试命令铁律节｜code: scripts/run-tests-mutex.sh 在盘｜处置：登记候 P3 文档修批（撤下或改指 run-tests-mutex.sh；改前 grep 引用，098 纪律）——本批唯一 P2 级登记

### 类 4 v2/v3 系分片并入（Eric 交，Alex 验收并入，2026-10-21）

- **分片结论**：9 件四态=已实现 2（tutorial-redesign v3.2 形态演进注记/ui-entry-points v1.1）/文档过时 6（difficulty-v2/ui-board-layout-optimization/ui-layout-polish/**ui-layout-redesign-v4**/ui-sidebar-redesign/ui-sidebar-v3-design）/部分 0/未实现 0
- **[文档过时/P3·方向性风险] ui-layout-redesign-v4.md（v4.2）**：其"选局/看棋分离、去 sidebar"原则与 v6.4 现行"共享 sidebar 基建+选择 View sidebar 化"架构**方向相反**且未标注被取代（commit a3f77b0/0c69846/5b492ad 反向演进）——为全矩阵唯一带误导风险发现：P4 实施者可能按 v4.2 原则把 sidebar 化当回归"修"掉｜doc: docs/design/ui-layout-redesign-v4.md L20-27｜code: commit a3f77b0/0c69846/5b492ad+Views/Layout/LayoutSpec.swift:10｜处置：**P3 文档修批显式标注 superseded（首优先）**
- **[归档批建议]** 本片 6 件过时+r3-07 日期笔误+oeu 日期纪律候选同批——P3 文档修批开"v2/v3-v4 系归档子批"一次清（各件头部加 superseded 指针）
- **D0/边界注记**：本片无 v3.9 发现项挂接；v5.6.1 缺口交集=零；puzzle-difficulty-rework.md 落地复查指针转交 v4/v5 系片（Cody）；auto-demo-design.md 归属候裁（本片 or v4/v5 片）

### 类 4 v4/v5 系+专项分片并入（Cody 交，2026-10-21；证据链底稿=t1023-dim1-shard-cody.md v1.0，本节为四态结论行集）

**分片结论**：14 件核验（含 v5.6.1 缺口交集与 v3.9 挂接），四态结论行 ~35 条——已实现/已修复 21｜部分实现 4｜仍开放 5｜文档过时/漂移/质量 7（日期违例 4 例合并）｜分析件口径 1；另覆盖缺口登记 8（件名未定位，见底稿 §九）。

**Eric 指针回销（上节 D0/边界注记两项）**：
- **[部分实现/证据受限·P1 交集] puzzle-difficulty-rework.md 落地复查（完成）**：FINAL-005 hints 0/551→**采样面 81/90 已填充**（puzzles.json v5，头描述"重新评估难度"；releases/ v6.4.2 产物 275,401B）｜FINAL-006 部分实现（代码子集 A=effectiveMaxMoves Puzzle.swift:120-139+子集 B=draw 守和 PuzzleViewModel.swift:253-266；容错公式 solution.count+2 与 doc ×1.5+3 有别=简化落地）｜FINAL-007+56 局 draw 数据面受单行 JSON 采样限制，列 P4 全量断言｜底稿 §二
- **auto-demo-design.md 归属建议**：归 v4/v5 片（本片已核验销项；演进链=auto-demo 建 PuzzleDemoView 双源→mge 并入大师棋谱→迁出 MasterGameBrowserView，PuzzleDemoView.swift:428-429 迁移注释亲证）

**高优发现行（P1 级）**：
- **[部分修复/P1] draw-detection P0-3 fingerprint 碰撞修复不对称**：Game 侧已换完整 FEN（GameViewModel.swift:813-817）vs Puzzle 侧仍 X-碰撞（PuzzleViewModel.swift:560-573，general→K/chariot→R/其余五种→"X"，注释"用于长将检测"）——draw-detection-analysis.md §2.3 自评"应在 P0 最优先修复（影响线上用户）"｜处置：P1 整改候选；已双通道移交②维 Tina（D2 交联）
- **[文档间冲突/已裁决·P1] 60 步规则阈值**：draw-detection-analysis.md 处方 100→120（中国象棋 60 步×2）vs PRD v1.1/实装=100 半着（GameViewModel.swift:801-804；v5.6.1 审计 FR-R 全✅ 口径）｜**裁决落定（丹妮 2026-10-21）**：采纳 doc 处方 120 半着（60 回合，象棋竞赛规则自然限着），PRD/实装 100 半着判 P1 规则合规整改项（整改落点 GameViewModel.swift:801-804）；Tina dim2 §六.1「50 回合判和」结论加更正脚注（参照源是 PRD 非外部权威）；规则语义最终呈洪涛确认——已入 D7 A 包
- **[仍开放/P2] v3.9 D1 P2-4 OpeningBook v1 兼容索引 FENParser 层依赖**：OpeningBook.swift:114-118 仍用 FENParser.parse（处方未采纳；防御性，v39 已判正常对局不触发）

**D0 翻转/销项行（v5.6.1 缺口交集）**：
- **[已实现·基线翻转] FINAL-009 分析性能优化**：v4.0-analysis-optimization.md 策略 B+C 全链落地——AnalysisViewModel.swift:47/:123/:179（isPlayerMove/策略 B 注释/循环跳过）+PositionAnalyzer.swift:248/:313（quickClassify 预筛）+:134 actor+:6 v6.4 @MainActor 并发修复——v5.6.1"未实施"作废；~72s 达标列 P4 实测
- **[已修复·逻辑面] FINAL-012#8 和棋检测**：三次重复判和+长将判负（GameViewModel.swift:766-796）+长捉判负超承诺（:780-788，v4.0 Phase 6）+fingerprint FEN 化（Game 侧）；测试面覆盖真伪移交②维
- **[已实现·采样面] FINAL-005 hints**（见 Eric 指针回销行）

**全行集指针**：其余 ~28 条四态行见底稿 §二-§七——已销项含：v3.9 D3 P0-2 开局探索器（pathFromRoot 现形）、v3.9 D4 P0-2 checkAfterPuzzle（PuzzleViewModel.swift:996-1001）、v3.9 D4 P1-2 占位模式（DailyChallengeView.swift:22-26/:44-48 单行文案）、v3.9 D1 P1-5 MoveOrderer（:133-134 makeSearchBoard 值副本）、v4.1 Phase2/3（GameViewModel.swift:987-995+BoardView.swift:25-30）、v4.0 三挑战模式、board-thread-safety-fix v3（BoardReadable 桥+LegacySearchBoard 值类型化）、ai-engine P0 beginnerMove/P1-a、ai-search 优化族（PVS/Razoring/NullMove/LMR/TT/AISearchConfig）、v5.0-opening-explorer-upgrade 全承诺（VE-1/2/4/8）；仍开放含：CoachModeOverlay 未集成（v3.9 P2-3，App 入口 852L 零引用）、Pikafish C API draw 信号（pikafish_api.h 零命中）、子力不足检测、engine-gap 三档立项件（待洪涛拍板，非缺陷）

**覆盖缺口（诚实登记，终裁权=矩阵 owner）→ 终裁落定（Alex 2026-10-21，详见下方 §九终裁节）**：v4.0-×4、v4.1-×2（含 oeu §1 提及的 Bug A/B/C 修复件）、bayeselo 系、coach 系件名未定位（20+ 名定点探测全失；无目录列举/全文检索工具）——详见底稿 §九

**D5 关联**：性能静态链官方产物已落 **docs/audits/t1023-dim5-perf-stability.md**（两栏口径：静态可证 6/需 P4 实测 5；Alex 主责面引用本矩阵 §四 D0⑤；v1.1 补扫=FINAL-013 翻转 pikafish_api.cpp TODO=0）

## §九 覆盖缺口终裁（Alex，2026-10-21）

- **v4.0-ai-difficulty-design.md**（AI 难度曲线改进 v1.1，v4.0 Phase 2）=**文档过时**：被 v2.2 锁数→v4.2 remap→S2 链逐代取代（同 difficulty 链口径）｜处置：P3 归档批标注 superseded
- **v4.0-architecture-assessment.md**（v4.0 架构评估，供 Luke 规划用）=**类 5 过程件销项**：消费凭证=v4.1-plan 前序引用链｜处置：销项
- **v4.0-perpetual-chase.md**（长捉判定方案，Luke 派单 Phase 6 #2）=**已实现销项**：交叉证据=Cody draw 域「长捉判负已随 v4.0 Phase 6 落地（GameViewModel.swift:780-788 detectPerpetualChase）」｜处置：销项
- **v4.1-opening-explorer-evaluation.md**（开局库综合评估，含 Bug A/B/C 修复）=**已实现销项**：交叉证据=oeu §4.4「Bug A 已在 v4.1 修复」+OpeningExplorerView pathFromRoot 现态（:326/:605）｜**日期违例第五例**（头部 2025-01-29）归 P4 修批统一包｜处置：销项
- **v4.1-phase7.2-swift-testing-filter.md**（Swift Testing Filter 调研）=**类 5 调研件销项**：消费凭证=测试基建演进链（test-runner→run-tests-mutex.sh H-1）｜处置：销项
- **bayeselo 系终裁**：2 件在盘（bayeselo-dual-layer-calibration-report.md+bayeselo-three-anchor-summary-template.md，docs/design/）——**T-1022 校准域归属**，本检查只登记在盘不对照（difficulty-v3 数据源引用链已在 difficulty-v3 件判定中覆盖）｜处置：登记，移交 T-1022 视域
- **coach 系终裁**：设计件定位=**docs/proposals/coach-explainer-enhancement.md**（proposals 目录，在 Cody design/ 探测面外）+教练执方门修复链 docs/plans/T-1021-OC-01｜**CoachModeOverlay 未集成（v3.9 D4 P2-3）维持仍开放**（ChineseChessApp.swift 852L 零引用）→P3 整改候选；coach 功能链细查归②维 Tina；独立 design 件缺位=设计债登记（P3 文档批）
- **引用卫生候选**：v4.0-×6/v4.1-×3 引用链中探测全失的件名（v4.0-plan/v4.1-opening-bugfix 等）=「引用存在但文件不存在」候选，P4 文档修批核对引用卫生时一并清｜**处置（⑤ 清偿 2026-10-27 Batch3-C）：销项**——全 docs 双模式复扫亲证：带 .md 后缀件名引用 8 种全实存（v4.1-plan×12/v4.0-analysis-optimization×11/v4.0-daily-challenge-modes×9 等）；无后缀死名（v4.0-plan/v4.1-opening-bugfix/v4.0-coach）audits 登记行外零命中——候选系探测猜测名非实引用，无清理面
- **代码定位缺口登记**（逻辑面已销项，定位注记归 P4 文档批，不影响结论）：DailyChallengeManager.swift/CommentaryEngine.swift（类型引用实证、文件路径未定位）/SearchBoard 类型定义文件（使用实证充分）
