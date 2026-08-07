# macOS Sidebar 构建路径差异分析

> 角色：Alex（架构师） | 日期：2026-08-10 | 版本：v2.1
>
> 修订记录：
> - v1.0（2026-08-10）出稿。核心结论"v5.5.4 不含 sidebarRow"被 Vera 证伪——nm 搜索确实有 50 个符号
> - v2.0（2026-08-10）Vera v1.0 审查修复：修正 nm 错误数据、推翻场景一、执行 clean build 实验、重写结论
> - v2.1（2026-08-10）Vera v2.0 审查修复：补充签名差异分析、排除可能性 C、增加实验 0（原始观察复现验证）、增加 scheme Release 对照实验

## 背景

丹妮发现：同样代码，两种构建路径产生不同行为：
- `xcodebuild -scheme ChineseChess -configuration Release` → ✅ 文字正常
- `build-release.sh`（xcodegen + `xcodebuild -target ChineseChess -sdk macosx -configuration Release`）→ ❌ 文字不可见

## 调查过程与发现

### 1. Build Settings 对比（Release 配置）

对 `-target ... -sdk macosx ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO`（build-release.sh 路径）和 `-scheme` 路径做了完整的 `showBuildSettings` diff。

**排除所有路径差异（BUILD_DIR / DERIVED_DATA / TEMP_DIR 等）后，实质差异仅 3 项：**

| Setting | Target 路径 | Scheme 路径 | 影响分析 |
|---------|------------|-------------|----------|
| `ARCHS` | `x86_64`（build-release.sh 覆盖） | `arm64 x86_64` | 都是 x86_64，不影响编译结果 |
| `CLANG_COVERAGE_MAPPING` | 未设置 | `YES` | Scheme 自动注入覆盖率插桩，影响二进制大小，不影响布局行为 |
| `SDKROOT` | 显式 `macosx26.2`（`-sdk macosx`） | 隐式推断 `macosx26.2` | 同一 SDK，无实质差异 |

**编译参数完全一致**：SWIFT_OPTIMIZATION_LEVEL=-O, SWIFT_COMPILATION_MODE=wholemodule, GCC_OPTIMIZATION_LEVEL=s（Release 默认）, DEAD_CODE_STRIPPING=NO, SWIFT_VERSION=5.0。

### 2. 二进制对比

Clean build 后两种路径的 Release 二进制：

| 维度 | Target 路径 | Scheme 路径 |
|------|------------|-------------|
| 大小 | 10.9 MB | 15.5 MB |
| 架构 | x86_64 (single) | x86_64 (single) |
| Coverage 符号 | 137 个 | 3,683 个 |
| `__llvm_covfun` section | 无 | 有 (184KB) |
| sidebarRow 符号 | 50 个 | 50 个（+58 个覆盖率变体）|

**大小差异 4.5MB 来自 CLANG_COVERAGE_MAPPING=YES 注入的覆盖率插桩代码。覆盖率插桩不改变 SwiftUI 布局行为。**

### 3. v5.5.4 打包二进制验证

> v1.0 文档声称 v5.5.4 不含 sidebarRow 符号——这是错误的。重新验证确认 **v5.5.4 包含 50 个 sidebarRow 符号**，和 clean target build 一致。

v5.5.4 二进制详情：
- sidebarRow 符号：**50 个** ✅（和 clean build 一致）
- 大小：10,937,776 bytes（和 clean build 10,938,224 差 448 bytes，来自时间戳/路径嵌入）
- 构建时间：Aug 7 09:25（在 sidebar commit `0553daf` Aug 7 08:33 之后）

**v5.5.4 确实包含了 sidebar 改动代码。** 两种构建路径都正确编译了相同代码。

### 4. Clean build 实验

执行了 `rm -rf build/` 后的 clean target build：
- 构建成功，二进制 10.9MB，50 个 sidebarRow 符号
- App 可正常启动
- **sidebar 是否可见无法从命令行确认——需要人工运行 App 检查**

### 5. 资源和配置对比

- App bundle Resources 文件列表：**完全一致**（22 个文件）
- Info.plist：**完全一致**
- 字体文件 LXGWWenKai-Regular.ttf：**完全一致**（25,575,676 bytes）

## 根因判断

### 已排除

| 假设 | 排除理由 |
|------|----------|
| ~~对比时用了不同版本代码~~ | v5.5.4 含 50 个 sidebarRow 符号，代码正确 |
| ~~编译参数差异~~ | SWIFT_OPTIMIZATION_LEVEL、SWIFT_COMPILATION_MODE 等完全一致 |
| ~~资源/字体/Info.plist 差异~~ | 完全一致 |
| ~~CLANG_COVERAGE_MAPPING 导致布局差异~~ | 覆盖率只加数据段，不改布局逻辑 |
| ~~working tree 未提交改动~~ | `git status` 确认只有 ChineseChess-iOS/project.yml（与 sidebar 无关）和本文档 |

### 签名差异（已发现，待验证影响）

v5.5.4 打包产物和 xcodebuild 直接产出的签名状态不同：

| 维度 | v5.5.4（build-release.sh） | build/Release（xcodebuild） |
|------|----------------------------|-----------------------------|
| 签名状态 | ad-hoc 签名（`codesign --force --deep --sign -`） | **未签名**（xcodebuild 默认不签名 macOS app） |
| CodeDirectory | 84877 bytes, hashes=2646+3 | N/A |
| Entitlements | 无（重签时被剥离） | N/A |

build-release.sh 的 `codesign --force --deep --sign -` 重签不指定 entitlements，剥离了 xcodebuild 默认注入的 `get-task-allow`。

> **注**：签名差异通常不影响 SwiftUI 布局行为，但 hardened runtime / App Sandbox 行为受签名状态影响。如果 SwiftUI 的某些系统外观行为（如 sidebar vibrancy material）受签名状态间接影响，这可能是运行时差异源。目前列为**待验证**，不是已确认根因。

### 当前状态：编译层面无差异，问题可能在运行时

如果 target 和 scheme 构建的 sidebar 行为确实不同（需要验证），剩余可能性：

**可能性 A：增量编译缓存残留**
- build-release.sh 没有 clean step
- 如果之前在 `build/` 中有旧代码的编译产物，Swift whole-module 编译可能部分复用
- Clean build（`rm -rf build/`）后应该排除这个因素

**可能性 B：签名/entitlements 差异**
- 详见上方签名差异分析
- 待验证：带 entitlements 的签名 vs 不带 entitlements 的签名是否影响 sidebar 行为

> **⚠️ 前提待验证**：以上所有分析都基于"两种构建路径确实产生不同行为"这个前提。但这个前提本身还没有被严格验证——见下方实验 0。

### 需要人工验证的实验

**实验 0**（最高优先级 — 原始观察复现）：

所有后续分析都基于"两种构建路径行为不同"的前提。这个前提需要被独立验证：
1. 请丹妮重现她的原始观察，记录确切步骤（什么时间、什么命令、从哪个路径运行的 App）
2. 关键：确认 "scheme 路径 ✅" 的观察是来自 Release 构建还是 Debug 构建（Xcode Run 默认 Debug）
3. 如果 "scheme ✅" 来自 Debug 构建，而 "target ❌" 是 Release 构建——那差异不是构建路径，而是 Debug vs Release
4. 如果原始差异无法复现，后续分析可以收束

**实验 1**：运行 clean target build Release
1. 运行 `~/DevTeam/projects/chinese-chess/build/Release/ChineseChess.app`
2. 打开残局演示或大师棋谱 sidebar
3. 检查分类名称是否可见

**实验 2**：运行 clean scheme build Release（对照实验）
1. `xcodebuild -project ChineseChess.xcodeproj -scheme ChineseChess -configuration Release build CONFIGURATION_BUILD_DIR=/tmp/scheme-release`
2. 运行 `/tmp/scheme-release/ChineseChess.app`
3. 检查 sidebar 是否可见
4. **与实验 1 对比**——如果两者行为一致，"两种路径不同行为"的前提不成立

**实验 3**（如果实验 1 和 2 行为不同）：
1. 调查签名差异——用 `codesign --force --deep --sign - --entitlements <保留 get-task-allow>` 打包
2. 调查 Bundle 路径差异——将 target 产物复制到和 scheme 产物类似的路径运行

## 修复方案

### 优先级 1：build-release.sh 增加 clean step（立即执行）

```bash
# 在 xcodegen generate 之后、xcodebuild build 之前加：
echo "🧹 Cleaning previous build artifacts..."
rm -rf "$BUILD_DIR"
```

**理由**：即使增量编译不是当前问题的根因，clean step 也是打包的基本卫生措施。不 clean 的增量打包 = 不可复现的构建。

**代价**：每次全量编译约 8-10 分钟（Intel Mac），但保证构建可复现。

### 优先级 2：验证实验 1

由 Luke/丹妮/洪涛执行实验 1（运行 clean target build，检查 sidebar）。结果决定后续方向。

### 优先级 3：如果 clean build 仍有问题（备选方案）

如果实验确认两种 Release 路径行为确实不同，需要：

**选项 A**：build-release.sh 改用 `-scheme` 路径（需要 project.yml 添加 scheme 定义）

**选项 B**：project.yml 显式定义 scheme（解决当前 -scheme 依赖 Xcode 隐式生成、不可复现的问题）

**选项 C**：做更深入的二进制 diff（text section disassembly、Swift type metadata 对比）

## 给 Luke 的建议

1. **先跑实验 0**：让丹妮用文档化步骤重现原始观察——这是所有分析的前提
2. **同时跑实验 1 + 实验 2**：分别运行 clean target Release 和 clean scheme Release，对比 sidebar
3. build-release.sh 加 `rm -rf "$BUILD_DIR"`（不管实验结果都该加）
4. 如果实验 0 发现原始观察不可复现，或实验 1+2 行为一致 → 问题已解决（或从未存在）
5. 如果实验 1+2 行为确实不同 → 我继续调查签名差异方向
