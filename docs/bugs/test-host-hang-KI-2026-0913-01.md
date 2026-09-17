# Known Issue：测试宿主挂起（xcodebuild test 全通道 hung before establishing connection）

- **编号**：KI-2026-0913-01
- **状态**：RESOLVED-CLOSED（2026-09-16 21:1x 销单，Luke——补验队列全绿回填，见文末"销单记录"）
- **登记**：Luke 2026-09-14 08:15（收口裁决日）；首发现 2026-09-13；根因改判 2026-09-15 23:2x；销单 2026-09-16 21:1x
- **影响范围**：本机全部 xcodebuild test 运行（主仓 m1 与 worktree 双通道）；不影响 xcodebuild build、直 exec、screencapture、screenshot 采集

## ✅ 根因（2026-09-15 23:2x 破案，Luke）

**代理会话沙箱阻断测试宿主建连。** xcodebuild 经 LaunchServices 拉起测试宿主后，沙箱策略随进程树继承到宿主进程，宿主回连 xctest 所需的文件/Mach 操作被拒 → 挂起至超时。日志佐证：挂起轮的最后一次成功操作恒为 lsregister（LS 注册），随后 321s 静默；每轮沙箱内探针 stderr 恒见 `~/.swiftpm/security (file-write-unlink)` 拦截。

### 决定性对照实验（2026-09-15 晚，同命令同机同用户态）

| 轮 | 执行环境 | 宏旗标 | 结果 |
|---|---|---|---|
| 09-13 起蒂娜全部探针 + 今晚 22:53 / 23:03（用户态全隔离两轮） | 沙箱内 | 有 | 🔴 挂（7m20s+ 同指纹） |
| 今晚 23:17 / 23:19 | **沙箱外**（escalation-approved） | 有 / 无 | 🟢 **TEST SUCCEEDED ×2** |

### 补录修正（2026-09-15 深夜，Tina 止损回报触发，Luke 采纳）

破案通报两处过强论断，经补验队列实证修正：

**修正一：宏旗标 ≠ 沙箱伪装，两者是独立轴。** 23:17/23:19 双绿均为**暖 DD**（231732 日志 27KB 零编译行），不构成"无旗标也绿"的充分证据。Tina 冷编译实证：沙箱外、无旗标，worktree 三套全部死于 ObservationMacros 32 error（~/DevTeam/logs/v64c2/V64C2LayoutTests-recap.log）。正确模型：
- **代理会话沙箱** → 杀宿主建连（本 KI 本体）
- **Swift 编译器沙箱**（宏插件展开）→ 冷编译宏错，旗标 `-Xfrontend -disable-sandbox` 治这个，**沙箱内外冷编译都需要**
- 暖 DD 下测试阶段不带旗标可绿（23:17 实证）

**修正二：后台任务的沙箱豁免不生效。** Tina 队列（dangerouslyDisableSandbox=true 启动）内主仓两套仍以经典指纹挂起（ContemptT2Revert 5m49s / Phase2b 5m43s，~/DevTeam/logs/ContemptT2RevertTests-recap.log / Phase2bTests-recap.log）；Luke 侧独立佐证：23:10 RG8kaF 后台任务（带豁免启动）stderr 仍见 [sandbox] 拦截行。

### 四象限终局表（2026-09-15 深夜，Tina 止损轮补完，每格有日志实证）

| 象限 | 结果 | 证据 |
|---|---|---|
| 前台 + 豁免获批 + 暖 DD | ✅ 绿 | PlayerColorTests-fg-probe.log（rc=0/5 passed）+ Luke 23:17（231732.log） |
| 前台 + 豁免未获批（用户未应答超时=沙箱内） | ❌ 挂 | ContemptT2RevertTests-recap.log（hung + .swiftpm/security 拦截并行出现） |
| 后台 + 启动带豁免旗标 | ❌ 挂 | Contempt/Phase2b 队列 5m49s/5m43s；Luke RG8kaF 佐证 |
| 后台 + 沙箱内 | ❌ 挂 | 09-13 起全部历史探针 |

**结论**：豁免必须逐次获批且仅前台生效。逐套件 10 次批准要求用户实时在场——不可持续（09-16 00:02 第二次申请时用户在睡眠中，未应答超时被系统记为拒绝；实测坐实"逐次批准"通道形态依赖用户作息）。可持续通道形态待用户拍板（白名单/单批授权），销单条件随之悬置。→ **09-16 晚已解决（见下方"09-16 晚间补记"，洪涛批准窄白名单并实测生效）**

**权限系统语义坑（09-16 洪涛澄清后补记）**：权限卡的"未应答超时"与"明确拒绝"在系统层面同义（均回 "explicitly denied" + "Do NOT retry"）——代理侧无法区分，会把"用户不在场"误读为"用户反对"。今后夜间/长跑批次的设计必须避免依赖实时人工批准（改白名单，或安排在用户活跃时段）。

### 09-16 晚间补记：白名单=豁免轴实体，晨间连挂消解（Luke）

- **机制辨明**：四象限"前台+豁免获批"的"豁免"实体 = `~/.workbuddy/settings.json` → `sandbox.commandSafety.allow` 前缀白名单。白名单命令**免卡且沙箱外执行**（20:5x 实测：`git-safe-commit.sh` 首用自证，系统横幅 "Sandbox bypassed (escalation-approved)"，提交 7a405e2 零卡片、零锁残留）。此前悬置的"可持续通道形态"就此解决——runner 脚本（run-tests-mutex 系）本就在白名单内，**验证批次不再结构性依赖用户在场点卡**。
- **晨间连挂消解**：09-16 晨"黄金象限连挂"三事件实为两种东西——① 09:45 selfverify **不是挂起**，是旧版 strippedSource 的 UnicodeScalarView 类型错误 ×4 编译失败（自验只跑 swiftc -parse 不做类型检查 → 误报"就绪"；教训：自验至少 -typecheck）；② 10:23 与 09:03（Checkmate+PatternRecognizer）为真挂起，与系统环境劣化窗重合（testmanagerd PID 3886 自开机累积 2.5 天 + swap 9.3→11G 近满 + load 2.74→6.46 爬升）。12:16 击杀旧 testmanagerd 后 load 6.46→4.03 回落，launchd 已拉起干净实例。**环境轴因素不动摇四象限表**。
- **销单条件解锁**：终局三套件批（CheckmateSearch 第二数据点 + PatternRecognizer 补跑 + V64C2 修正版验证）经白名单 runner 免卡执行，结果回填后销单。

### 销单记录（2026-09-16 21:0x-21:1x，Luke）

**终局三套件批全绿**（白名单通道 `scripts/run-tests-mutex.sh`，RUNNER_OWNER=luke，旗标同带，暖 DD，前台逐套件）：

| 套件 | 结果 | 日志 |
|---|---|---|
| V64C2LayoutTests（77b2894 修正版） | ✅ 5 tests passed, 0.063s | ~/DevTeam/logs/final0916-V64C2.log |
| CheckmateSearchTests（第二数据点） | ✅ 4 tests passed, 0.045s | ~/DevTeam/logs/final0916-CheckmateSearch.log |
| PatternRecognizerTests | ✅ 4 tests passed, 0.004s | ~/DevTeam/logs/final0916-PatternRecognizer.log |

- CheckmateSearch 今晨黄金象限挂起（5m38s）→ 今晚同象限绿：残差确认为环境轴（陈旧 testmanagerd PID 3886 + swap 9.3→11G），非 KI 回归。12:16 击杀旧实例 + launchd 拉新 + 白名单通道 = 全绿组合。
- **闭案口径**：Cody #7 七套件（09-16 晨 6 绿 + Phase2b 实名双套件今晚绿）+ Eric #8 三套件（09-16 晨绿）+ 今晚三套件 = 补验队列全绿。本 KI 转 RESOLVED-CLOSED。
- 遗留观察项（不阻塞）：① runner `scripts/run-tests-mutex.sh` 执行位曾丢（16:31 编辑事故，已修）；② 环境卫生纪律新增：长跑批前查 testmanagerd 实例龄与 swap 水位（已写入执行纪律 #3）。

### 执行纪律（修正版，覆盖前文"处置与纪律"）

1. `xcodebuild test` 必须**前台 + 沙箱豁免**（确认 "Sandbox bypassed" 横幅；白名单前缀命中即等效）；禁止 run_in_background 跑测试批
2. 宏旗标 `OTHER_SWIFT_FLAGS='-Xfrontend -disable-sandbox'`：**预热与测试调用一律同带**（Tina 09-16 指纹一致性裁定）——旗标是构建设置、参与构建指纹，预热带/测试不带 = 指纹不匹配 → xcodebuild 判产物过期 → 全量重编 → 宏 flake 回归（09-15 晚 worktree 三套即此死法）。旗标语义务=禁 Swift 编译器子进程沙箱，沙箱外无害（无编译时 no-op，有编译时防 flake）。前版"暖 DD 测试阶段可省"作废。
3. 挂起复发时第一检查项：执行环境四象限定位（沙箱内/外 × 前/后台）→ **次查 testmanagerd 实例龄与 swap/load**（09-16 晨教训：陈旧 testmanagerd + swap 近满可致沙箱外也挂）→ 再查其他

### 由此获得解释的既往反常

- 整机重启无效（重启换不掉沙箱）｜env -i 无效（仍在沙箱内）｜新用户态隔离无效（今晚两轮行为零变化）
- build 恒绿（不需要宿主握手）｜直 exec 正常（不需要 xctest 回连）
- KI 始发 09-13 = 团队测试批全面由沙箱化代理会话发起的时点
- `OTHER_SWIFT_FLAGS='-Xfrontend -disable-sandbox'` 的历史"必要性"同为沙箱伪装（治的是 `~/.swiftpm/security` 拦截；沙箱外无旗标亦绿）

### 排除链八项的重新解读

八项实验全部真实有效，但全部在沙箱内执行 → 对"沙箱"这一共同变量盲。09-14 归因"Xcode 工具链持久层"作废；招③（重装 Xcode 三级清单）作废不执行；招②（test-ki 账户分岔）被今晚的用户态隔离等效实验替代，无需执行。

## 处置与纪律（2026-09-15 起，修正版见上方"补录修正"节，以修正版为准）

1. **一切 `xcodebuild test` 必须前台 + 沙箱豁免执行**（确认豁免横幅）——写入 DEVTEAM.md 测试铁律；后台任务豁免不继承，禁止后台跑测试批
2. `OTHER_SWIFT_FLAGS` 旗标：冷编译必带（编译器自身沙箱，与代理沙箱独立）；暖 DD 测试阶段可省
3. KI 单销单条件：补验队列全绿（见下），随后本单转 RESOLVED-CLOSED

## 解除条件（48h 时钟自补验批起跑）

测试通道恢复（上述任一验证手段生效）后 **48h 内**补跑补验队列，全绿即销本单并回填验收记录：

- Cody #7 剩余 7 套件（主仓 b3fa0a7）
- Eric #8 三个 V64 套件（worktree 8077dc0：V64C0LayoutTests 等已绿者免）

## 证据索引

- 排除链全程日志：`~/DevTeam/evidence/v64c2-alpha3-verify/`（RESTART-PENDING.md 含接手便签与索引）
- 根因破案对照日志：`~/DevTeam/workdirs/logs/h1/PlayerColorTests-231732.log`（沙箱外绿）与 `PlayerColorTests-225348.log`（沙箱内挂，同夜同机）
- 最后一搏探针日志：`~/DevTeam/logs/v64c2/PlayerColorTests-finalprobe.log`
- p4-1920 终版：worktree `docs/design/prototypes/v64c2-anchor-shots/p4-1920-final-postreboot.png`（3.4MB）+ `p4-1920-recap-note.md`（含误诊链修正）
- P3 复查截图：`p3-1920-opena-postreboot.png`
- 持久化脚本：`~/DevTeam/scripts/`（run-tests-mutex-v64c2-wt.sh / run-tests-mutex-bisect-6e38573.sh / capture-p4-1920.sh / queue-cody-eric-recap.sh）

## 归因演进史（保留供审计）

- ~~09-14 终态归因：Xcode 工具链自身的持久层（最可疑 /var/folders XPC 缓存）~~ → **作废**（09-15：该层已被隔离实验证伪，沙箱外绿）
- 招①无效（被动排除）→ 招②（test-ki 账户）被用户态隔离等效实验替代并作废 → 招③（工具链修复三级清单）作废

## 现象

任何 `-skip-testing:EloBaselineTests` 的测试运行（`bash scripts/run-tests-mutex.sh` 主仓通道 / `~/DevTeam/scripts/run-tests-mutex-v64c2-wt.sh` worktree 通道，含宏旗标 `OTHER_SWIFT_FLAGS='-Xfrontend -disable-sandbox'`）在 7m20s+ 后超时报 `hung before establishing connection`。测试宿主进程未与 xctest 建立连接。

## 排除链（09-13 ~ 09-14，八项，全部成立）

| # | 假设 | 实验 | 结论 |
|---|------|------|------|
| 1 | 代码回归 | bisect 回 last-green 6e38573 | 仍挂 ✗ |
| 2 | LS 数据库内容污染 | 134 条路径清至 1 | 仍挂 ✗ |
| 3 | 用户态 lsd 坏态 | kill/respawn | 仍挂 ✗ |
| 4 | root 进程态累积 | 整机重启 | 仍挂 ✗（重启换新仍复现） |
| 5 | 会话环境污染 | `env -i` 干净环境跑 | 仍挂 ✗ |
| 6 | app 二进制自身 | 直 exec 启动正常 | 二进制无罪 ✓ |
| 7 | xcodebuild→host 建连通道 | 探针通过 | 通道可达 ✓ |
| 8 | 残留进程/AppleLanguages 注入 | 全杀 xctest/host/XCBBuildService + 清注入（09-14 08:0x 最后一搏，PlayerColorTests 探针） | 仍挂 7m23s ✗ |

## 终态归因

重启（假设 4）与干净环境（假设 5）都换不掉的坏态，指向 **Xcode 工具链自身的持久层**（最可疑：`/var/folders` 下缓存的 XPC 服务注册 / XCBBuildService 派生数据残留），而非项目代码或用户会话。

**待验证手段（按代价升序）**：① 清 DerivedData + `/var/folders/zz` XPC 缓存重启；② 新建用户账户跑同一命令（隔离用户级持久态）；③ Xcode/CLT 重装。

### ① 执行记录（Tina 2026-09-14 08:2x，部分执行）

- ✅ `/tmp/xc-mutex-dd`、`/tmp/v64c2-dd` 已清空（DerivedData 自有目录）
- ⛔ `~/Library.../C/com.apple.dt.*`（Xcode/xcodebuild/IDECacheDeleteAppExtension 等 5 项用户级 dt 缓存）：**用户在权限确认时明确拒绝删除**（sandbox 提示"Do NOT retry or attempt equivalent delete alternatives"）——已遵守，未重试
- ⛔ `/var/folders/zz/*/xpc`（系统级 XPC 缓存）：sudo 被工具环境硬拦（`operation not permitted: sudo`，与 09-13 记录一致）——按纪律跳过并记录
- ⏸ 重启：需用户手动执行（本会话无 sudo 无法 `reboot`）
- 探针未跑：①的三要素（dt 缓存清 + zz 清 + 重启）只完成 1/3，且今晨 06:51 全新 DD 构建后探针仍挂（等价于"仅清 DD"对照已做过），单跑无增量信息。**等用户对 dt 缓存删除/重启表态后再续**

### ① 续：放行后执行（Tina 2026-09-14，洪涛风险评估通过、Luke 转达）

- 前置检查：Xcode/Xcodebuild/XCBBuildService 进程全部已退（pgrep 空）
- **删除结果（意外发现）**：五项中四项**已不存在**——`com.apple.dt.Xcode`、`com.apple.dt.xcodebuild`、`com.apple.dt.IDECacheDeleteAppExtension`、`com.apple.dt.InstrumentsCLI` 在本轮检查时均已 absent（系统自行清理或 06:43 重启时清除）。这四项正是 KI 归因的核心嫌疑载体，**实质上已被清空**。
- 第五项 `com.apple.dt.CommandLineTools.installondemand`：再次被拒（safe-delete bulk guard 触发 + 用户拒绝）。该项为 CLT 安装器按需数据，与 test host 挂起无关，不重试。
- **招①"用户级 dt 缓存清理"实质已达成**（系统代劳）。剩余要素：zz xpc（sudo 拦，跳过记录在案）+ 重启（待洪涛手动）。

### ① 裁决：无效（Luke 2026-09-14，依据 Tina 被动排除推理）

06:43 重启 + dt 缓存四项 absent 的组合**已被被动测过且探针仍挂**（08:0x PlayerColorTests 5m30s 挂起）——再重启信息增量为零。招①关闭，转招②。

### ② 状态：清单就位，等洪涛 GUI 执行（Tina 2026-09-14）

- 清单：`~/DevTeam/evidence/v64c2-alpha3-verify/KI-move2-test-ki-checklist.md`（建户/登入/一行探针/权限预检/判读口径/事后清理全流程）
- 权限预检（test-ki chmod）Luke 已代做
- 判读：**绿** = 坐实 hth 用户级 Xcode 服务注册坏态 → 修复 = 重置 hth 账户 com.apple.dt.* 服务注册（比招③便宜一级）；**挂** = 转招③

### ③ 预置：工具链修复清单已备（Tina 2026-09-14 13:50，招②挂了即用）

- 清单：`~/DevTeam/evidence/v64c2-alpha3-verify/KI-move3-toolchain-repair-checklist.md`（3a 缓存重建 → 3b 原地修复安装 → 3c 完整重装+用户级 Xcode 状态重置，每子级后探针，绿了即停）
- 本机工具链事实（已核实）：Xcode 26.3 (17C529) 单实例、开发者目录指向完整 Xcode、CLT 26.3.0.0.1 与 Xcode 同源共存、无备用 toolchain——**`xcode-select --install` 重装 CLT 无意义（真身在 Xcode 内），直接走 3a→3b**

## 影响与处置（决策矩阵裁决，Luke 2026-09-14）

| 事项 | 裁决 | 依据 |
|------|------|------|
| Cody #7（主仓 4 commits：5204dce / 42e42c5 / 974b5c4 / b3fa0a7） | **延期验收**（代码面证据足额，运行时补验挂账本单） | Ruby 增量审通过（P1×1 转卫生批、P2×4 入库）；绿窗内 7 套件绿 |
| Eric #8（worktree 8077dc0 + 主仓 bcc0fbc） | **延期验收**（同上） | Ruby 增量审通过；双构建门绿；p4-1920 锚图形态判别 PASS |
| p4-1920 锚图 | **可验收** | 亮度剖面形态判别达标（最暗10%行 33.6 vs 参照 31.3；最亮10%行 123.4 vs 125.3），与 p4-1280 结构一致 |
| P3 harness「启动链不触发」 | **撤回**（非代码问题） | 09-13 直 exec 通道绕过 LaunchServices 激活，AppDelegate 启动链本就不触发——采集通道方法论错误，Eric 的 8077dc0 无需修改；正确口径 = `open -a` + env 前缀（Eric 原脚本即正确） |

## 解除条件

测试通道恢复（上述任一验证手段生效）后 **48h 内**补跑补验队列，全绿即销本单并回填验收记录：

- Cody #7 剩余 7 套件（主仓 b3fa0a7）
- Eric #8 三个 V64 套件（worktree 8077dc0：V64C0LayoutTests 等已绿者免）

## 证据索引

- 排除链全程日志：`~/DevTeam/evidence/v64c2-alpha3-verify/`（RESTART-PENDING.md 含接手便签与索引）
- 最后一搏探针日志：`~/DevTeam/logs/v64c2/PlayerColorTests-finalprobe.log`
- p4-1920 终版：worktree `docs/design/prototypes/v64c2-anchor-shots/p4-1920-final-postreboot.png`（3.4MB）+ `p4-1920-recap-note.md`（含误诊链修正）
- P3 复查截图：`p3-1920-opena-postreboot.png`
- 持久化脚本：`~/DevTeam/scripts/`（run-tests-mutex-v64c2-wt.sh / run-tests-mutex-bisect-6e38573.sh / capture-p4-1920.sh / queue-cody-eric-recap.sh）

## 附录 C：sandbox_guard 探针假阴性（2026-09-17 实测数据点）

Tina 两次实测（13:14 / 15:18）均为「OPENCLAW_* 环境标记阴性 + 会话实际在沙箱内 → 挂」：
guard 靠 env 标记判代理会话存在 **假阴性盲区**——标记 0 ≠ 非沙箱。Cody 注释自述「shell 层无可靠
seatbelt 签名」属已知局限，本次拿到两个实测反例数据点。

**判定纪律修正**：guard 放行 ≠ 非沙箱；实际判定以运行结果/授权拒绝为准（用户显式拒绝
~/.swiftpm/security 路径 = 会话在沙箱内的直接证据）。不改变 KI 主根因结论（环境轴），仅探针精度注记。
