# 存量测试技术债清理方案

> 角色：Alex | 日期：2026-07-30 | 版本：v1.1（Vera 审查后修订）
>
> ## 修订记录
>
> | 版本 | 日期 | 变更 |
> |------|------|------|
> | v1.0 | 2026-07-30 | 初版 |
> | v1.1 | 2026-07-30 | 修复 Vera 审查 P0-1~P0-4、P1-1~P1-5 |

## 背景

B2 Step 2 回归测试 711 tests 中 80 issues / 33 suites 失败，全部为存量问题（与 B2 变更无关）。根因：v2.2.x → v3.9 → v4.0 → v5.x 多次迭代中产品代码重构了接口/行为，但旧测试未同步更新。

本方案与 B2 并行执行，不阻塞 B2。

---

## 诊断方法论

对每个失败 issue，按以下决策树判断：

```
测试断言失败
├─ 产品代码 API 签名变了 → 更新测试调用（低风险，批量）
├─ 产品代码行为语义变了 → 确认新行为正确 → 更新断言（低风险）
│                                    └─ 新行为可疑 → 记录为产品 bug
│                                         └─ 评估影响传播 → 标注影响哪些其他测试/功能
├─ 测试依赖硬编码值（xcstrings key、文件路径）→ 同步更新测试（低风险）
├─ 测试逻辑本身有缺陷 → 修复测试逻辑（中风险，需审查）
└─ 测试环境问题（构建路径、Bundle 解析等）→ 更新测试基础设施（低风险）
```

**关键原则**：
1. 80 个 issues 中，预期 70+ 是"测试过时"（更新断言即可），<10 个可能是产品 bug
2. 每批修复后跑全量回归，确保不引入新问题
3. 产品代码 bug 不在本方案修复范围——记录到 known-issues.md，排入后续版本
4. 每个确认的产品 bug 必须标注**影响传播范围**（影响哪些其他测试/功能），如果超出当前 batch 需在对应 batch 中声明处理方式（跳过、标记 xfail、或设为阻塞项）
5. 测试之间有依赖顺序——BoardPlayer（第三类）是 DemoViewModel（第二类）和 ReplayViewModel（第三类）的委托基础，必须先修 BoardPlayer

---

## 七大类详细诊断与修复策略

### 一、L10n / 国际化（~28 issues，最大类）

**根因分析**：
- 项目从 `NSLocalizedString` 迁移到自定义 `L10n` 类 + xcstrings 双轨制
- 旧测试断言硬编码 xcstrings key 数量（如 `#expect(strings.count >= 544)`）、硬编码翻译值
- 新增 key 后旧断言过期；翻译值调整后硬编码期望值不匹配
- 部分 key 从 xcstrings 迁移到 L10n 的 `.lproj/Localizable.strings`，测试仍在查 xcstrings

**诊断思路**：
| 检查项 | 判断标准 |
|--------|----------|
| key 是否存在于 xcstrings | 查 `Localizable.xcstrings` strings 字典 |
| key 是否存在于 .lproj | 查 `zh-Hans.lproj/Localizable.strings` |
| 翻译值是否匹配 | 对比测试期望值与实际文件值 |
| key 数量断言 | `>= N` 类型断言只需更新下界；`== N` 类型断言需改为 `>= N` |

**修复策略**：
- **更新断言**（低风险，批量）：key 数量 `>=` 下界调整、翻译值同步
- **更新测试查找路径**（低风险）：从 xcstrings 查找改为 L10n.shared.t() 验证
- **删除过时 key 断言**（低风险）：已废弃的 key 从测试中移除
- **模式改进**（中风险）：将 `== N` 改为 `>= N`，避免每次新增 key 都要改测试

**预估工作量**：28 issues，约 2 小时。大部分是机械性更新。

**风险点**：
- xcstrings 与 .lproj 双轨制可能混乱——修复前先确认当前产品代码到底用哪个
- `D5I18nAuditVerificationTests` 的 `>= 544` 这类断言需要知道当前实际 key 数量

**P0-3 修复：L10n 运行时行为确认（Batch 2 前置步骤）**：

在修复 L10n 测试之前，必须先确认运行时行为：
1. 验证 `L10n.shared.t()` 实际从哪个源读值——是 `.lproj/Localizable.strings` 还是 `Localizable.xcstrings`
2. 确认哪些 key 走哪条路径（如有规律，记录下来）
3. 测试断言对齐运行时实际使用的源

验证方法：在测试中调用 `L10n.shared.setLanguage("zh-Hans")`，然后用 `L10n.shared.t("key")` 获取实际返回值，对比 xcstrings 和 .lproj 中的值。如果 L10n 返回的是 .lproj 的值，测试就对齐 .lproj；如果返回 xcstrings 的值，就对齐 xcstrings。

---

### 二、DemoViewModel 委托层（~10 issues）

**根因分析**：
- v3.9 Phase 2 将 DemoViewModel 播放逻辑抽取到 BoardPlayer
- DemoViewModel 变为委托层：`canGoForward` → `boardPlayer.canGoForward` 等
- 旧测试直接访问 DemoViewModel 属性，期望值与 BoardPlayer 委托行为不一致
- `progressText`：DemoViewModel 用 `String(localized:)` 格式，BoardPlayer 用纯文本 `"\(currentIndex)/\(totalSteps)"`
- `validStepCount`：DemoViewModel 委托 `boardPlayer.totalSteps`，旧测试可能期望不同语义
- `canGoForward`/`canGoBack`：BoardPlayer 用 `currentIndex < totalMoves`，DemoViewModel 委托转发

**诊断思路**：
| 检查项 | 判断标准 |
|--------|----------|
| 委托转发是否正确 | DemoViewModel 属性 == BoardPlayer 对应属性 |
| progressText 格式 | DemoViewModel: "第 X/Y 步" vs BoardPlayer: "X/Y" |
| stepForward/stepBackward 行为 | 是否正确委托到 BoardPlayer 并停止播放 |
| 初始化状态 | currentIndex=0, lastMove=nil, playState=.idle |

**修复策略**：
- **更新断言值**（低风险）：`canGoForward`/`canGoBack`/`currentIndex` 与 BoardPlayer 语义对齐
- **更新 progressText 期望**（低风险）：确认 DemoViewModel.progressText 用的是 `String(localized:)` 格式
- **更新 validStepCount 期望**（低风险）：与 `boardPlayer.totalSteps` 对齐
- **stepForward 停止播放**（低风险）：DemoViewModel.stepForward 调用 `boardPlayer.stepForward()` + 设 `playState = .idle`

**预估工作量**：10 issues，约 1.5 小时。需要逐个确认委托关系。

**风险点**：
- DemoViewModel 的 `stepForward()` 是否还执行了 BoardPlayer 之外的逻辑（如点评更新）
- 如果测试发现委托转发有 bug，则需修复产品代码——但根据代码审查，转发逻辑简单直接，bug 可能性低

---

### 三、BoardPlayer / 回放（~8 issues）

**根因分析**：
- BoardPlayer 是从 DemoViewModel 和 ReplayViewModel 抽取的通用播放器
- 旧测试可能还在测 DemoViewModel/ReplayViewModel 的旧接口
- `stepForward`/`stepBackward` 行为变化：BoardPlayer 中 `stepForward` 先执行再 +1，`stepBackward` 先 -1 再重建
- 历史回放入口：ReplayViewModel 可能改了公开 API（如 `goForward` → `stepForward`）
- BoardPlayer 的 `progressText` 是 `"X/Y"`，与 DemoViewModel 的 `"第 X/Y 步"` 不同

**诊断思路**：
| 检查项 | 判断标准 |
|--------|----------|
| 旧测试调用方法是否存在 | 编译错误 → 方法名变了 |
| stepForward/stepBackward 语义 | 与 BoardPlayer 实现对齐 |
| ReplayViewModel 委托转发 | 与 BoardPlayer 一致 |
| 历史回放入口 | ReplayView 的入口是否从 sheet 改为内部状态切换 |

**修复策略**：
- **更新方法调用名**（低风险）：`goForward` → `stepForward` 等
- **更新断言值**（低风险）：`currentIndex`/`canGoForward`/`canGoBack` 与 BoardPlayer 语义对齐
- **更新 progressText 期望**（低风险）：ReplayViewModel 可能也有自己的 progressText 格式
- **回放入口测试调整**（中风险）：如果入口从 sheet 改为状态切换，测试结构需调整

**预估工作量**：8 issues，约 1.5 小时。

**风险点**：
- ReplayViewModelTests 中 `testBoard_FENDifferentUUIDs` 验证了 Board UUID 问题——这是已知问题（Piece.id 改为稳定 Int），断言可能需要从 `XCTAssertNotEqual` 改为 `XCTAssertEqual`

---

### 四、SearchConfig / AI 引擎（~6 issues）

**根因分析**：
- v3.9 AI 引擎大改：medium 启用/禁用 QS、搜索深度调整、NullMove 开关
- 旧测试断言了特定的搜索配置（如 `medium.enableQuiescence == true`），与当前配置不符
- `captureMoves` 方法签名或行为变化（v3.9 为 QS 优化新增 `captureMoves`）
- NullMove/mate score 断言与当前引擎行为不匹配
- 已知问题：medium QS 曾导致挂起（回退为 `enableQuiescence: false`）

**诊断思路**：
| 检查项 | 判断标准 |
|--------|----------|
| 搜索配置当前值 | 检查 AIConstants.swift / EvalConfigManager |
| captureMoves 行为 | 是否跳过 wouldBeInCheck（当前实现是跳过的） |
| NullMove 配置 | 各难度是否启用 |
| mate score 范围 | 当前引擎是否能产生 mate score |

**修复策略**：
- **更新配置断言**（低风险）：`enableQuiescence`/`useNullMove`/深度值同步到当前值
- **更新 captureMoves 测试**（低风险）：确认当前实现是跳过 wouldBeInCheck 的候选走法
- **NullMove/mate score 断言调整**（中风险）：如果引擎行为改变，需要重新理解语义

**预估工作量**：6 issues，约 1.5 小时。AI 引擎逻辑复杂，需谨慎确认每个断言的语义。

**风险点**：
- medium QS 回退是否导致测试中的 medium 行为断言全变
- 如果测试发现了 captureMoves 的实际 bug（如返回不合法走法），需升级为产品 bug
- `P0AIFixTests` 中的 `bestMove(fen:moveHistory:)` 接口——检查当前 AIEngine 是否还有此签名

---

### 五、教程 / 段位系统（~8 issues）

**根因分析**：
- 教程课程数据变更：新增/删除/重命名课程，titleKey/subtitleKey 变化
- `isLastLesson` 语义可能变化（课程数量调整）
- 段位门禁 `UnlockedFeature` 新增/调整：requiredRank 变化
- xcstrings 中 tutorial.* key 变化导致教程 i18n 测试失败

**诊断思路**：
| 检查项 | 判断标准 |
|--------|----------|
| 课程列表当前内容 | TutorialViewModel.lessons 的 id/titleKey |
| isLastLesson 判断 | 最后一个课程的 id 是否与断言匹配 |
| UnlockedFeature.allCases | 当前有哪些 feature，requiredRank 是什么 |
| tutorial.* key 完整性 | xcstrings 中是否包含所有 tutorial.* key |

**修复策略**：
- **更新课程标题/内容断言**（低风险）：同步 TutorialViewModel 的当前课程数据
- **更新段位门禁断言**（低风险）：同步 UnlockedFeature 的当前定义
- **更新 isLastLesson 期望**（低风险）：确认最后一个课程的 id
- **更新 tutorial.* key 列表**（低风险）：同步 xcstrings 内容

**预估工作量**：8 issues，约 1.5 小时。需要逐个确认课程数据和段位定义。

**风险点**：
- 如果段位门禁逻辑本身有 bug（如某个 feature 的 requiredRank 设错），测试失败反而暴露了真实问题
- `P0ChapterUnlockFormatTests` 可能涉及格式化逻辑，需确认

---

### 六、棋局规则 / 验证（~8 issues，P0 最高优先）

**根因分析**：
- `captureMoves`：v3.9 新增，跳过 wouldBeInCheck 检查，语义与 `allLegalMoves` 不同
- `halfmoveClock`：判和逻辑可能调整了初始值或递增规则
- 困毙判负：`allLegalMoves.isEmpty` 的判断时机可能与旧测试期望不同
- `Piece.id`：从 UUID 改为稳定 Int，旧测试可能断言了 UUID 格式
- `MoveValidator.isLegal`：wouldBeInCheck 从 in-place 改为 snapshot 方式（已知 P0 回归修复）

**诊断思路**：
| 检查项 | 判断标准 |
|--------|----------|
| captureMoves vs allLegalMoves | 前者不做 wouldBeInCheck，后者做 |
| halfmoveClock 初始值 | Board 初始化时是否正确设置 |
| 困毙判负 | 无合法走法 → 当前方输 |
| Piece.id 格式 | 当前是 Int (0-31 + 10000-16198)，不是 UUID |
| wouldBeInCheck 实现 | 当前是 snapshot 方式 |

**P0-1 修复：captureMoves 对局影响验证**：

captureMoves 返回非法走法不仅影响测试，更影响 AI 对局质量。诊断需增加：
1. **确认调用链**：当前哪些难度级别实际调用了 captureMoves？
   - medium 已回退 `enableQuiescence: false`，如果只有 QS 用 captureMoves，则 medium 不触发
   - hard/master 是否启用 QS？如果启用，captureMoves bug 是活跃 bug
   - 如果 captureMoves 只被 QS 调用且所有难度都禁用了 QS，则是"休眠 bug"——代码有毒但当前不触发
2. **对局影响验证**：用已知棋局 FEN，对比 `captureMoves` 开/关时 `bestMove` 的差异
   - 如果差异显著（不同走法），说明 captureMoves 确实影响了对局结果
   - 如果无差异（QS 未启用），记录为休眠 bug，优先级降为 P2

**修复策略**：
- **更新 captureMoves 断言**（低风险）：期望值应包含 wouldBeInCheck 会被拦截的走法
- **更新 halfmoveClock 断言**（低风险）：确认当前递增/重置逻辑
- **更新困毙判负断言**（低风险）：确认行为是"无合法走法 → 当前方输"
- **更新 Piece.id 断言**（低风险）：从 UUID 改为 Int 范围断言
- ⚠️ **如果发现规则逻辑真有 bug**（中风险）：记录到 known-issues.md，不在此方案修复

**预估工作量**：8 issues，约 2 小时。规则类需要仔细确认语义。

**风险点**：
- **这是 P0 优先级的原因**：如果 captureMoves 或判和逻辑真有 bug，可能影响实际对局
- halfmoveClock 判和可能影响长局对弈体验
- 困毙判负方向错误是严重 bug（应判负但判了和，或反之）

---

### 七、视图结构 / 杂项（~12 issues）

**根因分析**：
- 文件结构断言：Swift 文件被移动/重命名/删除，旧测试断言文件存在性
- `OpeningBoardPreview` 等 View 的初始化签名变化
- Xcode 项目结构从 SPM 迁移到 xcodegen，文件路径变化
- View 的 `@Previewable` 或 `#Preview` 宏相关测试

**诊断思路**：
| 检查项 | 判断标准 |
|--------|----------|
| 文件是否存在 | `find` 命令确认 |
| View 初始化签名 | 检查当前源码中的 init 参数 |
| 测试是否依赖 SPM 路径 | 改为 xcodegen 路径 |

**修复策略**：
- **更新文件路径断言**（低风险）：同步当前文件位置
- **更新 View 初始化调用**（低风险）：同步当前签名
- **View 重构移除时确认功能去向**（中风险）：每个被移除的 View 需确认：
  - 功能已迁移到其他 View → 更新测试指向新 View
  - 功能已废弃（有意识删除） → 删除测试，标注废弃原因
  - 功能缺失（无意识删除） → 升级为产品 bug，记录到 known-issues.md
- **SPM → xcodegen 路径更新**（低风险）：构建产物路径变化

**预估工作量**：12 issues，约 1.5 小时。大部分是机械性更新。

**风险点**：
- 视图结构变化可能暗示功能缺失——需确认是"重命名"还是"删除功能"
- `OpeningBoardPreview` 如果被移除，需确认功能是否迁移到其他 View

---

## 分批执行计划

### 前置步骤：L10n 运行时行为确认

在 Batch 2 开始前，先确认 L10n 双轨制运行时行为（见第一类 P0-3 修复）。预计 30 分钟。

---

### Batch 1：P0 — 棋局规则/验证（第六类）+ BoardPlayer/回放（第三类）

> **依赖关系**：BoardPlayer 是 DemoViewModel 和 ReplayViewModel 的委托基础。虽然第三类不严格属于 P0，但必须先修好 BoardPlayer 测试，Batch 2 中 DemoViewModel 的断言值才能确认。

| 项目 | 内容 |
|------|------|
| 范围 | 16 issues（规则/验证 8 + BoardPlayer/回放 8） |
| 预估时间 | 3.5 小时 |
| 风险 | 中（可能发现产品 bug） |
| 产出 | 更新的测试文件 + 潜在产品 bug 清单 |

**执行步骤**：
1. 规则/验证（8 issues）：
   - 逐个分析失败
   - captureMoves 诊断包含对局影响验证（P0-1）
   - 区分"测试过时"vs"产品 bug"
   - 产品 bug → 记录到 known-issues.md，标注影响传播范围（P0-2）
2. BoardPlayer/回放（8 issues）：
   - 确认 BoardPlayer 当前 API 和行为
   - 更新 ReplayViewModel 委托断言
   - Piece.id 从 UUID 改为 Int 的断言调整
3. 每修完一类跑一次专项回归（6-8 分钟），确认无新增失败
4. 整批完成后跑全量回归

**通过标准**：16 个 issues 全部解决（测试更新或 bug 记录），回归测试无新增失败。

---

### Batch 2：P1 — DemoViewModel（第二类）+ L10n（第一类）

> **执行顺序**：先修 DemoViewModel（10 issues），再批量修 L10n（28 issues）。因为 DemoViewModel.progressText 依赖 L10n key，先确认委托行为，L10n 修复时才有参考。

| 项目 | 内容 |
|------|------|
| 范围 | 38 issues（DemoVM 10 + L10n 28） |
| 预估时间 | 4.5 小时 |
| 风险 | 低（大部分是机械性更新） |
| 产出 | 更新的测试文件 |

**执行步骤**：
1. DemoViewModel（10 issues）：
   - 逐个确认委托转发关系（依赖 Batch 1 中已验证的 BoardPlayer 行为）
   - 更新断言值
   - 每 5 个 issues 跑一次 DemoViewModel 专项回归
2. L10n（28 issues）：
   - **前置**：确认 L10n 运行时行为（P0-3），确定测试对齐哪个源
   - 批量更新 xcstrings key 断言和翻译值
   - 每 10 个 issues 跑一次 L10n 专项回归
3. 整批完成后跑全量回归

**通过标准**：38 个 issues 全部解决，回归测试无新增失败。

---

### Batch 3：P2 — AI 引擎（第四类）+ 教程/段位（第五类）+ 视图/杂项（第七类）

| 项目 | 内容 |
|------|------|
| 范围 | 26 issues（AI 引擎 6 + 教程/段位 8 + 视图/杂项 12） |
| 预估时间 | 5.5 小时 |
| 风险 | 低-中 |
| 产出 | 更新的测试文件 + 潜在产品 bug 清单 |

**执行步骤**：
1. AI 引擎（6 issues）：谨慎确认每个断言语义
   - 如果发现产品 bug，标注影响传播范围
2. 教程/段位（8 issues）：同步课程数据和段位定义
3. 视图/杂项（12 issues）：
   - 每个被移除的 View 确认功能去向（已迁移/已废弃/功能缺失）
   - 功能缺失升级为产品 bug
4. 每类完成后跑一次专项回归
5. 整批完成后跑全量回归

**通过标准**：26 个 issues 全部解决，回归测试无新增失败。

---

## 总结

| 批次 | 优先级 | 范围 | Issues | 预估时间 | 风险 |
|------|--------|------|--------|----------|------|
| 前置 | — | L10n 运行时确认 | — | 0.5h | 低 |
| 1 | P0 | 规则/验证 + BoardPlayer/回放 | 16 | 3.5h | 中 |
| 2 | P1 | DemoVM + L10n | 38 | 4.5h | 低 |
| 3 | P2 | AI + 教程 + 视图 | 26 | 5.5h | 低-中 |
| **合计** | | | **80** | **14h** | |

> 注：总预估从 v1.0 的 10h 调整为 14h（+40%），增加缓冲以覆盖产品 bug 诊断时间、增量回归验证时间、以及 AI 引擎断言的谨慎确认。

### 关键决策记录

1. **不修复产品代码 bug**：本方案仅更新测试断言。如果发现产品 bug，记录到 known-issues.md 排入后续版本
2. **产品 bug 影响传播评估**：每个确认的产品 bug 必须标注影响范围，如果影响其他 batch 的测试，需声明处理方式
3. **与 B2 并行**：本方案不修改产品代码，不会影响 B2 进度
4. **增量回归验证**：每修完一类跑一次专项回归（而非整个 Batch 完成后才跑），避免大量修改后难以定位问题
5. **断言模式改进**：L10n key 数量断言从 `== N` 改为 `>= N`，避免后续新增 key 又导致测试失败
6. **方案变更机制**：方案变更需记录在修订记录中。新增产品 bug、工时超 20% 需通知 Luke；断言值微调可自行处理

### known-issues.md 记录模板

确认的产品 bug 按以下格式记录到 `~/DevTeam/knowledge/known-issues.md`：

```markdown
## {问题简述}（{日期}）
- **现象**：{具体表现}
- **严重度**：P0/P1/P2
- **复现步骤**：{如何复现}
- **影响范围**：{影响哪些测试/功能}
- **建议修复版本**：{vX.Y.Z}
- **状态**：待修复
```

### 验收标准

方案整体完成后的验收标准：
1. 80 issues 关闭率 ≥ 95%（允许少量需产品代码修复的 issue 保持记录状态）
2. known-issues.md 中记录的产品 bug ≤ 10 个
3. 全量回归测试（`xcodebuild test -skip-testing:EloBaselineTests`）通过率 100%
4. 无新增测试失败

### 潜在产品 Bug 清单（待确认）

以下是根据代码审查和已知问题预判的可能产品 bug，需在 Batch 1 诊断时确认：

| # | 疑似问题 | 严重度 | 来源 |
|---|----------|--------|------|
| 1 | captureMoves 返回 wouldBeInCheck 的非法走法 | P0 | known-issues.md: medium QS 导致挂起 |
| 2 | halfmoveClock 在某些特殊走法下未正确重置 | P1 | 规则验证测试 |
| 3 | L10n 与 xcstrings 双轨制可能存在运行时不一致 | P2 | L10n 类测试 |

### 测试基础设施改进建议（不在本方案范围）

1. **CI 自动回归**：每次提交自动跑测试，脚本模板：
   ```bash
   cd ~/DevTeam/projects/chinese-chess
   xcodegen generate && \
   xcodebuild test -skip-testing:EloBaselineTests \
     -resultBundlePath ./TestResults.xcresult
   ```
2. **断言稳定性**：避免硬编码数量值。示例：
   ```swift
   // ❌ 旧写法：每次新增 key 都要改
   #expect(strings.count == 544)
   // ✅ 新写法：下界断言 + 缺失 key 列表
   #expect(strings.count >= 544, "当前 key 数: \(strings.count)")
   let missing = expectedKeys.filter { strings[$0] == nil }
   #expect(missing.isEmpty, "缺失 key: \(missing)")
   ```
3. **测试分类标签**：用 `xcodebuild test -only-testing:<TestClassName>` 做模块级专项运行，比 SPM `--filter` 更适合 xcodegen 项目
