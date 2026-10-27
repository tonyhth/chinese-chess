# T-1023-OC-01·P4·Batch 2 审查判词（Ruby）

> 审查人：Ruby（reviewer）| 日期：2026-10-22 | 对象：daec845 基座上六 commit 694a68a/496d67a/cf37777/9754a84/9553917/a0dbbcb
> 验收链：编码→**Ruby**→Tina→门禁→tag | 底稿：docs/design/t1023-remediation-plan.md §四+§十三
> 审查方式：全程只读（git show/diff + 定点读码 + log 实读），未跑测试批、未改码

## 一、真实性验证与变更清单核对

- 六 commit 链与申报一致（694a68a→496d67a→cf37777→9754a84→9553917→a0dbbcb），基座 daec845 正确；tracked 树净 ✅
- 汇总 19 files +126/-49 与申报吻合；per-commit 分账核对：隔离 +13（1 file）/docs 3 files +39/-15/A2 1 file +26/-4/B10 1 file +7/-1/B9 1 file -2/B6 12 files +41/-27
- ⚠️ **P3-1 清单误差（登记）**：B6 申报"27 数值站点（**15 文件**）"，a0dbbcb 实际 **12 files**（站点数 27 与 -27 行吻合，文件数不符）。内容面无损（12 文件全数定点验过），属申报口径误差非代码缺陷；同周 MY§7.5 引证教训同类——数字申报以 git stat 为准。随件更正记录，不阻断
- B-新 附录核验：dark-mode-policy.md L20「附录：F4 语义色 27 处降级登记」在盘，四要素齐备（处置裁定/复现命令/分布表 27 处逐文件/色族归纳+耦合提醒）✅

## 二、逐项审面

### 首项 694a68a 测试隔离（丹妮裁准方案 a）✅
- 实现：读原值 chinesechess.humanSide → 显式 set "red" → defer 还原（原值存在则回写、不存在则 removeObject——不注入原本没有的键，语义精确）
- KI 锚接：注释直指 known-issues 登记项；效应已双向实证——Tina Batch 1 验收凭此前置跑通（五件全 PASS），isofix log :534 转绿（0.043s，原失败点）6/6 RC=0

### cf37777 A2 UIScreen.main→GeometryReader（=D3 P1-5 闭环）✅
- 方案：ContainerHeightKey(PreferenceKey, max-reduce) + ContainerHeightReader(GR+Color.clear) 后台实测；bottomAreaMaxHeight 改读 containerHeight
- 语义保持声明核实：iPad 15%/其余 20% 比例不变；**667 档阈值由屏高改对容器高度生效**——声明式行为偏移（容器高<屏高，部分高屏设备将落入 25% 档），方向更正确（预算对实际空间），Tina iOS 验收视觉确认点
- 首帧兜底 180 与 macOS 分支 180 一致；`#if os(iOS)` 门控下 iOS 分支 macOS 工具链不可编译证——Cody 已注记候 iOS 门禁（正当，门禁覆盖）
- 残查：UIScreen.main 全 src **零活代码残留**（仅 2 处注释记述）

### 9754a84 B10 OpeningBook v1 索引解耦 ✅
- `private static let v1BasePieces`（Swift lazy init 线程安全）单次解析常量基盘 FEN；各 variation 经 Board(pieces:) 派生独立工作副本——原每 variation 重复 parse 同一常量消除
- 行为零变化成立：parse 纯函数同输入同结果，仅缓存化；Board 引用类型语义经副本隔离保持

### 9553917 B9 悬置 TODO 移除 ✅
- 纯注释移除（-2），零行为。职能裁定（残局文案属 Puzzle 域 UI 层，集成前置未发生，职能随集成重建）已记 commit message，Product 决策可追溯

### a0dbbcb B6 LayoutSpec 字阶 10 token ✅（内容面）
- LayoutSpec.swift +14：Nano7/Micro8/Footnote9/Small10/Medium11/BodyLarge14/Display32/DisplayLarge40/Hero48/HeroMax56，与申报枚举一致；收编口径注释在案（cellSize 相对过程值不收编=F1 口径；F5 Dynamic Type 可选未启用）
- 零视觉变化抽验：AnalysisView/MasterGameBrowserView 站点逐一比对——48→Hero/9→Footnote/14→BodyLarge/8→Micro/40→DisplayLarge×6，字面值与 token 定义全等 ✅
- 清单误差见 §一 P3-1（文件数 15→12）

### 496d67a docs（B1/B2/B3）✅
- B1：test-rules.md 改指 run-tests-mutex 现行真相源（31 行重构）——消除双源，与 DEVTEAM.md 2026-08-29 规约对齐
- B2：release-notes 补 v6.4.0/v6.4.1/v6.4.2 三条目（对照 ledger 115-119+tag 链无误）
- B3：build-release.sh +3 tmp.* 排除（BOM 临时文件不入发布包，`|| true` 容错）

## 三、测试与构建证据核验（log 实读）

- t1023p4-b2-build/-build2 双 log 各含 BUILD SUCCEEDED；build2 内 error 零命中（命中的 Swift 6 actor-isolation 条目为**警告**级且属 ReplayWindowShell/AnalysisViewModel——均非本批 19 文件，存量）
- t1023p4-b2-isofix-1022.log：6 tests 2 suites 全 passed，"走棋 + 悔棋 回归" passed 0.043s（转绿实证）✅
- A2 iOS 分支与测试批主体候 Tina/iOS 门禁——验收链分工正确，本审查不越位

## 四、B11-18 枚举结论核对 ✅

与 D3 报告处置逐条对得上：dim3 P2-2（评估曲线）=v6.4 B1 定案部分处理不立案、P2-3（主题预览）=已修复、P2-7→P4 实机待证——"已闭/候实机"口径与我的三态标注一致；dim2/dim7/dim8 交叉项路由合理。零新增编码项结论**维持**。

## 五、发现清单

- P3-1：B6 申报文件数 15→实际 12（清单口径误差，见 §一；随件登记即闭环）
- P3-2（观察）：A2 667 阈值容器化使部分高屏设备落 25% 档——已声明行为偏移，非缺陷；Tina iOS 验收建议对 iPhone Plus 系实测底部高度
- P3-3（观察，批外）：build log 存量 Swift 6 actor-isolation 警告（ReplayWindowShell:21/AnalysisViewModel:352）——非本批引入，Swift 6 mode 升级前需清，登记备忘

## 六、结论

**代码面通过，零返工面。** 六件全数与申报一致、隔离修法效应双向实证、零行为/零视觉声明经抽验成立、红线零违反。P3-1 清单误差随件登记。

**放行路径**：Ruby 审通过 → Tina 验收（A2 iOS 分支+视觉确认点随批）→ 门禁 → tag。Luke/群通知按 10-18 协议由 lead sweep 代行。

> 判词落盘即审查完成。Ruby 2026-10-22
