# DEVTEAM.md — 中国象棋项目开发规范

> 本文件是 chinese-chess 项目的开发规范，所有 agent 在本项目工作前**必须先读此文件**。
> 规范仅适用于本项目，不影响其他项目。

---

## Git 规范

### ⚠️ Phase 完成必须提交（铁律，零例外）

**每个 Phase 代码定稿后，Cody 必须 commit + tag。不允许攒多个 Phase 一起提交。**

- Cody 完成编码 → Ruby 审查 → Tina 测试 → **Luke 验收时确认 git 有新 commit**
- commit message 格式：`feat(phase-X): <描述>` 或 `fix(phase-X): <描述>`
- 版本发布时打 tag：`v<major>.<minor>.<patch>`
- 打包前必须确认版本号与最新 tag 匹配

**为什么这是铁律**：v3.8.2→v5.0.1 的 86 个文件变更全部未提交，导致：
1. 无法 git diff / git bisect 定位回归 bug
2. 无法回退到已知正常版本
3. 代码变更与版本号无法对应

**Luke 验收检查清单增加**：
```
git log --oneline -3   # 确认 Phase commit 存在
git diff --stat        # 确认 working tree 干净
```

### 提交粒度
- 按**功能模块**拆分 commit，不混合无关改动
- commit message 格式：`<type>(<scope>): <描述>`
  - type：feat / fix / refactor / chore / test / docs
  - scope：phase-a / phase-b / engine / ui / build 等
  - 示例：`feat(phase-a): add precompiled Pikafish static library + modulemap`
- 一个 commit 只做一件事，能独立通过编译

### 禁止提交的文件
- `.build/` `*.build/` `.build-release/` — SPM/Xcode 构建产物
- `*.o` `*.a` `*.profraw` — 编译中间产物和静态库（.a 由 build.sh 生成，不入 Git）
- `*.app/` — 打包产物
- `DerivedData/` — Xcode 缓存
- `data/` — PGN 训练数据（体积大，非源码）
- `ChineseChess-iOS/` — iOS 子项目（独立管理）
- `docs/` `*.md`（除 README.md）— 文档通过 .gitignore 排除
- `debug.log` `training.log` — 日志文件

### .gitignore 维护
- 新增构建产物类型时，同步更新 `.gitignore`
- 如果 `git status` 出现不应跟踪的文件，先加 .gitignore 再处理

---

## 构建规范

### 构建验证命令（v3.5.0 起，统一 xcodegen）
- **主构建**：`cd ~/DevTeam/projects/chinese-chess && xcodegen generate && xcodebuild -target ChineseChess -configuration Debug build`
- **Release 构建**：`cd ~/DevTeam/projects/chinese-chess && xcodegen generate && xcodebuild -target ChineseChess -configuration Release build`
- **⚠️ 不再使用 `swift build` / `swift test`**（Package.swift 已删除，SPM 已废弃）

### ⚠️ 测试命令（铁律）
- **起跑前预检（2026-08-16 起，基线污染单2）**：`~/DevTeam/scripts/preflight-test-assets.sh <worktree根>`——四类 gitignored 资产（nnue / Pikafish 引擎 / data JSON / Accessibility 源）缺一即退出码 3 终止，不烧批次；隔离 worktree 必跑（资产不随 git 走，dc4653d §五.2 实证四轮补资产的学费）
- **Test run 计数与基线比对 = 常规门规（2026-08-16 起）**：每测试批 Test run 总数与比对锚核对——**锚 = 同 commit 预期起跑数**（套件清单变更只走 docs commit 同步更新，禁运行时自适应锚）；**缺口 = 批次作废（hard fail）**非警告；误报处置序 = 先查环境再查清单，不允许补录豁免
  - 背景：`.disabled` 静默性双向刃（对 CI 不可见，任何人静默 disable 用例同样无痕——dc4653d 三跑实录是运气不是机制）+ 本版 swift-testing xcresult `skippedTests` 恒 0（verify4 实测）→ Test run 总数缺位 = 唯一可见信号
  - 谱系呼应：与 aa35f46 存量对账账目同源——静态账目 vs 动态起跑数，同一对账原则的运行时延伸
- **禁止全量 `xcodebuild test`**（不带过滤参数）— Intel Mac 必定超时
- **必须用** `xcodebuild test -skip-testing:EloBaselineTests`
- 专项测试：`xcodebuild test -only-testing:<TestClassName>`
- EloBaselineTests 是自对弈 5 局 × 30+ 分钟，会锁死构建目录

### iOS 编译门禁（Phase 合入前必跑）

```bash
cd ChineseChess-iOS  # ⚠️ iOS 工程在子目录（主区 project.yml 是 macOS 的）
xcodegen generate     # ⚠️ 新增源文件必先 regenerate，否则新文件不进 iOS target（P2c 教训：新增 .swift 后 iOS 报 cannot find type）
xcodebuild build -project ChineseChess.xcodeproj -scheme ChineseChess \
  -configuration Debug -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/ios-gate-dd
```

- 检出 macOS 专属 API 裸用（AssessmentView :209 教训：phase 功能从未在 iOS 编译过）
- 无签名/无设备依赖，任何环境可跑；DerivedData 独立路径不与主构建互踩
- ~~project.yml 为磁盘态配置（gitignored，勿 commit），由 xcodegen 维护~~ **更正（2026-08-16，与 worktree 侧 f0a335b 同款）**：root project.yml 与 ChineseChess-iOS/project.yml 均 **git 跟踪**（可且应 commit）；gitignored 的是生成的 **xcodeproj** 磁盘态——验证 commit 态勿信残留，**regenerate 后再跑**
- ⚠️ **错误跑法警示**：主工程 ChineseChess.xcodeproj 仅 macOS——直接对它跑 `generic/platform=iOS` 报 "Unable to find destination" / 先兆 "Supported platforms is empty"。必须 cd ChineseChess-iOS 按上块跑

### 测试 env 传参规范（2026-08-16，P2c 踩坑落档）

**env 直传不进 xcodebuild 测试进程**：`env FOO=1 xcodebuild test` 的 FOO 在测试内 `ProcessInfo.processInfo.environment` 读不到（xcodebuild 不透传给 test runner）。

正确姿势：**`TEST_RUNNER_` 前缀**，xcodebuild 自动剥前缀后注入测试进程：
```bash
TEST_RUNNER_MOVEGEN_CROSSCHECK_FULL=1 xcodebuild test -scheme ChineseChess \
  -only-testing:ChineseChessTests/MovegenCrosscheckTests -destination 'platform=macOS'
```
首跑教训：直传导致 FULL 批以默认规模静默假跑（715 局面 full=false），白烧一轮。同族陷阱与 `-only-testing` 过滤器漏写同源：**派单命令从本文件复制，不凭记忆**。

### USE_SEARCHBOARD_V2 开关跑法（P2c-②，v1.2 §7.4）

```bash
# flag-off（默认，Legacy 路径）——直接跑，无需任何参数
xcodebuild test -scheme ChineseChess -only-testing:ChineseChessTests/M1HotpathSwitchTests \
  -destination 'platform=macOS' -derivedDataPath /tmp/xc-p2c-dd

# flag-on（V2 路径，P5 验收/双态复核用）——OTHER_SWIFT_FLAGS 传编译条件
env OTHER_SWIFT_FLAGS='-DUSE_SEARCHBOARD_V2' xcodebuild test -scheme ChineseChess \
  -only-testing:ChineseChessTests/M1HotpathSwitchTests -destination 'platform=macOS' \
  -derivedDataPath /tmp/xc-p2c-dd

# 切回 Legacy = 去掉 env 前缀重跑（编译条件默认 off，无需改码）
```

⚠️ flag 与 TEST_RUNNER_ 前缀同族风险：OTHER_SWIFT_FLAGS 凭记忆重敲 = 假跑。双态复跑一律未本块复制。

### 编译检查频率
- 每修改 3-5 个源文件后执行一次 `xcodebuild build`
- 不要攒一大堆改动最后才编译

---

## Pikafish 引擎规范

### NNUE 嵌入
- `-DNNUE_EMBEDDING_ON` 是**无效参数**，pikafish 不支持编译时 NNUE 嵌入
- NNUE（`pikafish.nnue`，48MB zstd）作为独立文件打包到 **App Bundle Resources**
- 运行时由 `pikafish_api.cpp` 通过 `CFBundleCopyResourcesDirectoryURL` 加载
- 删除 NNUE 文件 = 引擎废掉，**禁止删除或移动**

### 静态库
- 预编译 `.a` 文件由 `Pikafish/build.sh` 生成，不入 Git
- 路径约定：`Pikafish/lib/<platform>/libpikafish.a`
- 不同架构的 .a 文件不混用，按目录隔离

### 许可证
- Pikafish 采用 GPLv3，静态库链接方式，无 App Store 上架法律障碍
- 不修改 Pikafish 源码，只通过 C API 调用

---

## 文档规范

### 目录结构
```
docs/
├── design/          — 设计文档
├── spikes/          — 技术调研
├── reviews/         — 审查记录
├── guides/          — 使用指南
├── user-guide/      — 用户文档
├── bugs/            — Bug 记录
├── general/         — 通用文档
└── v3.x/            — 按版本归档
```

### 命名规则
- Phase 文档：`v3.x.0-phase-<name>.md`
- 调研文档：`<topic>-investigation.md` 或 `<topic>-evaluation.md`
- 归档文档放入对应版本子目录（如 `v3.1/`）

---

## 打包规范

### 输出路径
- macOS：`~/DevTeam/projects/chinese-chess/中国象棋-v<version>.app`
- **永不输出到桌面**

### 必须检查项
1. 资源完整性（字体 + 音效 + 开局库 + NNUE）
2. 图标正确生成并嵌入
3. Info.plist 版本号正确
4. i18n：Localizable.xcstrings 在 bundle 路径下可被读取

---

## 版本号管理

- 主版本号：`v<major>.<minor>.<patch>`（如 v3.4.0）
- Phase 完成后由洪涛决定是否升级版本号
- 打包前确认 `Info.plist` 中的 `CFBundleShortVersionString` 和 `CFBundleVersion` 一致

### 版本边界记录

v3.8.2 之前的版本边界可通过 commit hash 定位（无需补打 tag）：

| 版本 | Commit | 依据 |
|------|--------|------|
| v3.0.0 | 20f5d91 | Phase 8 P2最后修复 |
| v3.1.0 | cbcb481 | Phase 2c P1返工完成 |
| v3.5.0 | 7a83e84 | v3.5.0 最后提交 |
| v3.6.0 | 532e332 | bump version to 3.6.0 |
| v3.7.1 | a422afc | v3.7.1 最后提交 |
| v3.8.1 | bedac52 | 标注 v3.8.1 |
| v3.8.2 | 24edac1 | 标注 v3.8.2 |

**⚠️ v4.0.0 ~ v5.0.0 边界合并说明**：这三个版本的代码变更合并于 commit ccacebe (2026-07-11)，版本间差异无法通过 git diff 追溯，需参考 docs/ 下的设计文档。

### 丹妮 Phase 验收门禁

验收 Phase 时额外检查：
```
git log --oneline -3   # 确认 Phase commit 存在
git diff --stat        # 确认 working tree 干净
```
working tree 不为空 → 不算验收通过。

## 工作区与并行协作（2026-08-16 起，7 人团队）

### 工作区划分（线级隔离）
- **主树**（~/DevTeam/projects/chinese-chess，m1 分支）：Cody 专用（M1 引擎线 P2-P5）
- **/tmp/v62-wt**（v6.2 分支 worktree）：Eric（布局+HIG UI 修复）与 Tina（断言清偿验证批）共享
- worktree 重建后必须重新 rsync gitignored 资产（ChineseChess-iOS/ + data/ + src/ChineseChess/Pikafish/，清单见 deploy-ios.sh）

### 共享 worktree git 卫生（v62-wt 双人期间）
1. `git add` 只按具体文件路径，**禁止 -A / -u**（防误收对方 WIP；2026-08-15 git 手术 add -A 教训）
2. commit 前自查：`git diff --cached --name-only` 只含自己的文件
3. 遇 `index.lock`：等 10s 重试，不删锁
4. 文件面分工：Eric→Views/ 新增实现+新建测试；Tina→ChineseChessTests/ 存量重写

### worktree 拆分触发（预登记，双门槛）
- 条件：Tina 断言批与 Eric 布局重叠 >2 天 **且** 锁冲突/误收事故 ≥1 次
- 动作：Tina 迁独立 worktree（v6.2-tests 分支，Luke 定期合并）；迁移时带上 fixture 资产清单（批次新造 fixture 可能引用 data/ 路径）
- 依据：断言批=收敛型任务（批次结束设施即废），布局=生长型任务（Eric 长期驻地）——不为收敛型建永久设施

### 合并仲裁（单口原则）
- **所有跨分支合并归 Luke**：v6.2→main、m1→main、（若拆分）v6.2-tests→v6.2
- Eric/Tina/Cody 只 commit 不 merge——双头合并是 2026-08-15 手术场景的种子

### Eric 首日验证清单（2026-08-16 执行）
- 飞书群 bot 路由实测（Danny bot 230002 前鉴）
- HIG P1-1 练手单全升级链走真：编码→Ruby 审→Tina 验
- HIG P1-1 的 alert 文案过 Vera 增量 HIG 对照（触发式 HIG 规约首例实践）
