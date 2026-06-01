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

## 2025-06-26 | SwiftUI sheet 预渲染捕获旧状态

**现象**：首次点击关卡弹出空白（或闪关卡列表），第二次正常。

**根因**：SwiftUI `.sheet(isPresented:content:)` 的 content 闭包在 `isPresented` 变为 true 之前被预渲染（求值）。此时中间变量 `adventureLevelId` 还是旧值（nil），导致 `GamePlayView` 收到 `levelId=nil`。

**修复**：sheet content 不用 @State 中间变量，直接从数据源（`app.currentGameLevel`）读取。

**教训**：
1. SwiftUI sheet/fullScreenCover 的 content 闭包可能被预渲染，不能依赖 @State 中间变量的时序
2. 直接读数据源比通过中间变量传递更可靠
3. 调试 UI 时序问题必须加日志看实际值，不能靠代码推断

## 2025-07-15 | verify_delivery.sh 门禁脚本 bug

### Bug 1: `((PASS++))` 在 PASS=0 时触发 `set -e` 退出
**现象**：脚本执行第一个 check_pass 就整体退出，没有任何错误输出。
**根因**：bash `((expr))` 在表达式值为 0 时返回 exit code 1。PASS 初始为 0，`((PASS++))` 表达式值为 0，`set -e` 捕获 exit code 1 后终止脚本。
**修复**：`((PASS++))` → `PASS=$((PASS+1))`（`PASS=$((PASS+1))` 在 PASS=0 时表达式值为 0 但赋值语句本身返回 0）。

### Bug 2: binary 选择逻辑选了 dylib 而非主可执行文件
**现象**：`find -perm +111 | head -1` 在 macOS app bundle 中可能选到 `VocabGame.debug.dylib` 而非主可执行文件 `VocabGame`，导致 `strings` 输出不同。
**修复**：优先选非 dylib 的可执行文件：`find -perm +111 -not -name '*.dylib' | head -1`，无结果时 fallback 到原逻辑。

### 经验教训
1. bash 脚本中 `((var++))` 配合 `set -e` 有陷阱，推荐用 `var=$((var+1))`
2. `find | head -1` 的文件顺序不可预测，需要显式过滤优先级
3. 中文路径 + `set -euo pipefail` + 大 strings 输出的管道交互偶现不一致（手动 strings | grep 成功但脚本内失败），怀疑是 locale/编码相关，暂未定位根因

## 2025-05-28 v1.16 V2 方案审计补齐

### 返工 #1：编译产物未更新
- **现象**：Cody 声称编译成功，但 binary mtime（May 27 23:26）比源码（May 28 06:28）旧 7 小时
- **根因**：编译命令可能输出到了错误目录，或 build 实际失败但被误报为成功
- **修复**：用精确路径重编译 + 验证 binary mtime
- **教训**：编译完成后必须执行 `stat -f "%Sm" <binary>` 确认 mtime > 最新源码 mtime，不能只看 exit code

### 返工 #2：提交清单失实
- **现象**：Cody 声称改了 7 个文件 + 版本号，实际 git diff 涉及 57 个文件、+3455/-840 行
- **根因**：清单手写，未与实际 git diff 核对
- **修复**：Ruby 审查时发现并指出
- **教训**：提交清单必须从 `git diff --stat` 生成，不允许手写

## 2025-05-28 v1.17 角色系统

### 返工 #1：pbxproj 重复破坏
- **现象**：Cody 用 xcodeproj gem 重构 pbxproj 时，覆盖了 v1.16 修过的测试 target 配置（SDKROOT、TEST_HOST、Compile Sources）
- **根因**：xcodeproj gem 的 save 操作会重写整个 pbxproj，丢失手动修复
- **修复**：丹妮介入手动修复，关键发现是 macOS 的 TEST_HOST 路径与 iOS 不同（`.app/Contents/MacOS/Executable` vs `.app/Executable`）
- **教训**：pbxproj 修改必须备份+lint 验证；xcodeproj gem 操作后要验证测试 target 配置未被覆盖

### 返工 #2：levelUpTrigger 回归
- **现象**：v1.17 PetDisplayView 重写后丢失了 v1.16 的 levelUpTrigger 连续升级触发修复
- **根因**：文件重写时未对照 v1.16 修复清单逐项保留
- **教训**：重写文件前，必须列出当前文件中所有已修复问题的补丁点，重写后逐项确认保留

## 2025-06-09 | CogView-3-Flash 无法生成星眼

**问题**：用 CogView-3-Flash 生成 excited（兴奋）状态角色时，4 轮不同 prompt 均无法生成星形眼睛（★）。无论 prompt 如何强调 "star-shaped eyes"、"five-pointed star"、"COMPLETELY REPLACED by stars"，AI 输出始终为普通圆眼。

**已验证的 prompt 变体**（均失败）：
1. "Eyes are replaced by golden/yellow five-pointed star shapes (★)"
2. "The character's eyes are COMPLETELY REPLACED by two large bright golden five-pointed STAR shapes"
3. "Where the eyes normally are, there are TWO LARGE BRIGHT YELLOW FIVE-POINTED STARS"
4. "think of the cartoon trope where amazed characters have stars in their eyes"

**妥协方案**：excited 状态改用超大圆眼 + 大 O 嘴 + 夸张闪光高光，不使用星眼。在 120pt 显示尺寸下与 happy（闭眼弯月）区分度足够。

**影响**：v2 角色素材升级方案。如需真正的星眼效果，需换用 Stable Diffusion + ControlNet 或专业插画师。

## 角色素材生成经验 (2025-06-09)

### CogView-3-Flash 限制
- 无法生成星眼（4 轮 prompt 均失败）
- 无法稳定生成手臂（4 轮均失败）
- 风格一致性不可控：6 色同 prompt 模板生成，体型/眼睛/质感/肢体数量全部不统一
- 结论：不适合需要多角色统一画风的场景

### GPT-4o 限制
- 不支持透明背景生成
- "pear shape" 等抽象描述会被按字面生成错误形状
- 同样存在风格一致性问题

### 验证脚本注意事项
- 验证字符串不能用 xcassets 图片文件名（编译为 Assets.car，不进 binary）
- 应使用源码中的实际引用（如 `egg_yellow`、`EggCharacter`）

### 程序化生成（PIL）优劣势
- 优势：100% 风格一致性，参数精确可控，批量生成零错误
- 劣势：画风天花板受限于 Pillow 能力，偏扁平可爱风，无法达到 3D 渲染质感
- 适用场景：需要多角色统一画风的项目，尤其卡通/Q 版风格

### v3 P2 待下轮迭代
- happy 腮红未放大
- happy 舌头 120pt 下变像素
- sad 泪滴 120pt 下偏小
- excited 嘴巴偏小+缺舌头
- Red 颜色偏珊瑚非正红

## StatsManager 测试隔离缺陷（非阻塞）
- **发现时间**: Phase 3 / Phase 4
- **现象**: 单独 `swift test --filter Phase3Tests` 时 StatsManager 4 个测试失败（shared singleton + UserDefaults 状态未清理），全量跑通过
- **影响**: 仅测试可靠性，不影响产品功能
- **根因**: StatsManager 用 shared 单例 + UserDefaults，测试间状态残留
- **修复建议**: 给 StatsManager 测试添加 setUp/tearDown 清理 UserDefaults，或注入 UserDefaults 实例
- **优先级**: P2，后续修复
