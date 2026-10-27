# T-1023-OC-01·P2·D5 — 性能与稳定性静态链（⑤维报告 v1.2·FINAL-013 补扫+双写 sweep 定谳）

> 主责：Alex（0.5 人日：D0⑤ 三项核销+衍生核验项+本文件统稿）｜协作：Cody（0.5 人日：v39-d1 性能链遗留关联核销+known-issues 性能/稳定类静态走查，2026-10-21 交付）
> 依据：docs/plans/T-1023-OC-01-inspection-plan.md v1.1 §四⑤（两栏口径，裁示④批准：结论分"静态可证/需 P4 实测确认"）+§六 D5 行
> 边界：T-1022 校准域只引用产物为证据源，不开新单不下结论；不跑 benchmark；P4 实测衔接 T-1022 产物引用
> 格式：两栏口径——【静态可证】/【需 P4 实测确认】

---

## 一、Alex 主责面（D0⑤，引用不重做）

三项核销见 t1023-dim1-doc-compliance.md §四"D0⑤ v3.9 性能链三项核销"：QS 全量走法生成【已修复·销项】、wouldBeInCheck 深拷贝【已修复·LegacySearchBoard 形态·残余成本列 P4 观察项】、medium QS 缺位处方【文档过时·处方被取代；衍生项"现行 mediumNoQS 下 medium→hard 梯度"挂 T-1022 边界列 P4】。双写历史同根因 sweep 待办（矩阵 v6.3 锚件②衍生）归本维候办池。

## 二、【静态可证】（Cody 协作面，2026-10-21 定谳，全部带文件:行锚）

- **1. KI-2026-0829 业余档时延违约（v6.4 立案 P1）——根因面已修复**｜KI 面: known-issues.md（初判根因 Cody：TimeManager 仅迭代加深层间检查，单迭代内无 deadline 截断；pfcal lvl4 max 13.5s>8s 帽、lvl5 max 45.4s=预算 5.7×）｜code 面: AIEngine.swift:898 `nodeCount & (timeCheckInterval - 1) == 0` → tm.shouldStop（搜索内 node 级时间检查）+:37 粒度权衡注释（"64 粒度最坏 ≈140ms，shouldStop 开销 <0.1%"）+:220/:392/:485/:620/:661 多层检查点；TimeManager.swift:28-33（shouldStop=elapsedMs>=timeLimitMs，systemUptime 口径休眠不计入）｜定性: 单迭代内截断已实装，KI 初判根因消除
- **2. EmbeddedPikafishEngine.newGame dispatch_sync 死锁 KI（2026-08-15，active·存量）——dispatch_sync 已消失**｜KI 面: known-issues.md（EngineRouter.newGame→EPE.newGame dispatch_sync 跨队列等待 ownership；修复方向=dispatch_sync→async/超时保护）｜code 面: EmbeddedPikafishEngine.swift（599L）全文件 dispatch_sync 零命中；现态=async/Sendable 体（:76-77 @Sendable async 入口、:315/:317/:447-449/:501-503 cApiQueue.async 串行队列、:230 async shutdown+:256 防御性兜底注释）｜定性: 已按 KI 处方方向重构；条目销账归条目 owner
- **3. PositionAnalyzer actor 化（v3.9 §五"复盘并行分析需重构 actor"建议面）**｜code 面: PositionAnalyzer.swift:134 actor（"线程安全"）+:397 "共享同一引擎实例，通过 actor 串行化保证安全"｜定性: 线程安全化落地（串行形态）；真并行化列 P3 改进候选
- **4. AI 搜索路径零 @Observable Board（board-thread-safety-fix v3 落地）**｜code 面: BoardReadable.swift（AI/，17L）+MoveOrderer.swift:85/:133-134（order<T: BoardReadable>+makeSearchBoard 值副本）+AIEngine.swift:351/:581（inout LegacySearchBoard）+TimeManager positionComplexity<T: BoardReadable>｜定性: 值类型化落地；命名演进 SearchBoard→LegacySearchBoard 登记 P4 文档修批
- **5. v6.4 并发修复在案**｜code 面: AnalysisViewModel.swift:6（"v6.4 P1 并发修复：标 @MainActor"）｜定性: 已知-已修
- **6. 复盘分析静默 nil 长期建议（active）**｜KI 面: known-issues.md（6.3.1 已修三处；长期建议=C 层错误码 r=-1 未上抛 UI）｜定性: 修复面已落（FingerprintReplayPipelineTests 转正）；错误码上抛 open——P3 候选（与 draw 信号 API 同属 C API 健壮性包）

## 三、【仍开放/交联登记】（非本文件下结论，移交对应主责）

- **AI 飞将走法 bug**（KI 2026-07-30，active·未修复）：搜索层未过滤飞将→②维 Tina（D2 交联）
- **C 层 g_engine 并发 TODO（FINAL-013）→ 补扫定谳（Alex 主责面，2026-10-21）**：pikafish_api.cpp 已定位 ChineseChess-iOS/Pikafish/src/（561L），**TODO 计数=0**（grep 亲证）；g_engine 为标准全局指针形态在用（:41 定义/:99 判空/:146 构造/:149-195 回调挂接）——v5.6.1 基线"有 TODO"主张在现文件不可复现，FINAL-013 翻转为"登记撤销候选"（运行时验证面如需仍列 P4）；登记撤销归 known-issues 条目 owner
- **CheckmateSearch maxResponses=8 假阳性 residual**（v3.9 D1 P1-6）——②维/P3
- **搜索内重复检测缺失+SEE 缺失+MoveOrderer historyTable String 键**（engine-gap-analysis-elephanteye.md §3.1 现势仍准，MoveOrderer.swift:14-17 亲证）：立项件待洪涛拍板——非缺陷登记

## 四、【需 P4 实测确认】（右栏汇总）

1. 分析性能 ~72s 目标（FINAL-009 策略 B+C 实测）
2. KI-2026-0829：AIEngineTimingContractTests 回绿（skip-registry 在案）+ lvl4/lvl5 pfcal 复测
3. dispatch_sync 死锁 KI：全量套件回归通过性
4. puzzles.json 全量统计断言（hints 覆盖率/draw 计数/freePlay 局数——dim1 矩阵 Cody 分片节移交，单行 JSON 采样局限）
5. arm64 适配面（r3-07 R3-18 口径，矩阵已登记）

---

## 四.5、双写历史同根因 sweep 定谳（候办池项闭合，Alex 2026-10-21）

- **机制确认**：根因在消费侧双输入——analyzeMoveLite/analyzeMove 形态为 engine.evaluate(fen: fenBefore, moveHistory: moveHistory)，fenBefore 已烘焙历史时再传全量 history=C 层双应用静默 nil（PositionAnalyzer.swift:398 起亲读）
- **消费方全枚举 4 处，静态面无残留**：AnalysisViewModel ×2（fenList 烘焙+空历史，v6.3.1 修，:188/:301）、AssessmentSession ×1（c4f50cd 修，:99）、MasterGameCommentator.analyzeStep ×1（唯一调用方 DemoViewModel.swift:294 实证 moveHistory: [] 空传+注释明引同根因「v6.3.1 同修：fenList[idx] 已烘焙历史，双传 moveHistory 会致 C 层双应用静默 nil」）——**第 5 处候选排除**
- **生产侧 append 点 10 处均合法单写**：Board.swift:125 母体/LegacySearchBoard.swift:76 值类型设计内/SelfPlayRunner ×5（工具链离线批，非用户面）/CMAESOptimizer.swift:250（generation 统计非同族）
- **遗留注记 1 条（P4 接口卫生候选，非缺陷）**：MasterGameCommentator.analyzeStep 签名仍保留 moveHistory 参数（现调用方传 []；API 形态留有未来双传误用空间）——可选收敛：默认参数化或删参
- ｜处置：候办池项闭合；D 包实测清单不变

## 五、证据局限声明

无目录列举/全文检索工具（文件发现走引用链+定点探测）；所有"零命中"注明扫描文件与行数边界；未跑任何构建/测试/基准（P1-P3 硬约束全程遵守）。