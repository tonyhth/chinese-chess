# T-1101-1 v6.5 FP P3 三件批审查判词（Ruby）

> **主审**：Ruby（审查者）｜**日期**：2026-11-01
> **派单**：Cody coder:main 交下游（T-1101-1 v6.5 FP P3 三件批）
> **任务书**：docs/reviews/t1023-fp-anchor-vera-audit.md（§三路径A+§四 8约束）
> **对象**：工作树态 @ m1 528b3ab6（HEAD 未动，亲证），7 files +355/-7 + 4 untracked 判词件
> **纪律**：只读审查零 commit；依 2026-10-18 丹妮协议，判词落盘即完成，三方通知由 lead sweep 代行

---

## 一、变更清单独立核验 ✅（无漏报无多报）

- `git diff --stat` 与申报**逐行一致**：7 files, 355 insertions(+), 7 deletions(-)，文件名/增量全对账；算术自洽（各文件增量 marks 合计 362 = 355+7）
- untracked 4 件与申报一致（v65-b0-baseline / v65-bugfix-gui-leak-review-ruby / v65-bugfix-gui-leak-verify-tina / v65-implementation-status-assessment，全为 docs/reviews 判词件，非代码面）
- Phase2bTests.swift(+329) 在 diff 中且已正确申报为工作树态保留——与 7afdb2a 禁 commit 纪律一致

## 二、分件审查

### 件2 privacy（PositionAnalyzer.swift:154）✅
- diff 亲证：engineType/isReady 补 `privacy: .public`，单 hunk 纯注记，无逻辑变更
- 两值均为非敏感诊断值（引擎类型名+布尔），Release 可观测意图成立，无安全面
- 🟡 **P3-1 行内注记时点失真**：注释"工作树态随下批验证流转"与本批收口（本件入库）矛盾——commit 前顺手勘误为"已随 T-1101-1 批入库"，否则 HEAD 上代码自称"工作树态"会误导未来读者

### 件3① DrawDetectionRealTests coachConfig ✅
- GameViewModel.swift 亲证：applyMove 末尾 :373 `if coachConfig == nil { triggerAIMove() }`——coachConfig 在位即断引擎链，声称成立
- triggerAIMove :582、引擎切换 :598 `switchEngineIfNeeded`——申报 :598 实锤成立
- halfmoveClock 断言面在移动应用逻辑（先于 coach 门），断言语义不受影响
- 同套件 testThreeRepetition_RealDriven 等既有同款 coachConfig 模式——本用例是补齐遗漏而非引入新模式

### 件3② GameRecordStore seam（披露偏离——重点审查）✅ **偏离裁定：可接受**

五点裁定依据（全部亲证）：
1. **Release 编译路径恒等**：#if DEBUG 编译剔除后 `shared ≡ GameRecordStore()`，与原 `static let shared = GameRecordStore()` 同义，release 产物零变化
2. **init(baseURL:) 为既有文档化测试初始化器**（:117 注释"测试用初始化器（指定 baseURL，避免污染真实数据）"），非新增 API 面
3. **tests-only 替代不存在**：shared 为 static let 不可注入；挂起点在生产单例 init（reconcileOrphanFiles → ~/Documents TCC 目录枚举）；调用链经生产代码（applyMove→recordGameResult）进入，测试侧无拦截点——缝是最小 release-safe 路径，偏离成立且必要
4. **双重门安全**：#if DEBUG ∧ env 在位才重定向；默认行为（含未设 env 的 debug 构建）零变化；env 值为开发者自有可控的文件系统路径，无生产暴露面、无注入面
5. **生产直构造点唯一**（:88 closure 内），grep 亲证无其他 .shared 旁路

缝语义亲证：init(baseURL:) 仍跑 reconcileOrphanFiles，但重定向至 /tmp（非 TCC 域）+ createDirectory(intermediate) 自建——机理自洽。TCC 根因链（sample 1362/1362 __open、detached ls rc=124 vs /tmp 秒回）与已知 macOS TCC responsible-process 行为一致，采信。

- 🟡 **P3-2 缝是 opt-in**：run-tests-mutex.sh 未默认注入 TEST_RUNNER_GAMERECORDSTORE_BASEURL（:87 有 TEST_RUNNER_ 双通道注入先例）——未带 env 的 agent-session 批次跑任何触碰 .shared 的套件仍会挂（风险面不止 DrawDetectionRealTests）。建议 runner 默认注入 per-run /tmp fakehome，让免疫覆盖全测试面
- 注：脚本 :99 注释"TEST_RUNNER_/环境变量注入不生效"系 UserDefaults 特例（不读 env），GameRecordStore 直读 ProcessInfo.environment，TEST_RUNNER_ 前缀穿透有效，两者不冲突

### 件1 探针套件（Phase2bTests.swift +329，工作树态保留）✅ 同意不入库

- @Suite Swift Testing struct 亲证；**mirrorScore 三项代数侧向正确**：邻近项用走子方己将（generalPosition(of: move.piece.side)）、阻挡按对手攻击子线（车 between0 +60 / 炮 between1 +30）——与 Vera §一代数逐项一致，镜像失真风险排除
- **约束6 迭代协议合规**：dump ①应将清单 ②moveScore 三项分拆 ③新旧双判定（:329 注记+实现齐）
- **约束2 合规**：捕炮线按约束2 删除（迭代1 注记明示）
- B3 硬上限亲证：scanned ≥ 30000 break（:542）+ stride 5 采样（:543）——机时有界
- B3 越界崩溃已修（:514 注记：池去重后 15，原 0..<16 越 extras[15]）——verify7 崩溃实证侧面印证探针确在批内实跑过
- 🟡 **P3-3 探针无门禁**：@Suite 常驻套件，工作树态下任何含 Phase2bTests 的批次都会拖 ≥30min（B3 实测 57min 未完）。建议 Swift Testing `.enabled(if:)` env 门禁（如 FP_ANCHOR_PROBE=1），或批 filter 显式排除至冻结裁定
- **给 Luke 裁定输入（非本审裁量）**：若"单 punish 结构内四断言互斥"机理证明成立（造响应子=防守子 → 应将≥9 需富军 ∧ 诱饵全败需贫军，互斥），则 B3 万级挖掘在**同一结构约束下预期仍 0 命中**——挖掘放量只在两条路上有意义：放宽"单一 punish"约束（v2 预算爆炸教训，慎）或调整锚口径（窗口/判定语义）。万级隔夜挖掘前先裁决结构约束是否解除，否则是算力空转

### 件4 收口裁定 ✅ 同意

- 入库 6 文件清单与 diff 对账一致（7 减工作树态 Phase2bTests）
- 版本 bump 双侧一致 6.4.3→6.5.0（iOS 侧引号风格沿用原状，无漂移）
- **build-release.sh universal ARCHS 非纸面变更**：releases/中国象棋-v6.5.0.app（10-30 16:22）lipo 亲证 x86_64+arm64 双片 ✅
- **universal 连带风险排除**：EmbeddedPikafishEngine 经 modulemap 进程内 C API（`import Pikafish`），无子进程二进制架构错配面；NNUE 为数据文件无架构属性 ✅
- 4 untracked 判词件随批入库沿 B2 528b3ab6 先例——非代码面，无异议
- 🟡 **P3-4 申报口径勘误**：三扫变体总数 6+336+5544=**5886**，申报写 5586（差 300，不影响 0 命中结论，口径随批勘误）

## 三、独立复跑

- RUNNER_OWNER=ruby 复跑 DrawDetectionRealTests（TEST_RUNNER_GAMERECORDSTORE_BASEURL=/tmp/ruby-verify-t1101/Documents/GameRecords，nohup 脱离）已起跑，因全局互斥锁（~/DevTeam/.locks/xcode-tests.lock flock）被在途 FPAnchorProbeTests 批（timeout 1800 封顶）持有而排队
- Cody verify7 结果（testPerpetualCheck_RealDriven 0.041s / 14/14 绿）为申报证据；本审以静态全链亲证（缝语义+coach 门+构造点唯一性）作为通过依据，复跑结果若在判词后到账由 lead sweep 附转

## 四、结论

**代码面通过，同意收口：6 文件入库 + Phase2bTests.swift 工作树保留 + 4 判词件随批。无方案级问题。**

- 件3② 披露偏离裁定：**可接受**——Release 恒等 + 既有测试缝 + 无 tests-only 替代，属最小 release-safe 路径；附带条件为 P3-2（runner 默认注入，登记后续）
- P3×4 随批处理：P3-1 注记勘误（commit 前顺手）；P3-2/P3-3 登记后续批；P3-4 申报口径勘误
- 件1 冻结与挖掘放量归 Luke 裁（§二裁定输入：结构约束先裁决，再决定挖不挖）

*主审 Ruby｜2026-11-01｜只审不落码零 commit｜通知由 lead sweep 代行（2026-10-18 丹妮协议）*
