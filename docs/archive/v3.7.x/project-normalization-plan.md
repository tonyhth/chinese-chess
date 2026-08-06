# 中国象棋项目规范化方案

> 角色：Alex（架构师） | 日期：2026-06-26 | 版本：v2.0（Vera 审查修复版）
>
> 状态：GPLv3 决策已定（2026-06-27）→ 待 Vera 复审

---

## 一、概述

### 问题总结

| 维度 | 问题数 | 严重度 |
|------|--------|--------|
| 文档规范 | 3 类 | 中（不影响功能，影响协作效率） |
| 代码规范 | 4 类 | 高（Git 脏乱影响版本管理，编译产物拖慢仓库） |
| 第三方/依赖 | 4 类 | 🟢 已决策（GPLv3 已定案 + 438MB 构建产物 + 192MB NNUE 重复） |

### 设计原则

1. **不破坏当前可用代码**：清理是安全的，不改变编译结果和运行时行为
2. **分批执行**：按风险等级分批，高优先级先做
3. **可回滚**：每步操作前确保 git 可回滚
4. **洪涛只关心结果**：法律风险结论和最终目录结构，执行细节交给团队

### ✅ 前置阻塞项：GPLv3 决策（已决策）

> **已决策（2026-06-27，洪涛确认）**：继续使用 Pikafish，静态库链接方式不构成衍生作品。

**决策依据**：通过 C API（pikafish_api.h）接口调用 Pikafish，Pikafish 代码独立编译为 .a 静态库，是接口层面的使用，不构成版权意义上的衍生作品。Cody 之前的 GPLv3 评估结论（NO-GO）不适用。

---

## 二、文档规范化

### 2.1 问题诊断

| # | 问题 | 现状 |
|---|------|------|
| D-1 | 文档分散在两处 | `~/DevTeam/docs/`（37 个文件，已废弃但仍在用）+ `~/DevTeam/projects/chinese-chess/docs/`（57 个文件，规范位置） |
| D-2 | 版本目录命名不统一 | 项目内：`v2.2.18/`、`v3.1/`；项目外：散落在 `docs/phases/` 以 `v3.x.x-*.md` 命名 |
| D-3 | 过期文档未归档 | `docs/v2.2.18/`（16 个文件）、`docs/bugs/`（v2 时代 bug）、`docs/spikes/` |
| D-4 | v3.4.0 Phase 文档在项目外 | 我写的 macOS 方案文档在 `~/DevTeam/docs/phases/`，不在项目版本目录内 |

### 2.2 目标目录结构

```
~/DevTeam/projects/chinese-chess/docs/
├── README.md                          # 文档索引（已有，需更新）
├── active/                            # 当前活跃版本文档
│   ├── design/                        # 活跃设计方案
│   ├── phases/                        # 活跃 Phase 文档
│   │   ├── v3.4.0-macos-static-embed-common.md
│   │   ├── v3.4.0-macos-phase-a.md
│   │   ├── v3.4.0-macos-phase-b.md
│   │   ├── v3.4.0-macos-phase-c.md
│   │   ├── v3.4.0-macos-phase-d.md
│   │   ├── v3.4.0-ios-engine-implementation-plan.md
│   │   └── v3.3.0-ios-engine-integration.md
│   ├── bugs/                          # 活跃 bug 分析
│   └── spikes/                        # 活跃调研
│       └── pikafish-gplv3-evaluation.md
├── archive/                           # 已完结版本归档（只读）
│   ├── v2.2.18/                       # v2 最后版本完整归档
│   ├── v3.0/                          # v3.0 升级计划 + Phase 文档
│   │   ├── overview.md
│   │   ├── phase1.md
│   │   ├── ...
│   │   └── phase11.md
│   ├── v3.1/                          # v3.1 国际化
│   ├── v3.2.x/                        # v3.2 系列
│   └── v3.3.0/                        # v3.3 已完结设计
├── general/                           # 通用规范（跨版本）
│   ├── test-rules.md
│   ├── doc-organization-analysis.md
│   └── tech-debt.md
├── guides/                            # 用户指南
│   └── ios-deploy-guide.md
└── reviews/                           # 历史审查报告
    └── v2.1-vera-review-fixes.md
```

### 2.3 执行计划

| 步骤 | 操作 | 影响文件数 | 前置条件 |
|------|------|-----------|----------|
| 1 | 创建 `docs/active/` 和 `docs/archive/` 目录结构 | 0 | 无 |
| 2 | v3.4.0 Phase 文档从 `~/DevTeam/docs/phases/` 迁入 `docs/active/phases/` | 6 文件 | **v3.4.0 发布完成** |
| 3 | `~/DevTeam/docs/phases/` 中 v3.0/v3.1/v3.2.x 文档迁入 `docs/archive/v3.x/` | ~20 文件 | 无 |
| 4 | `~/DevTeam/docs/` 顶层散落文件迁入对应位置或归档 | ~10 文件 | 无 |
| 5 | `docs/v2.2.18/` 移入 `docs/archive/v2.2.18/` | 16 文件 | 无 |
| 6 | `docs/v3.1/` 移入 `docs/archive/v3.1/` | 8 文件 | 无 |
| 7 | `~/DevTeam/docs/` 标记废弃（见 §2.5） | 目录级别 | 步骤 3-6 完成 |
| 8 | 删除 `.bak` / `.bak2` / `.deprecated` 文件 | 4 文件 | 无 |
| 9 | 更新 `document-conventions.md` 反映新结构 | 1 文件 | 无 |
| 10 | 更新 `docs/README.md` 索引 | 1 文件 | 无 |

> **P1-3 修复**：步骤 2（v3.4.0 Phase 文档迁移）增加前置条件"v3.4.0 发布完成"。v3.4.0 实施期间文档保持在 `~/DevTeam/docs/phases/`，审查流程中的路径引用不受影响。

### 2.4 归档策略（持续）

- **版本完结标准**：版本发布 + 无后续补丁 = 归档条件
- **归档操作**：`docs/active/` → `docs/archive/v{版本号}/`
- **归档后只读**：不再修改归档文档，新问题在新版本目录中记录

### 2.5 废弃目录管理

> **P2-8 修复**：明确废弃标记和删除流程。

`~/DevTeam/docs/` 迁移完成后：

1. 在 `~/DevTeam/docs/` 下创建 `.DEPRECATED` 文件（非目录）：
   ```
   此目录已废弃。
   所有文件已迁移到 ~/DevTeam/projects/chinese-chess/docs/。
   删除日期：2026-07-15（2 周后）
   负责人：Cody
   ```
2. 到期后由 Cody 执行 `rm -rf ~/DevTeam/docs/`，并在 commit message 中记录
3. 如果 2 周内有文件被发现遗漏，迁移到项目 docs/ 后再删除

---

## 三、代码规范化

### 3.1 Git 工作区清理

#### 当前状态

| 类型 | 数量 | 说明 |
|------|------|------|
| 已修改未提交 | 25 | v3.4.0 开发中的正常变更 |
| 已删除未 git rm | 10 | 旧外部引擎方案文件 |
| 新增未 git add | 8 | 新文件（EmbeddedPikafishEngine.swift 等） |

#### 清理计划（拆分为语义化 commit）

> **P1-4 修复**：拆分为多个语义化 commit，便于 bisect。

| 步骤 | 操作 | Commit Message |
|------|------|----------------|
| G-1 | `git rm` 已删除的 10 个文件 | `chore: remove legacy external engine code` |
| G-2 | `git add` Pikafish 静态库 + modulemap + build.sh | `feat: add Pikafish static library + modulemap` |
| G-3 | `git add` EmbeddedPikafishEngine.swift + EngineConfigStore.swift | `refactor: rewrite engine layer for C API direct calls` |
| G-4 | `git add` 其余已修改的源码文件 | `feat: v3.4.0 WIP - engine integration changes` |
| G-5 | 更新 .gitignore，清理 .profraw / *.log | `chore: update .gitignore, clean untracked artifacts` |

每个 commit 独立可回滚，出问题可以精确 bisect。

### 3.2 .gitignore 完善

#### 当前缺失项

```gitignore
# === 新增 ===

# Profiling 产物
*.profraw
*.profdata

# 日志文件
*.log

# 编译中间产物（防御性）
*.o
*.obj

# Xcode / Swift 编译产物（防御性）
DerivedData/

# iOS Pikafish 编译产物（防御性）
ChineseChess-iOS/Pikafish/src/*.o
ChineseChess-iOS/Pikafish/src/*.a
ChineseChess-iOS/build_phase6/
ChineseChess-iOS/build_smoke/

# Xcode 自动生成
*.xcuserstate

# 构建产物补充
*.dmg
*.ipa
```

> **P2-7 修复**：删除 `*.resolved` — `Package.resolved` 应入库以保证依赖版本一致性。删除重复的 `*.xcodeproj/xcuserdata/`（已有）。

### 3.3 Pikafish 代码去重

> **前置条件**：GPLv3 决策为"继续使用 pikafish"。

#### 当前状态

| 位置 | 内容 | 大小 | 说明 |
|------|------|------|------|
| `ChineseChess-iOS/Pikafish/` | 完整 C++ 源码 + 42 个 .o + 7 个 .a + Makefile | 113MB | iOS 项目的直接编译方案 |
| `src/ChineseChess/Pikafish/` | build.sh + modulemap + pikafish_api.h + VERSION | 6.9MB | macOS 的预编译静态库方案 |

**重复内容**：
- `pikafish_api.h` 两处（iOS 源码目录 + macOS include 目录）
- pikafish 完整 C++ 源码在 iOS 目录中（113MB）
- NNUE 文件 4 份（详见 §4.2）

#### 目标：统一为预编译静态库方案

| 保留 | 删除 |
|------|------|
| `src/ChineseChess/Pikafish/`（统一目录） | `ChineseChess-iOS/Pikafish/`（113MB 全部删除） |
| `src/ChineseChess/Pikafish/include/pikafish_api.h` | `ChineseChess-iOS/Pikafish/src/pikafish_api.h` |
| `src/ChineseChess/Pikafish/lib/ios/libpikafish.a` | `ChineseChess-iOS/Pikafish/src/*.a`（7 个文件） |
| `src/ChineseChess/Pikafish/lib/ios-sim/libpikafish.a` | `ChineseChess-iOS/Pikafish/src/*.o`（42 个文件） |

**前置条件**：Phase A 构建脚本能产出 iOS 静态库（`lib/ios/` + `lib/ios-sim/`）。

**注意**：此方案依赖 v3.4.0 Phase B 完成（iOS 侧删除 ObjC Wrapper，迁移到 modulemap）。**如果 Phase B 未完成，保持现状，仅清理编译产物**。

#### 分级执行

| 级别 | 操作 | 前置条件 | 收益 |
|------|------|----------|------|
| 即时 | 删除 `ChineseChess-iOS/Pikafish/src/*.o`（42 个）和 `*.a`（7 个） | 无 | -67MB 编译产物 |
| 即时 | 删除 `ChineseChess-iOS/build_phase6/` 和 `build_smoke/` | 无 | -98MB |
| Phase B 完成后 | 删除整个 `ChineseChess-iOS/Pikafish/` 目录 | Phase B | -113MB |
| Phase B 完成后 | 统一 `pikafish_api.h` 到 `src/ChineseChess/Pikafish/include/` | Phase B | 消除重复 |

### 3.4 构建系统统一策略

#### 当前状态

| 平台 | 构建系统 | Pikafish 集成方式 |
|------|----------|-------------------|
| macOS | SPM（`Package.swift`） | `CPikafish` systemLibrary + 预编译 .a |
| iOS | xcodegen（`project.yml`） | Pikafish Xcode target 直接编译 C++ |

#### 目标方案（长期）

**统一为 Xcode + xcodegen**，iOS 和 macOS 共用一套构建系统。

#### 风险评估

> **P1-5 修复**：补充迁移风险评估。

| 风险点 | 评估 | 应对 |
|--------|------|------|
| SPM 独有功能无法替代 | SPM 的 `systemLibrary` 在 xcodegen 中通过 `frameworks` + build settings 实现，功能等价 | 验证 modulemap 导入是否正常 |
| App bundle 组装 | `build-app.sh` 脚本手动组装 bundle，不依赖 SPM 的 bundle 生成 | 脚本适配 xcodegen 输出路径 |
| Resource handling | SPM `\.process("Resources")` 在 xcodegen 中通过 "Copy Bundle Resources" build phase 实现 | 迁移时确认 resources 列表完整 |
| CI/CD 改造 | 当前无 CI/CD（手动构建），无改造压力 | 未来引入 CI/CD 时直接用 xcodegen |
| 回退方案 | 如果 xcodegen 无法替代 SPM 某功能 | git revert Package.swift，保留 SPM（不影响 iOS） |

**结论**：SPM → xcodegen 迁移风险可控。关键差异（systemLibrary → frameworks）有成熟替代方案。如果迁移发现不可逾越的问题，回退到 SPM 不影响 iOS 侧。

#### 执行策略

**不阻塞 v3.4.0 发布**。构建系统迁移作为 v3.5.0 的独立任务：

| 阶段 | 任务 | 时机 |
|------|------|------|
| 1 | macOS 构建从 SPM 迁移到 xcodegen | v3.5.0 |
| 2 | 验证 macOS + iOS 双平台 xcodegen 构建 | v3.5.0 |
| 3 | 删除 `Package.swift` 和 SPM 相关配置 | v3.5.0 |

---

## 四、第三方工具/依赖规范化

### 4.1 Pikafish GPLv3 决策（已定案）

> **已决策（2026-06-27，洪涛确认）**：继续使用 Pikafish。

#### 决策结论

通过 C API（pikafish_api.h）接口调用 Pikafish，Pikafish 代码独立编译为 .a 静态库，是接口层面的使用，不构成版权意义上的衍生作品。

#### 历史评估（已被推翻）

`docs/spikes/pikafish-gplv3-evaluation.md`（2026-06-20，Cody）的结论是 ❌ NO-GO，依据为：
1. GPLv3 传染性 → 必须开源全部 App 代码
2. GPLv3 anti-titoization → 与 App Store DRM 直接冲突
3. 即使动态链接也不行（GPLv3 覆盖动态链接场景）

**此评估不适用**：洪涛判定静态库链接方式（C API 接口调用）不构成衍生作品，上述传染性分析的前提不成立。

#### 后续行动

规范化方案 §3.3（Pikafish 源码去重）、§4.2（NNUE 去重）、§3.4（构建系统统一）全部按原计划执行，不再附带前置条件。

### 4.2 NNUE 文件去重

> **前置条件**：GPLv3 决策为"继续使用 pikafish"。

#### 当前状态

| 文件 | 位置 | 大小 |
|------|------|------|
| `pikafish.nnue` | `ChineseChess-iOS/Pikafish/pikafish.nnue` | 48MB |
| `nnue.bin` | `ChineseChess-iOS/Pikafish/src/nnue.bin` | 48MB |
| `pikafish.nnue` | `ChineseChess-iOS/build_phase6/pikafish.nnue` | 48MB |
| `pikafish.nnue` | `ChineseChess-iOS/build_smoke/pikafish.nnue` | 48MB |

**总计**：4 份 × 48MB = **192MB**（实际只需 1 份或 0 份）

#### 清理计划（分步安全删除）

> **P0-2 修复**：完善回退方案，分步执行。
> **NNUE 修正（2026-06-26）**：NNUE 不嵌入静态库，以独立文件打包到 Bundle Resources。
> 因此项目中需保留 1 份 NNUE 文件作为打包源。仅删除冗余副本。

**Step 1：保留 1 份作为打包源**

```bash
# 将 pikafish.nnue 统一放到 Pikafish/resources/ 目录
# （build.sh 构建脚本已自动拷贝到此位置）
# 此文件是 Xcode Copy Bundle Resources 的打包源，不能删除
ls -la src/ChineseChess/Pikafish/resources/pikafish.nnue  # 预期：48MB
```

**Step 2：分步删除冗余副本**

| 步骤 | 操作 | 验证 | 回退 |
|------|------|------|------|
| 2a | 删除 `build_phase6/pikafish.nnue` + `build_smoke/pikafish.nnue` | 编译通过 | 重新编译生成 |
| 2b | 删除 `Pikafish/pikafish.nnue`（iOS 项目目录） | iOS 编译通过，Bundle 中 NNUE 正常 | 从 resources/ 恢复 |
| 2c | 删除 `Pikafish/src/nnue.bin` | iOS/macOS 运行正常 | 从 resources/ 恢复 |
| 2d | 删除 `build_phase6/` + `build_smoke/`（整个目录） | 无影响 | 无（编译产物） |

**Step 3：确认后清理 backup**（可选）

双平台运行正常后，确认 `Pikafish/resources/pikafish.nnue` 是唯一的 NNUE 文件。

> **注意**：由于 NNUE 不嵌入静态库，项目中**必须保留 1 份** pikafish.nnue 作为 Bundle Resource 打包源。
> 原方案“删除全部 4 份 NNUE 文件”的前提（嵌入静态库）不成立。

### 4.3 构建产物归档策略

#### 当前状态

项目根目录散落 14 个 `.app` 目录，总计 **438MB**。

#### 完整清单

> **P2-9 修复**：列出所有 .app 的完整信息。

| # | 文件名 | 大小 | 修改日期 | 处理建议 |
|---|--------|------|----------|----------|
| 1 | 中国象棋-v2.2.10.app | 29MB | _待确认_ | 删除 |
| 2 | 中国象棋-v2.2.11.app | 29MB | | 删除 |
| 3 | 中国象棋-v2.2.12.app | 29MB | | 删除 |
| 4 | 中国象棋-v2.2.13.app | 29MB | | 删除 |
| 5 | 中国象棋-v2.2.14.app | 29MB | | 删除 |
| 6 | 中国象棋-v2.2.15.app | 29MB | | 删除 |
| 7 | 中国象棋-v2.2.20.app | 29MB | | 删除 |
| 8 | 中国象棋-v2.2.20n.app | 29MB | | 删除 |
| 9 | 中国象棋-v2.2.21.app | 29MB | | 删除 |
| 10 | 中国象棋-v3.2.1.app | 34MB | | 删除 |
| 11 | 中国象棋-v3.2.2.app | 34MB | | 删除 |
| 12 | 中国象棋-v3.2.3.app | 35MB | | 删除 |
| 13 | 中国象棋-v3.3.0.app | 35MB | | 保留（上一稳定版） |
| 14 | 中国象棋-v3.4.0.app | 35MB | | 保留（最新版） |

> 执行前由 Luke `ls -la` 确认修改日期后决定。

#### 清理建议

| 保留 | 删除 |
|------|------|
| 最新版本 `中国象棋-v3.4.0.app` | v2.2.10 ~ v2.2.21（9 个，~261MB） |
| 上一稳定版本 `中国象棋-v3.3.0.app`（回退用） | v3.2.1 ~ v3.2.3（3 个，~103MB） |

**节省**：~364MB

> **洪涛决策**：是否保留旧版本 .app？如果不需要回退测试，可以全部删除。

### 4.4 脚本工具规范化

#### 当前状态

| 脚本 | 位置 | 行数 | 用途 | 状态 |
|------|------|------|------|------|
| `build-app.sh` | `scripts/` | 298 | 构建 macOS App（debug/release 参数） | 通用 |
| `build-release.sh` | `scripts/` | 316 | 标准化发布打包（签名、版本号校验） | 已修改未提交 |
| `reclassify-551.py` | `scripts/` | — | 一次性数据迁移 | 已废弃 |
| `test-batch.sh` | `scripts/` | — | 批量测试 | 通用 |
| `test-runner.sh` | `scripts/` | — | 测试运行器 | 通用 |
| `build_opening_book.py` | `tools/` | — | 开局库生成 | 通用 |
| `pgn_data` | `tools/` | — | PGN 数据文件 | 数据文件 |

#### 规范化

> **P1-6 修复**：先评估合并可行性，差异大的保持分开。

经 diff 分析，`build-app.sh`（298 行，支持 debug/release 参数）和 `build-release.sh`（316 行，专注发布打包，含版本号校验、签名逻辑）功能差异较大。**强行合并会增加复杂度**。

| 操作 | 说明 |
|------|------|
| 删除 `reclassify-551.py` | 一次性脚本，已完成使命 |
| 重命名 `build-app.sh` → `build-macos.sh` | 明确平台 |
| 保持 `build-release.sh` 不变（或重命名 → `build-macos-release.sh`） | 差异大，不合并 |
| `scripts/` 目录文档化 | 每个脚本开头加注释说明用法 |
| `tools/pgn_data` 加入 `.gitignore` | 数据文件不入库 |
| 创建 `scripts/README.md` | 脚本索引和使用说明 |

#### 目标结构

```
scripts/
├── build-macos.sh              # macOS 构建（debug/release 参数）
├── build-macos-release.sh      # macOS 发布打包（签名、版本号校验）
├── test-batch.sh               # 批量测试
├── test-runner.sh              # 测试运行器
└── README.md                   # 脚本索引

tools/
├── build_opening_book.py
└── README.md
```

---

## 五、执行计划

### 分批执行

| 批次 | 内容 | 风险 | 前置条件 | 工期 |
|------|------|------|----------|------|
| **批次 1** | Git 工作区清理 + .gitignore 完善 | 🟢 低 | 无 | 0.5 天 |
| **批次 2** | 文档迁移归档（已完结版本） | 🟢 低 | 无 | 0.5 天 |
| **批次 2b** | v3.4.0 Phase 文档迁移 | 🟢 低 | **v3.4.0 发布完成** | 0.5 天 |
| **批次 3** | NNUE 去重 + 编译产物清理 | 🟡 中 | GPLv3 决策 + Phase A 构建脚本 | 0.5 天 |
| **批次 4** | Pikafish 源码去重 + 脚本规范化 | 🟡 中 | GPLv3 决策 + Phase B 完成 | 0.5 天 |
| **批次 5** | 构建系统统一 | 🔴 阻塞级 | v3.5.0 规划 | 2-3 天 |
| **批次 6** | 旧 .app 清理 | 🟢 低 | Luke 确认 | 0.5 天 |

### 依赖关系

```
无前置 ──→ 批次 1（Git 清理）─┐
                             ├→ 批次 2（文档归档，已完结版本）→ 批次 2b（v3.4.0 文档迁移，待发布后）
                             └→ 批次 6（.app 清理，待 Luke 确认）

GPLv3 决策 ──→ 批次 3（NNUE 去重）→ 批次 4（源码去重）→ 批次 5（构建统一，v3.5.0）
```

### 每批次验证清单

> **P2-10 修复**：每个批次末尾加验证标准。

**批次 1 验证**：
- [ ] `git status` 无未跟踪的 .profraw / .log 文件
- [ ] `git log --oneline -5` 显示语义化 commit
- [ ] `.gitignore` 新增项生效（`git check-ignore` 测试）

**批次 2 验证**：
- [ ] `docs/active/` 和 `docs/archive/` 目录结构正确
- [ ] `docs/README.md` 索引链接可正确跳转
- [ ] `~/DevTeam/docs/.DEPRECATED` 文件存在

**批次 3 验证**：
- [ ] `nm` / `strings` 确认 NNUE 嵌入 .a
- [ ] backup 存在于 `~/DevTeam/assets/pikafish-backup/`
- [ ] iOS + macOS 双平台编译通过
- [ ] 双平台运行时 NNUE 加载正常

**批次 4 验证**：
- [ ] `ChineseChess-iOS/Pikafish/` 已删除
- [ ] `pikafish_api.h` 仅存在于一处
- [ ] iOS + macOS 双平台编译通过
- [ ] `scripts/README.md` 存在

**批次 6 验证**：
- [ ] 仅保留 v3.3.0 + v3.4.0 两个 .app
- [ ] 节省空间符合预期（~364MB）

### 洪涛审批事项

| # | 决策点 | 选项 | 建议 |
|---|--------|------|------|
| 1 | ~~GPLv3 风险应对~~ | ~~上架但接受风险 / 不上架 / 放弃 pikafish / 寻求商业许可~~ | ✅ 已决策：继续使用 Pikafish（2026-06-27） |
| 2 | 旧 .app 保留策略 | 全删 / 保留最近 2 个 / 全保留 | 建议保留最近 2 个 |
| 3 | 构建系统统一时机 | v3.4.0 / v3.5.0 / 不统一 | 建议 v3.5.0 |

---

## 六、风险与回退

| 风险 | 影响 | 回退 |
|------|------|------|
| 文档迁移后找不到文件 | 协作混乱 | `~/DevTeam/docs/` 保留 `.DEPRECATED` 标记 2 周后删除，到期由 Cody 执行 |
| 删除编译产物导致 iOS 构建失败 | 编译阻塞 | 重新编译生成 .o/.a（不是不可逆操作） |
| NNUE 删除后引擎无法加载 | 运行时错误 | backup 在 `~/DevTeam/assets/pikafish-backup/`，逐步删除确保可回退 |
| 构建系统迁移引入新 bug | 编译失败 | 回退到 SPM（git revert），不影响 iOS 侧 |
| GPLv3 决策为放弃 pikafish | v3.4.0 方案废弃 | 自研引擎路线，规范化方案 §3.3/§4.2 调整为删除全部 pikafish 文件 |

---

## 附录：空间节省预估

> **P2-11 修复**：区分立即节省和后续节省。

| 清理项 | 节省空间 | 时机 |
|--------|----------|------|
| 编译产物（.o + .a） | 67MB | 批次 3（即时） |
| build_phase6 + build_smoke | 98MB | 批次 3（即时） |
| NNUE 冗余副本（3 份删除，保留 1 份） | 144MB | 批次 3（GPLv3 决策后） |
| 旧 .app 删除 | 364MB（9 个 v2 + 3 个旧 v3） | 批次 6（Luke 确认后） |
| **立即可执行节省** | **~673MB** | 批次 1-3 + 6 |
| Pikafish 源码去重 | 113MB | 批次 4（Phase B 后） |
| **总计** | **~786MB** | 全部完成 |

> **NNUE 修正（2026-06-26）**：原方案假设 NNUE 嵌入静态库后可删除全部 4 份 NNUE 文件。实际 pikafish 不支持编译时 NNUE 嵌入，NNUE 以独立文件打包到 Bundle Resources，需保留 1 份作为打包源，仅删除 3 份冗余副本。

---

## Vera 审查修复记录（v2）

| # | 级别 | 问题 | 修复 |
|---|------|------|------|
| 1 | P0 | GPLv3 矛盾处理时机不对 | 独立为 v3.4.0 前置阻塞项，所有 Pikafish 相关清理加前置条件标注 |
| 2 | P0 | NNUE 删除回退方案不充分 | 分步安全删除：验证嵌入 → backup → 逐步删除 → 1 周后清理 backup |
| 3 | P1 | 文档迁移与 v3.4.0 实施冲突 | v3.4.0 Phase 文档迁移增加前置条件"v3.4.0 发布完成" |
| 4 | P1 | Git WIP commit 太大 | 拆分为 5 个语义化 commit |
| 5 | P1 | SPM→xcodegen 风险评估不足 | 新增风险评估小节，逐项评估 + 回退方案 |
| 6 | P1 | 脚本合并过于激进 | 经 diff 分析后决定不合并，保持 build-macos.sh + build-macos-release.sh 分开 |
| 7 | P2 | `*.resolved` 可能误伤 Package.resolved | 删除 `*.resolved`，保留 `*.xcuserstate` |
| 8 | P2 | `.deprecated` 标记策略模糊 | 明确 `.DEPRECATED` 文件格式 + 负责人 + 删除日期 |
| 9 | P2 | 旧 .app 缺少版本对应关系 | 列出全部 14 个 .app 的完整清单 |
| 10 | P2 | 缺少执行后验证步骤 | 每个批次增加验证清单 |
| 11 | P2 | 空间节省预估含后置项 | 拆分为"立即节省 673MB"和"后续追加 113MB" |
