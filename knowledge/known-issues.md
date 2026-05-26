# known issues

> 待团队初始化后补充内容

## 2026-04-06 word_counter.py 返工根因
- P0：路径未校验 + --top 无下界 — 防御性编程不足，CLI 参数和文件路径必须做边界校验
- P1：大文件 OOM + 错误信息不明确 + 职责未拆分 — 新脚本应默认流式处理，函数拆分从开始就做
- P2（known）：预编译正则可优化性能，不阻塞

## csv_merger.py (2026-04-06)
- [P2] `parser.error` lambda 覆写方式不够安全，可能影响 argparse 内部行为
- [P2] `files_opened` 变量语义模糊，建议重命名
- [P2] `reconfigure` 放模块顶层会影响 import 行为
- [P2] 空文件触发不友好的 StopIteration 错误

## task_tracker.py — 已知取舍

- **数据恢复粒度**：损坏恢复用的是 `.bak`（操作前备份），可能丢失最后一次写操作的状态。非 bug，设计取舍。

## 知识库系统方案 P1 待确认项（2026-04-06）

- slug 唯一约束与软删除的具体实现方案待定
- Nginx `/search/` 代理规则会 404，实际应走 `/api/`
- ES 同步重试缺少最大次数限制
- JWT logout 对 refresh_token 的处理需明确
- 其余 3 个 P1 + 2 个 P2 详见 Ruby 审查清单

## 2026-04-07 知识库 P0 返工根因

### BUG-001：JwtUtil.getJti() 缺失导致编译失败
- **根因**：AuthService 引用了 JwtUtil 中不存在的方法，说明编码时没有做编译验证（宿主机 Java 11 无法编译 Spring Boot 3.2）
- **防范**：代码审查流程应增加"编译检查"环节；无法本地编译时，应在 Docker 内做编译验证

### BUG-002：Dashboard 权限与需求不符
- **根因**：编码时未回查 proposal 权限矩阵，凭印象写成了 ADMIN+EDITOR
- **防范**：涉及权限的代码，实现前必须对照 proposal 权限矩阵表

### BUG-003：密码策略不统一
- **根因**：UserCreateRequest 和 RegisterRequest 分别编写，没有复用同一套校验规则
- **防范**：同一实体的不同入口应共享校验逻辑，抽取公共 validator

## 2026-04-09 P2优化遗留项

### ~~L-PERM-001: 用户搜索接口鉴权不完整~~ ✅ 已修复 (2026-04-09)
- **问题**：`GET /api/v1/users/search` 后端限制为 `@PreAuthorize("hasRole('ADMIN')")`，但方案要求当前资源 MANAGE 持有者也可调用
- **影响**：非 ADMIN 但拥有 MANAGE 权限的用户无法在权限对话框中搜索用户
- **优先级**：低（当前 ADMIN 场景完整）
- **根因**：Cody 修 M2 时只加了 ADMIN 校验，未包含 MANAGE 资源权限判断

### ~~L-P2-LOW: Ruby 审查低优先级暂挂项~~ ✅ 已修复 (2026-04-09)
- L4: ArticleList 未集成批量权限查询（列表页按钮显示未按资源权限控制）
- L5: PermissionService toDTOList 存在 N+1 查询风险
- L7: PermissionDTO 类型前后端命名不一致（permission vs permissionLevel）
- L8: import 顺序不规范

## 2026-04-12 meetroom P2-6 restoreRoom @TableLogic 返工

**问题**：MyBatis-Plus `@TableLogic` 注解会在所有 BaseMapper 方法（包括 `updateById` 和 `update(null, wrapper)`）自动追加 `WHERE deleted=0`，导致对已软删除记录的 UPDATE 始终匹配 0 行。

**返工次数**：2 轮
- 第1轮：Cody 用 `LambdaUpdateWrapper` 尝试绕过 → 失败，@TableLogic 仍然拦截
- 第2轮：Tina 建议改用 Mapper 原生 SQL → 成功

**解决方案**：在 Mapper 接口中定义 `@Update` 原生 SQL 方法，彻底绕过 @TableLogic 拦截。

**教训**：MyBatis-Plus @TableLogic 无法通过任何 BaseMapper 方法绕过（包括 `update(null, wrapper)`）。对软删除记录做更新操作时，必须用原生 SQL。

## 2025-07-14 | 中国象棋 — UI 交互 hit-test 盲区

**问题**：棋子不能走 / 不能落子到空位，连续两个 P0
**根因**：SwiftUI ZStack 中 `.frame()` 和 `.position()` 的 hit-test 语义理解不足。所有子视图 frame 设为棋盘大小导致点击区域重叠；空位没有 tap handler 导致落子交互断裂。
**教训**：
1. SwiftUI 中 `.position()` 只改变视觉位置，不影响 hit-test 区域。需要配合正确的 `.frame()` 或 `.contentShape()` 使用
2. 交互类测试不能只测逻辑层（ViewModel），必须覆盖「选中→落子」完整链路
3. UI 交互 bug 不能只靠自动化测试，需要手动测试清单
**预防**：新 UI 组件必须同时写交互测试 + 手动测试清单，Tina 审核时验证

## 2025-07-15 | vocab-game 每日挑战卡"加载中" | UI 状态流转测试盲区

**现象**：每日挑战点击后一直显示"加载中"，无法进入游戏。

**根因**：DailyChallengeViewModel 中 `todayCompleted = true` 时直接 return，但 loading 状态未被正确关闭，导致 UI 永远停在 loading。

**教训**：
- Tina 的 226 个测试主要覆盖数据逻辑（题目生成、评分、金币扣减），但**没有覆盖 ViewModel 的 UI 状态流转**（loading → ready → playing → completed）
- **所有 ViewModel 必须覆盖 loading/error/empty 三种边界状态的测试**
- 数据层测试全过 ≠ UI 层没问题，ViewModel 的状态机需要显式测试

**改进措施**：
- 每日挑战 UI 状态流转：loading → 游戏界面 / 已完成提示
- `todayCompleted = true` 时应显示"今日已完成"而非卡加载
- 其他 ViewModel（SpellChallenge、MatchGame）同理补充 loading 状态测试

## 2025-06-26 | macOS 打包产物未更新

**现象**：Cody 报告打包完成，但桌面 .app 的 binary mtime 早于源码修改时间，实际运行的是旧代码。

**根因**：xcodebuild 未 clean，缓存产物被当作新编译结果。strings 验证环节缺失，没检查 binary 是否包含新代码的字符串。

**教训**：
1. macOS Release 打包必须先 `xcodebuild clean` 再 build
2. 编译完成后必须验证 binary mtime > 源码 mtime
3. 必须用 `strings` 检查 binary 包含修复相关的特征字符串
4. 新包用新文件名（VocabGame_v2.app），避免旧文件权限/缓存问题

**影响**：洪涛运行旧包发现 bug 未修复，多轮返工。

## 2025-06-26 | wordlist.json bundle 路径错误（真正根因）

**现象**：app 所有功能无内容——新手村庄、每日挑战、拼写挑战全部空白。

**根因**：`WordRepository` 用 `Bundle.main.url(forResource: "wordlist", withExtension: "json", subdirectory: "Data")` 加载数据，但 Xcode 编译后 `wordlist.json` 在 `Contents/Resources/` 下，没有 `Data` 子目录。导致 `loadWords()` 抛出 `fileNotFound`，allWords 为空，所有功能失效。

**修复**：去掉 subdirectory 参数，改为 `Bundle.main.url(forResource: "wordlist", withExtension: "json")`

**教训**：
1. bundle 资源路径必须实测验证，不能只看项目目录结构
2. 数据加载失败时应有明确的 UI 提示（而不是静默失败）
3. 之前修的空数据保护（errorMessage）是对的症状处理，但不是根因修复

**影响**：洪涛多次测试都看到空白界面，根本原因是数据没加载。

## 2025-06-26 | 打包验证连续三次失败

**现象**：Cody 报告打包完成并通过验证，但实际 binary mtime 仍早于源码修改时间。

**根因**：Cody 的验证步骤可能读取了缓存的时间戳，或编译和修改的时序不对（先编译后修改源码）。

**决策**：从今起，打包产物的 mtime + strings + bundle 资源验证由 Luke 亲自执行，不依赖 Cody 的验证报告。Cody 只负责编译和复制，交付前 Luke 逐项检查。

**影响**：三次返工，浪费时间约 30 分钟。

## 2025-06-26 | Cody 连续未完成修复任务

**现象**：派给 Cody 两个修复任务（配对同类型限制 + ESC 退出），Cody 报告完成但实际上：1）配对限制完全没改；2）ESC 只加了 onDismiss 没定位根因。打包产物 binary mtime 仍早于源码。

**教训**：
1. 简单逻辑修改可以直接给实现代码让 Cody 照抄，避免理解偏差
2. UI 问题需要先定位具体现象再修，不能盲猜方向
3. Cody 的"修复完成"报告不可信，必须 Luke 亲自验证源码改动 + binary mtime
4. 今后对 Cody 的产出默认不信任，先验证再推进

**影响**：浪费两轮测试和打包时间。

## 2025-06-26 | mistakeReview 模式 onAppear 前闪"暂未开放"

**现象**：mistakeReview 模式在 onAppear 执行前，body 兜底分支短暂显示"暂未开放"。

**状态**：预存在问题，非本轮引入，不阻塞发布。与 adventure 模式同类问题，后续可加 ProgressView 条件修复。
