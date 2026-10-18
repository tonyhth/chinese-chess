# T-1019-OC-01 快审 Vera 审查单（Ruby 全审 P3×6 消解统计面复核）

> **审查人**：Vera（inspector）｜**日期**：2026-10-18
> **对象**：m1 双 commit——b691618（fix(stats) P3×6 消解+v6.4.1 版本定版；=派单引 b34abdd 同树+project.yml 定版）+240d86d（memo N6 引用卫生；=派单引 abc7c29 同树）。累计 GameRecordStatsAggregator 621L/测试 503L
> **规格锚**：Ruby 全审 P3 清单（T-1017-OC-01-R-review-ruby.md，**在盘勘误后已直读**：DevTeam 根级 /Users/hth/DevTeam/docs/reviews/，7093B@10-17 23:17——§八 P3×6 原文与本审六项逐一吻合，忠实性升格 primary-source 确认，见 N1）+ Luke 双域统计口径（harness 卡 7328c9fc）
> **锚链勘误（2026-10-18，Cody 事实纠正+我方亲验）**：本审锚定中间链 b691618/240d86d（当时 HEAD 实况，现已弃）——现权威链 3686c47→b34abdd→abc7c29→8f9df43→3bf5307→6117e59。亲验：git diff 240d86d 8f9df43 空（审定码面逐位一致）+聚合器/T1017 测试面 8f9df43→6117e59 零触碰（后随仅 L10n/manifest/他测试文件钉点）——**判词以码面内容锚结转有效**，hash 引用以本注为准
> **取证基线**：git diff/show（75f06e0→b691618 增量 + 双 commit 树同一性 + 生产零触碰空 diff）+ 聚合器/测试增量 diff 全读 + 测试 log 双份直读（logs/t1018-oc01-p3-tests2-1018.log、t1019-oc01-tests-1018.log，内层 "Test run with 23 tests in 1 suite passed" ×2 直读）+ HEAD=240d86d=m1 工作树一致

---

## 判词：**通过**（非阻塞 4 项登记随下触）

P3×6 六项实现全部忠实 Ruby 原意（以派单三问枚举承证）；schemaVersion 1→2 契约变更规范；时长门控与 §五.7 触发线语义自洽。通过→随 Luke 线推进。

## 快审三问裁定

### ① P3×6 实现忠实性 ✓（六项逐一对读）

| 项 | 实现核验 | 测试锚 |
|---|---|---|
| P3-1 zeroMoves 双条件分流 | ✓ 双域（产品+校准）同构：totalMoves>0&&moves.isEmpty→moveCountMismatch（"记录损坏形态，完整性受损剔除统计"）；==0→zeroMoves（裁定③原文）。均剔除统计；enum 注释明示 moveCountMismatch 双语义（观测面仍计入 vs 损坏变体剔统计） | corruptRecordSplitToMismatchSemantics（mismatch 在场+zeroMoves 不在场+counted==1） |
| P3-2 时长门控 .playing | ✓ .playing→durationExcludedUnfinished++ 后 continue（先于倒序检查，无伪告警）；截断时长系统偏短不进样本；胜率面剔除逻辑不变 | unfinishedDurationGatedWithDisclosure（510s 剔/630s 样本/计数=1/胜率面 excludedUnfinishedCount=1） |
| P3-3 导出原子覆盖 | ✓ 存在性循环追加 -N 后缀再 .atomic 写——同秒双导出零覆盖 | exportFilenameCollisionAvoided（同 fixedDate 双导出 url 异+双存在） |
| P3-4 测试边界 | ✓ 四项全补：==20 入主判据钉死／clamp 双界（0→1、999_999→10_000）／freePlay·puzzle 披露理由锚（"非 versusAI"/"残局练习"字面断言）／novice 缺席 nil 链（byDifficultyNovice nil→noviceWinRate nil→Triggered nil，且 moveP50Triggered 独立生效 30<40=true） | boundaryAtThresholdGoesPrimary/configThresholdClampedBothBounds/otherSourcesReasonsAnchored/noviceAbsentNilChain |
| P3-5 documentsDirectory 防御+AlertReason enum 化 | ✓ first! 强解包撤除（Documents 不可得退临时目录）；namespace 常量→String raw enum Codable——**JSON 载荷零变更**（rawValue 串与旧常量同字面，导出 schema 兼容） | （随全套件编译+23 过承载） |
| P3-6 0s 告警+Config 上界 | ✓ 全手同时戳 0s→zeroDurationObserved 观测告警、样本仍计入；阈值 clamp 1...10_000（下界防零负/上界防全量打进异常列） | zeroDurationObservationalAlert（0s 样本计入+告警在场）/configThresholdClampedBothBounds |

### ② schemaVersion 1→2 契约变更 ✓（附一条消费面注记）

变更面=ProductReport 加法字段 durationExcludedUnfinishedCount: Int（P3-2 披露载体）+AlertReason String→typed enum（**JSON 载荷不变**，rawValue 同字面——IntegrityAlert.reason 编码无漂移）。v2 导出件自解码/往返等值（roundtrip 断言已随 ==2 更新）。**v1 导出件消费行为=v2 结构体解码 fail-fast**（keyNotFound durationExcludedUnfinishedCount，无 decodeIfPresent 兜底）——现产品无 v1 再摄取通道（导出为终态文件），schemaVersion 字段可门控，fail-fast 语义可接受；未来消费面若需读 v1 件，补 decodeIfPresent(default 0) 或 v1 专属结构体（见非阻塞 N2）。

### ③ 时长门控统计语义 vs §五.7 ✓ 自洽

§五.7 触发线锚**人均对局步数 P50<40**——moveStats 口径本批未动（裁定②产品域全计，.playing 仍计入步数样本），触发线定义不受时长门控影响。时长 P50 样本集=已终局+非损坏+时序有效（截断偏短防御），样本集与步数样本集**有意分叉且双侧披露**（duration.sampleCount + durationExcludedUnfinishedCount + durationInvalidCount）。胜率面（excludedUnfinishedCount）不变。无指标互斥、无静默样本漂移——自洽。

## 生产零触碰与树同一性实证

- 75f06e0→b691618 diff 在 EngineRouter/Enums/Engine 面**空输出** ✓；b691618 另含 project.yml MARKETING/CURRENT_VERSION 6.4.0→6.4.1（版本定版，commit 标题已披露；build config 面不在生产代码枚举内，如实记录）
- 派单引 b34abdd/abc7c29 与盘面 b691618/240d86d 树差=仅 project.yml 定版 4 行（标题 T-1018→T-1019 更名随定版）——内容同源，审面以盘面 HEAD 链为准
- 23/23 直读："Test run with 23 tests in 1 suite passed" ×2（两 run 均过，mutex H-1 runner rc=0）；HEAD=240d86d=m1，工作树净

## 非阻塞登记（随下触，4 项）

- **N1**（已勘误 2026-10-18，Cody 事实纠正+我方直读亲验）~~Ruby 判词文件不在盘~~——文件在盘：/Users/hth/DevTeam/docs/reviews/T-1017-OC-01-R-review-ruby.md（7093B@10-17 23:17），我方初检系项目级 docs/reviews/ scope 未及根级。已直读对读：Ruby §八 P3×6 原文与本审六项逐一吻合（P3-1 文案分流/P3-2 时长门控/P3-3 碰撞/P3-4 四缺口/P3-5 防御+enum/P3-6 0s+上界）；另 Ruby 本审独立结论=通过（P0-P2 零/P3×6 同项/四裁量无异议不提级）——两线独立同判收敛互证。是否落项目级副本归链主裁
- **N2** v1 导出件 v2 解码 fail-fast（见三问②）——未来消费面需读 v1 时补 decodeIfPresent(default 0) 或 v1 结构体。
- **N3** excludedZeroMoveCount 字段语义外扩（现兼计损坏变体剔除，非严格"零步"计数）——enum/测试注释已披露，结构体字段宜补一行 doc comment 防消费面误读。
- **N4** 我方原 P3×6（T-1017-OC-01 降级留档单）存量对账：②校准域防御对等、④漏测 2 项**已由本批关闭** ✓；①q4 口径 a 来源披露、③source↔summary 一致性抽验、⑥rawValue 格式耦合**未见本批**（不在 Ruby 六项内）——维持登记随下触。

## 交付记录

- 快审判词完整件→Cody（sessions_send agent:coder:main）＋群消息完整件；摘要→Luke＋群消息摘要件
- （runId/om id 见 CURRENT_TASK.md 本任务条目）
