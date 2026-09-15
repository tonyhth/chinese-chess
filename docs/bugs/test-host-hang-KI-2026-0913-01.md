# Known Issue：测试宿主挂起（xcodebuild test 全通道 hung before establishing connection）

- **编号**：KI-2026-0913-01
- **状态**：RESOLVED（根因已锁定：代理会话沙箱；2026-09-15 23:2x Luke 破案，销单条件见文末）
- **登记**：Luke 2026-09-14 08:15（收口裁决日）；首发现 2026-09-13；根因改判 2026-09-15 23:2x
- **影响范围**：本机全部 xcodebuild test 运行（主仓 m1 与 worktree 双通道）；不影响 xcodebuild build、直 exec、screencapture、screenshot 采集

## ✅ 根因（2026-09-15 23:2x 破案，Luke）

**代理会话沙箱阻断测试宿主建连。** xcodebuild 经 LaunchServices 拉起测试宿主后，沙箱策略随进程树继承到宿主进程，宿主回连 xctest 所需的文件/Mach 操作被拒 → 挂起至超时。日志佐证：挂起轮的最后一次成功操作恒为 lsregister（LS 注册），随后 321s 静默；每轮沙箱内探针 stderr 恒见 `~/.swiftpm/security (file-write-unlink)` 拦截。

### 决定性对照实验（2026-09-15 晚，同命令同机同用户态）

| 轮 | 执行环境 | 宏旗标 | 结果 |
|---|---|---|---|
| 09-13 起蒂娜全部探针 + 今晚 22:53 / 23:03（用户态全隔离两轮） | 沙箱内 | 有 | 🔴 挂（7m20s+ 同指纹） |
| 今晚 23:17 / 23:19 | **沙箱外**（escalation-approved） | 有 / 无 | 🟢 **TEST SUCCEEDED ×2** |

### 由此获得解释的既往反常

- 整机重启无效（重启换不掉沙箱）｜env -i 无效（仍在沙箱内）｜新用户态隔离无效（今晚两轮行为零变化）
- build 恒绿（不需要宿主握手）｜直 exec 正常（不需要 xctest 回连）
- KI 始发 09-13 = 团队测试批全面由沙箱化代理会话发起的时点
- `OTHER_SWIFT_FLAGS='-Xfrontend -disable-sandbox'` 的历史"必要性"同为沙箱伪装（治的是 `~/.swiftpm/security` 拦截；沙箱外无旗标亦绿）

### 排除链八项的重新解读

八项实验全部真实有效，但全部在沙箱内执行 → 对"沙箱"这一共同变量盲。09-14 归因"Xcode 工具链持久层"作废；招③（重装 Xcode 三级清单）作废不执行；招②（test-ki 账户分岔）被今晚的用户态隔离等效实验替代，无需执行。

## 处置与纪律（2026-09-15 起）

1. **一切 `xcodebuild test` 必须沙箱外执行**（用户本地终端，或代理会话中逐次申请沙箱豁免）——写入 DEVTEAM.md 测试铁律
2. `OTHER_SWIFT_FLAGS` 旗标仅沙箱内需要，沙箱外不传（避免宏旗标常态化污染）
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
