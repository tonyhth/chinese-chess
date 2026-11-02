# T-1102-1 判别锚路线二实施批审查判词（Ruby）

> **主审**：Ruby（审查者）｜**日期**：2026-11-02
> **派单**：Cody coder:main 交下游（T-1102-1 判别锚路线二实施批——判定循环语义钉；DDL 11-03 18:00）
> **权威 spec**：docs/reviews/T-1101-5-anchor-verdict-vera.md §3.2（Vera 裁定单，实施口径）
> **对象**：工作树态 @ m1 52d3a62d（HEAD 未动亲证）；批面 = src/ChineseChess/AI/CheckmateSearch.swift（39±，缝）+ docs/reviews/t1023-fp-anchor-vera-audit.md（+2 rider）+ 2 untracked（src/ChineseChessTests/CheckmateLoopSemanticsTests.swift 新件、docs/reviews/T-1101-5-anchor-verdict-vera.md 裁定单）；Phase2bTests.swift +344 为探针工作树态非批面（申报正确）
> **纪律**：只读审查零 commit；依 2026-10-18 丹妮协议，判词落盘即完成，三方通知由 lead sweep 代行

---

## 一、变更清单独立核验 ✅（无漏报无多报）

- `git diff --stat` 亲证：3 files +384/-1；批面两文件与申报一致（CheckmateSearch 39、t1023 rider +2），Phase2bTests +344 已正确申报为探针工作树态非批面
- untracked 2 件与申报一致（新测试件 + 裁定单）；HEAD=52d3a62d 亲证

## 二、缝 Release 恒等五点叙事逐点核验

1. **Release 编译恒等 ✅**（构造性：#if DEBUG 剔除后响应校验循环体=原 if-dfs 语句；Release 构建实证 /tmp/t1102-release-build.log `** BUILD SUCCEEDED **`）——🟡 P3-1："逐字节保留"表述失准：#else 分支与原语句差一个缩进空格（diff 亲证：`path:` 续行 25→24 空格；语义恒等无损，构造性保证成立）
2. **tests-only 替代不存在 ✅**：dfs 递归判定结果无其他 test-side 注入通道；分歧见证局面作曲被 T-1101-5 裁①封死（单 punish 域互斥+五扫 0 命中）
3. **最小路径 ✅**：grep 亲证 src/ 内仅 :21 声明 + :103 消费，一个 static var + 循环内 if-let 分流，零生产 API 面
4. **DEBUG 门禁默认零变化 ✅**：代码亲读——oracle nil 走 else=原 dfs 调用；responseIndex 死增量无副作用
5. **生产消费点唯一 ✅**：grep 亲证（:103 唯一消费位）

## 三、适配偏离裁定：**可接受**

- **实证基础真实**：首跑失败日志亲读（/tmp/t1102-loopsem-2.log + 归档件）：`result=[R1(3,3)→(0,3) 捕士]≠nil`、`oracleCalls=2`——纯调用计数下次序依赖实锤（非锚线 R1xa2+ 的 2 次调用全落前窗口即翻 mate），与派单叙事逐字一致
- **裁定意图保持**：四断言全绿（run3+Ruby 复跑双证）+ 次序免疫（checkMove 判别键）+ 真值对齐（非锚线恒黑活，与既有行为契约 search==nil 互洽——被 Phase2bTests 行为契约钉旁证）
- **向下兼容**：纯调用计数=适配后 oracle 忽略 checkMove 的特例，原口径仍可表达
- **回流通道在位**：缝头注释+测试注释均注记（引裁定单 §六实施异议回流）
- **迭代链完整可溯**：run1 编译错（static 声明位错）→修复→ run2 语义失败（首跑实证，08:56）→08:59 适配编辑→ run3 绿（08:59:59）

## 四、测试件审查（CheckmateLoopSemanticsTests.swift）

- **夹具同源 ✅**：与 Phase2bTests:85 nineResponsesFullValidationContract 逐子一致（红帅(9,3)/红车(3,3)/黑将(0,4)/士×2/马×2/相×2/黑车×2），零作曲——裁定 §3.2 硬要求
- **验收四条对齐 ✅**：④漂移门（MoveValidator 机核应将 ≥9，:81 模式）／①search==nil／②oracle 调用 ≥9／③prefix(8) 克隆对照（spec 明示可选、文档级、不承担生产门禁）
- **defer 清纪律 ✅**（:79 用毕置 nil 防跨用例泄漏）
- 🟡 **P3-2**：测试注释②"截断回潮时 ≤8 必红"在多将军线夹具下**不成立**——非锚线先行序下截断回潮调用数=1+8=9 ≥9，②不红；②的判别力依赖将军线生成序，**①（search==nil）才是序免疫实门**。注释应勘误，防未来维护者误信②为截断探测器
- 🟡 **P3-3**：③克隆对照为不可失败的同义反复（`oracleSemantics(callCount≤8)` 喂调用 1-8 恒真）——spec 定位即文档级可选，合规；作为可执行断言永不红，建议注明「演示性断言」或简化
- 🟡 **P3-5**：夹具复制而非引用（Phase2bTests 工作树态禁 commit 无法引用）：双份 11 子摆位独立漂移风险由④漂移门兜底；Phase2bTests 未来入库时建议抽公共夹具助手

## 五、动态验证（双重亲证）

- Cody run3（/tmp/t1102-loopsem-3.log，08:59:59）：`** TEST SUCCEEDED **`，1 test 0.007s——与派单申报一致；run3 晚于两源文件 mtime（08:59）= 当前工作树态所跑
- **Ruby 独立复跑**（RUNNER_OWNER=ruby，2026-11-02 09:16，runner 通道同参）：rc=0，`** TEST SUCCEEDED **`，1 test 0.007s——亲证绿 ✅

## 六、rider 与顺延项

- t1023 supersede 注记 ✅（+2 行，lead 代行授权，与裁定 §四资产处置表一致）
- nineResponses 名实注记顺延 ✅（裁定 §3.3「随触碰」条件成立——本批未 commit Phase2bTests；**登记不销账**，Phase2bTests 入库批必须落注）
- 🟡 **P3-4**：证据路径申报失准——派单引 `~/DevTeam/evidence/t1102-1-cody/first-run-order-proof.log`（子目录不存在），实为 `~/DevTeam/evidence/t1102-1-cody-first-run-order-proof.log`（平铺名）；绿跑日志 loopsem-3 仅在 /tmp 未归档——建议随批归档防 /tmp 易失
- 🟡 **P3-6（观察）**：全局 static oracle 与 Swift Testing 跨套件并行的理论干扰窗口（~7ms）——现行 runner 每 suite 独立 xcodebuild 进程 + 套件内 .serialized 已容纳；全量并行跑批场景登记备忘

## 七、结论

**代码面通过，同意收口：CheckmateSearch.swift 缝 + t1023 rider 入库；CheckmateLoopSemanticsTests.swift 新件 + T-1101-5 裁定单随批入库（沿 B2 528b3ab6 先例 add -f）；Phase2bTests.swift 维持工作树态禁 commit。无方案级问题。**

- 缝五点叙事全部成立（P3-1 仅"逐字节"措辞勘误，构造性恒等无损）
- 适配偏离裁定：**可接受**（实证真实+意图保持+向下兼容+回流通道在位）
- 动态验证双绿（run3 + Ruby 独立复跑亲证）
- P3×6：P3-1/P3-2/P3-4 随批顺手勘误；P3-3/P3-5/P3-6 登记后续
- 下游：链 Tina 验证（runner 通道）——派单指定

*主审 Ruby｜2026-11-02｜只审不落码零 commit｜通知由 lead sweep 代行（2026-10-18 丹妮协议）*
