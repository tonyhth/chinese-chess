# NNUE 嵌入问题排查报告

> 角色：Alex（架构师） | 日期：2026-06-26 | 优先级：🔴 紧急
>
> 状态：排查完成，修正方案待审批

---

## 一、根因分析

### 结论：`-DNNUE_EMBEDDING_ON` 是无效参数，pikafish 不支持编译时 NNUE 嵌入

### 证据链

| # | 证据 | 说明 |
|---|------|------|
| 1 | 全源码搜索 `NNUE_EMBEDDING` 无结果 | pikafish 代码中**没有任何地方**检查 `NNUE_EMBEDDING_ON` 宏 |
| 2 | `build.sh` 第 59 行 `-DNNUE_EMBEDDING_ON` | 这个参数被传入编译器但从未被任何源码使用，等于空操作 |
| 3 | `pikafish_api.cpp` 第 132-150 行 | 引擎初始化时通过 `CFBundleCopyResourcesDirectoryURL` 从 **App Bundle Resources 目录**加载 NNUE 文件 |
| 4 | `misc.cpp` 第 555 行 `read_compressed_nnue()` | NNUE 加载是**运行时从文件系统读取** Zstandard 压缩文件，不是从编译时数据 |
| 5 | `network.cpp` 第 63-76 行 `load()` | 搜索目录列表加载 NNUE 文件，无编译时嵌入路径 |
| 6 | `lib/macos/libpikafish.a` 仅 4.0MB | 嵌入 48MB NNUE 后应 > 50MB |
| 7 | `lib/ios/libpikafish.a` 仅 957KB | 同上 |
| 8 | `iOS project.yml` 第 75 行 | `pikafish.nnue` 作为 **Copy Bundle Resources** 打包，不是嵌入静态库 |

### 根因

**我们的 `build.sh` 是手写的 clang++ 直接编译流程，不走 pikafish 的 Makefile。** 而 pikafish 本身**根本没有编译时 NNUE 嵌入机制**——它的 NNUE 始终是运行时从文件加载的。

`-DNNUE_EMBEDDING_ON` 是我们方案文档虚构的参数，pikafish 源码不认。

### iOS 为什么能用

iOS 项目（`project.yml`）将 `pikafish.nnue`（48MB zstd 压缩文件）作为资源文件打包到 App Bundle 的 Resources 目录。`pikafish_api.cpp` 在 `pikafish_init()` 中通过 `CFBundleCopyResourcesDirectoryURL` 找到该文件并加载。

**NNUE 从未嵌入静态库，iOS 一直是运行时从 Bundle 加载的。**

---

## 二、方案修正

### 两个可行方向

| 方向 | 说明 | 优势 | 劣势 |
|------|------|------|------|
| **A：运行时加载（保持现状）** | NNUE 作为资源文件打包到 App Bundle | 已验证可行（iOS 已用）、实现简单、编译快 | App 安装体积仍含 48MB NNUE 文件 |
| **B：编译时嵌入** | 修改 pikafish 源码，用 `incbin` 将 NNUE 编译进 .a | App 无需独立 NNUE 文件 | 需修改第三方源码、升级维护成本高、编译慢 |

### 推荐：方向 A（运行时加载）

**理由**：
1. **已验证可行**：iOS 已在使用此方案，macOS 只需同样处理
2. **不修改第三方源码**：pikafish 源码零改动，升级时无冲突
3. **App 体积相同**：无论编译时嵌入还是运行时加载，48MB NNUE 数据都在 App 中，最终体积无差异
4. **编译效率高**：静态库 4MB vs 嵌入后 50+MB，编译和链接更快
5. **增量更新友好**：NNUE 网络文件可独立更新，不需重编译静态库

### 方向 B 的额外风险

如果选择编译时嵌入：
- 需引入 `incbin` 第三方库（将二进制文件嵌入 C++ 代码）
- 需修改 `network.cpp` 的 `load()` 方法，添加嵌入数据读取路径
- pikafish 升级时需重新适配修改
- 编译时间从秒级变为分钟级（48MB 数据 → C++ 字节数组 → 编译）
- 静态库 50+MB，git clone 和 CI 都变慢

---

## 三、修正后的架构

### NNUE 加载流程（macOS + iOS 统一）

```
App 启动
  → pikafish_init()
  → CFBundleCopyResourcesDirectoryURL() 获取 Resources 路径
  → 读取 Resources/pikafish.nnue（Zstandard 压缩）
  → read_compressed_nnue() 解压
  → Network::load() 初始化神经网络
  → 引擎就绪
```

### 文件部署

| 文件 | 位置 | 打包方式 |
|------|------|----------|
| `libpikafish.a` | 静态库，链接到主可执行文件 | Xcode Link Binary |
| `pikafish.nnue` | App Bundle Resources 目录 | Copy Bundle Resources |
| `module.modulemap` | 编译时使用 | 不入 Bundle |
| `pikafish_api.h` | 编译时使用 | 不入 Bundle |

### macOS App 大小影响（修正）

| 项目 | 大小 | 说明 |
|------|------|------|
| 主可执行文件 | ~15MB（含 libpikafish.a 的代码段） | 原始 ~15MB + 4MB 引擎代码 |
| pikafish.nnue | 48MB（zstd 压缩） | Bundle Resources |
| 其他资源 | ~2MB | 图片、音效等 |
| **App 总计** | **~65MB** | 比原先预估的 85MB 小（之前错误计算了 70MB 嵌入 + 15MB App） |

> **注意**：原方案文档中"NNUE 70MB 嵌入"是错误的。实际 NNUE 文件是 48MB zstd 压缩格式，解压后约 200MB，但运行时才解压到内存，不影响 App 安装体积。

---

## 四、需要修正的文档

| 文件 | 修正内容 |
|------|----------|
| `v3.4.0-macos-static-embed-common.md` | 删除所有"NNUE 嵌入到预编译静态库"描述；改为"NNUE 作为 Bundle Resource 打包" |
| `v3.4.0-macos-phase-a.md` | 删除 `-DNNUE_EMBEDDING_ON`；`build.sh` 不再处理 NNUE；增加"NNUE 文件打包到 Bundle"步骤 |
| `v3.4.0-macos-phase-b.md` | 无需修改（Swift 代码不直接处理 NNUE） |
| `v3.4.0-macos-phase-c.md` | 无需修改（UI 层不涉及 NNUE） |
| `v3.4.0-macos-phase-d.md` | 更新验证项：确认 NNUE 文件在 Bundle 中可用 |
| `project-normalization-plan.md` | 批次 3（NNUE 去重）修正：仅保留 1 份 NNUE 文件在项目中作为打包源，删除 build 目录中的冗余副本 |

### 关键参数修正

| 参数 | 原方案（错误） | 修正后 |
|------|---------------|--------|
| NNUE 嵌入方式 | 编译时嵌入 `.a` | 运行时从 Bundle Resources 加载 |
| `-DNNUE_EMBEDDING_ON` | 有效 | **无效，删除** |
| 静态库大小 | > 50MB（含 NNUE） | ~4MB（不含 NNUE） |
| macOS App 大小 | ~85MB | ~65MB |
| NNUE 文件部署 | 不需要（已嵌入） | 需打包到 Bundle Resources |

---

## 五、执行计划

| 步骤 | 操作 | 前置条件 |
|------|------|----------|
| 1 | 修正 `build.sh`：删除 `-DNNUE_EMBEDDING_ON`，增加 NNUE 文件复制步骤 | 无 |
| 2 | 修正 Phase A 文档：NNUE 打包方式改为 Bundle Resource | 步骤 1 |
| 3 | 修正通用设计文档：删除 NNUE 嵌入描述 | 步骤 1 |
| 4 | 修正规范化方案批次 3 | 步骤 1 |
| 5 | macOS Xcode 项目配置：`pikafish.nnue` 加入 Copy Bundle Resources | 步骤 1 |
| 6 | 验证 macOS 启动时 NNUE 加载成功 | 步骤 5 |

---

## 六、风险

| 风险 | 影响 | 回退 |
|------|------|------|
| macOS Bundle Resources 路径与 iOS 不同 | NNUE 文件找不到 | `pikafish_api.cpp` 已处理：macOS 用 `CFBundleCopyResourcesDirectoryURL` 获取 `.app/Contents/Resources/` |
| NNUE 文件未加入 Copy Bundle Resources | 运行时加载失败 | Phase D 测试矩阵会验证此项 |
| 未来如果需要编译时嵌入 | 架构变更 | 方向 B 方案可作为后续优化，不影响当前方向 A |
