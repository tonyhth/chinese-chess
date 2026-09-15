# p4-1920 重采集结果（Tina #10, 2026-09-13 22:41 → 9-14 06:30 修正）

## 结论
**PARTIAL FAIL** —— 1920 宽布局投递未生效（窗口仍是默认尺寸），P4 sheet 未 attach。

## 证据
- 截图：`p4-1920-partial-tina.png`（3.74MB，截到了主窗 + 棋盘，右侧无 sheet；右侧 crop 见 `p4-right-crop-sm.png`）
- stdout 日志：`/tmp/p4-1920-harness.log`（含 pikafish_init success；**LAYOUT_DUMP dump_count=0**）
- 启动方式：`$APP_BUNDLE/Contents/MacOS/ChineseChess` 直 exec（env 经 ProcessInfo 天然继承，POSIX 语义保证），配套 `open -a` + osascript 强制前台
- 环境送达验证：`ps eww` 在 macOS 受限（控制实验：`/bin/sleep` 带 env 同样不显示），故 ps eww 法不可用；env 通过 POSIX fork+exec 继承，理论送达

## 失败根因分析（已三段递进修正）

### 第一段（早前误诊，已废）
~~worktree data/ 目录无 puzzle 数据~~ —— 错。puzzles.json 在 `src/ChineseChess/Resources/Puzzles/puzzles.json`，且已打包进 app bundle（`Contents/Resources/puzzles.json`，find 验证存在）。

### 第二段（仍误诊，已废）
~~PuzzleDemoView:63 的「列表缓存就绪才进、未就绪静默跳过」~~ —— 部分对，但**前置条件「窗口 onAppear 触发 activeSheet = .harnessPlay」未发生**，sheet 根本没 attach，自然无所谓列表缓存。

### 第三段（当前结论）
**主窗 onAppear 未把 activeSheet 置为 .harnessPlay("puzzle")。** 实证：
- 截图右半部显示窗口本身是普通尺寸，**非 1920 宽**——AppDelegate 的 `applicationDidFinishLaunching` 内 LAYOUT_WIDTH 钉宽也没生效
- dylib `strings` 验证 DEBUG 代码全在：`LAYOUT_DUMP`、`LAYOUT_WIDTH`、`LAYOUT_PLAY`、`LAYOUT_DUMP {`、`harnessPlay`、`harnessPlay-` 字面量均在 `ChineseChess.debug.dylib` 中存在
- 编译配置 -D DEBUG 已定义（对照 xcodebuild 输出可见 `-Onone -D DEBUG`）
- 故构建正确，env 应送达，**未生效只剩 app 启动期 sheet/state 阻塞**

### 可能的根因（按概率）
1. `activeSheet` 在窗口 onAppear 触发时**非 nil**（被 tutorial/first-launch dialog/review card/some other sheet 抢占）
2. 主窗 onAppear 因视图层级问题未在 75s 内 fire（理论上窗口首 frame onAppear 同步触发）
3. onAppear 触发后 activeSheet 被另一段代码立即置 nil
4. 直 exec 启动绕过 LaunchServices，某个 NSApplicationDelegate 钩子因此不触发

## 屏幕限制（重启后需注意）
- 逻辑分辨率 1536×960（Retina 3072×1920）
- 1920 宽窗口超过屏幕逻辑宽度；AppDelegate 钉宽后窗口会超屏右侧，sheet 渲染也受影响
- 即使 harness sheet attach 成功，截图可能只截到部分 sheet

## 给重启后接手 Tina 的建议
- 重启后**优先用 LAYOUT_PLAY=master（P3 无 category gate，最直接验证 harness）做对照**：跑 `~/DevTeam/scripts/capture-p4-1920.sh`（注意：此脚本当前用 `open -a` + env 前缀，直 exec 路线在本会话实证更稳；可参考 `/tmp/p4-envtest2.sh` 改写）
- 若 P3 sheet 出现、P4 不出 → 是 PuzzleDemoView 进入条件 bug（cachedListItems 必须 selectedCategory 非空才填充），转 Eric 修
- 若 P3 也未出 → harness onAppear 未 fire 的根因更广，转 Eric + 主程排查
- 若 env 也未达 → 改用 `osascript` 的 `tell application "Xcode" to launch` 不如直 exec，**直 exec 是最稳通道**（本会话实证）

## 当前能交付的部分
- 1920 宽布局「**主窗 + 棋盘**」形态（无 P4 sheet）：`p4-1920-partial-tina.png` 可作 fallback 锚图
- harness 进入条件源码层结论（cachedListItems 需 selectedCategory 非空）

## 下一步
- 不再做无依据的重采尝试——根因需重启后在新环境核实，文档化移交即可
- 重启后补验口径见 `~/DevTeam/evidence/v64c2-alpha3-verify/RESTART-PENDING.md` 第 4 节
---

## 2026-09-14 08:07 终版（post-reboot, open -a 通道）——**PASS（形态判别通过）**

**结论修正：p4-1920 重采成功。** 此前多轮失败根因是**我的采集通道错误**（直 exec 绕过 LaunchServices 激活，AppDelegate/NSApplication 启动链未触发），非 app/harness 代码问题。

**终版采集方式**：`LAYOUT_WIDTH=1920 LAYOUT_PLAY=puzzle LAYOUT_DUMP=1 open -a <Debug.app>`（env 前缀 + LaunchServices 激活，与 09-05 锚图同通道）→ 70s → screencapture。

**形态判别（客观，全分辨率右栏行剖面）**：
| 指标 | p4-1280 正确形态参照 | p4-1920-final 待判 | 判定 |
|---|---|---|---|
| 最暗 10% 行灰度 | 31.3 | 33.6 | 暗底一致 |
| 最亮 10% 行灰度 | 125.3 | 123.4 | 亮顶一致 |
| 行中位数 | 56.7 | 70.7 | 同量级 |

右栏结构（三 tab / 走法列表 / 进度条 / 控制条）与 p4-1280 形态一致。

**文件**：
- 终版：`p4-1920-final-postreboot.png`（3.4MB，3072×1920）+ `p4-1920-final-postreboot-sm.png`
- P3 同通道佐证：`p3-1920-opena-postreboot.png`（P3 sheet 正常挂载、三 tab 可见）

**历史误诊链修正**（避免接手者再踩）：
1. ~~worktree data/ 缺 puzzle 数据~~ → puzzles.json 一直在 src/ChineseChess/Resources/Puzzles/ 且已打包
2. ~~harness onAppear 未触发是代码 bug~~ → 直 exec 才不触发；`open -a` 通道一切正常
3. 昨晚报「转 Eric 排查」撤回——**不是代码面问题**，是我的采集通道方法论错误

**给 Eric 的口径**：harness 无需修改。锚图采集一律用 `open -a` + env 前缀（Eric 原脚本 /tmp/capture-p4-1920.sh 的方式本来就是对的）。
