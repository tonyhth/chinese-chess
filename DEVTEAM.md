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
- **禁止全量 `xcodebuild test`**（不带过滤参数）— Intel Mac 必定超时
- **必须用** `xcodebuild test -skip-testing:EloBaselineTests`
- 专项测试：`xcodebuild test -only-testing:<TestClassName>`
- EloBaselineTests 是自对弈 5 局 × 30+ 分钟，会锁死构建目录

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
