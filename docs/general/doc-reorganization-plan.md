# chinese-chess 文档目录整理方案

> 架构师：Alex | 日期：2026-08-05 | 版本：v1.2（Vera 复审修复版）
>
> 状态：✅ 审查通过，待 Luke 安排执行
>
> v1.0 → v1.1：P0×1 + P1×4 + P2×3 全部修复
> v1.1 → v1.2：P1×1 + P2×2 全部修复（Vera 复审）

---

## 〇、调查摘要

### 调查方法

已执行以下 grep 确认引用关系：

| 检查项 | 命令 | 结果 |
|--------|------|------|
| Swift 代码引用 docs/ | `grep -r "docs/" src/ --include="*.swift"` | ✅ 零引用（代码不依赖文档路径） |
| MD 文档引用 DevTeam/docs/ | `grep -r "DevTeam/docs" ~/DevTeam/ --include="*.md"` | ⚠️ 14 处引用（normalization-batch 任务文件、历史审计报告、knowledge/document-conventions.md） |
| MD 文档引用 docs/active/ | `grep -r "docs/active" ~/DevTeam/ --include="*.md"` | ⚠️ 12 处引用（active/ 内文档互相引用 + v3.9 审计报告引用） |
| app-icon-redesign.md 引用 competitor_icons 路径 | 逐文件 grep | ⚠️ 12 处行内引用（`~/DevTeam/docs/competitor_icons/XX.png`），迁移后需更新 |
| 根级散落文件引用 | 逐文件 grep | ✅ 仅 tech-debt.md 被 normalization-plan 引用（目录树列举） |

### 关键发现

1. **DevTeam/docs/ 已标记废弃**（`.DEPRECATED` 文件，计划 7/13 删除未执行）
2. **DevTeam/docs/ 有 2 个文件与项目内重复**：`v3.6.0-q3-achievement-design.md`、`v3.6.0-quest-restructure-design.md`（项目内 `active/phases/` 有同名文件）
3. **DevTeam/docs/phases/v2-phaseB2.md 与项目内 phases/v2-phaseB2.md 完全相同**（`diff` 确认）
4. **DevTeam/docs/phases/v2-common.md 与项目内 phases/v2-common.md 不同**（前者是 v2.2 自动演示设计 325 行，后者是 v3.7.0 通用设计 33 行，同名不同内容）
5. **active/ 中所有文档均属已交付版本**（v3.4.0~v3.7.0），项目当前已到 v5.5.0
6. **4 个空目录**：`active/bugs/`、`reviews/`、`screenshots/`、`archive/v3.1/bugs/`
7. **competitor_icons/（12 个 PNG）无副本**，是竞品分析唯一素材
8. **test-infra-redesign.md（DevTeam/docs/）与 test-infra-fix.md（项目内）是同一主题的不同版本**

---

## 一、保留清单

### 1.1 保留的目录（位置不动）

| 目录 | 说明 |
|------|------|
| `chinese-chess/docs/archive/` | **不动**。历史归档，方案约束 |
| `chinese-chess/docs/assets/` | 保留。含 4 个图片资源（截图 + iOS 图标） |
| `chinese-chess/docs/audits/` | 保留。含 v3.9 审计报告 12 个文件 + v5.2 改进提案 |
| `chinese-chess/docs/bugs/` | 保留。含 2 个 bug 记录 |
| `chinese-chess/docs/design/` | 保留。含 22 个设计文档（v4.0/v4.1/v5.0 系列） |
| `chinese-chess/docs/general/` | 保留。含 3 个通用文档 |
| `chinese-chess/docs/guides/` | 保留。含 iOS 部署指南 |
| `chinese-chess/docs/phases/` | 保留。含 7 个 Phase 文档（v2/v3.7 系列） |
| `chinese-chess/docs/spikes/` | 保留。含 3 个调研文档 |
| `chinese-chess/docs/user-guide/` | 保留。含 Pikafish 安装指南 |

### 1.2 删除的目录

| 目录 | 说明 |
|------|------|
| `DevTeam/docs/` | **整体删除**。已标记废弃超过 3 周，文件迁移后删除 |

---

## 二、迁移清单

### 2.1 DevTeam/docs/ → chinese-chess/docs/（非重复文件迁移）

以下文件在项目内**无重复**，需迁移后才能删除 DevTeam/docs/：

| 源路径 | 目标路径 | 原因 |
|--------|---------|------|
| `DevTeam/docs/chinese-chess-doc-reorganization.md` | `chinese-chess/docs/general/doc-reorganization-plan.md` | **本方案文件自身**。执行前先迁移到项目内，执行者以此为操作依据。执行完毕后可保留作为历史记录 |
| `DevTeam/docs/competitor_icons/`（12 个 PNG） | `chinese-chess/docs/assets/competitor_icons/` | 竞品图标素材，唯一副本，移入项目 assets 统一管理 |
| `DevTeam/docs/app-icon-redesign.md` | `chinese-chess/docs/design/app-icon-redesign.md` | App 图标重设计文档，归入 design/ |
| `DevTeam/docs/board-thread-safety-fix.md` | `chinese-chess/docs/design/board-thread-safety-fix.md` | Board 线程安全修复方案 v3，归入 design/ |
| `DevTeam/docs/test-infra-redesign.md` | `chinese-chess/docs/general/test-infra-redesign.md` | 测试基础设施修复方案 v3，归入 general/（注意：与已有的 `docs/test-infra-fix.md` 是同主题不同版本，后者是根级散落文件，一并整理——见 §2.2。两个文件头部各加交叉引用注释——见 P2-1 修复） |
| `DevTeam/docs/v3.7.3-audit-dimension1.md` | `chinese-chess/docs/audits/v3.7.3-dimension1.md` | v3.7.3 审计 D1，归入 audits/ |
| `DevTeam/docs/v3.7.3-audit-dimension2-review.md` | `chinese-chess/docs/audits/v3.7.3-dimension2-review.md` | v3.7.3 审计 D2，归入 audits/ |
| `DevTeam/docs/v3.7.3-audit-dimension5-review.md` | `chinese-chess/docs/audits/v3.7.3-dimension5-review.md` | v3.7.3 审计 D5，归入 audits/ |
| `DevTeam/docs/v3.7.3-audit-summary.md` | `chinese-chess/docs/audits/v3.7.3-audit-summary.md` | v3.7.3 审计总结，归入 audits/ |
| `DevTeam/docs/v5.0.0-bug4-rendering-analysis.md` | `chinese-chess/docs/bugs/v5.0.0-bug4-rendering-analysis.md` | v5.0.0 Bug4 渲染分析，归入 bugs/ |
| `DevTeam/docs/v5.0.0-real-device-bug-analysis.md` | `chinese-chess/docs/bugs/v5.0.0-real-device-bug-analysis.md` | v5.0.0 真机 Bug 分析，归入 bugs/ |
| `DevTeam/docs/design/auto-demo-design.md` | `chinese-chess/docs/design/auto-demo-design.md` | 自动演示设计文档，归入 design/ |
| `DevTeam/docs/icon_A_source.svg` | `chinese-chess/docs/assets/icon_A_source.svg` | 图标源文件，归入 assets/ |
| `DevTeam/docs/phases/v2-phase1.md` | `chinese-chess/docs/archive/v2.x/v2-phase1.md` | v2 Phase1 已交付，直接归档 |
| `DevTeam/docs/phases/v2-phase2.md` | `chinese-chess/docs/archive/v2.x/v2-phase2.md` | v2 Phase2 已交付，直接归档 |
| `DevTeam/docs/phases/v2-phase3.md` | `chinese-chess/docs/archive/v2.x/v2-phase3.md` | v2 Phase3 已交付，直接归档 |
| `DevTeam/docs/phases/v2-common.md` | `chinese-chess/docs/archive/v2.x/v2-common-auto-demo.md` | v2.2 自动演示通用设计（⚠️ 与项目内 `phases/v2-common.md` 同名不同内容，重命名避免冲突） |
| `DevTeam/docs/phases/v3.8.0-design.md` | `chinese-chess/docs/archive/v3.8.x/v3.8.0-design.md` | v3.8.0 设计文档，已交付，直接归档 |

### 2.2 chinese-chess/docs/ 根级散落文件归位

| 源路径 | 目标路径 | 原因 |
|--------|---------|------|
| `docs/bug4-fallbackId-collision-fix.md` | `docs/bugs/bug4-fallbackId-collision-fix.md` | Bug 修复文档，归入 bugs/ |
| `docs/tech-debt.md` | `docs/general/tech-debt.md` | 技术债务登记册，归入 general/ |
| `docs/test-debt-cleanup.md` | `docs/general/test-debt-cleanup.md` | 测试技术债清理方案，归入 general/ |
| `docs/test-infra-fix.md` | `docs/general/test-infra-fix.md` | 测试基础设施修复方案（v1），归入 general/（与 test-infra-redesign.md v3 并列保留。**P2-1 修复**：迁移后在两个文件头部各加交叉引用注释：<br>test-infra-fix.md 头部加 `> ℹ️ 初版方案，修订版见 test-infra-redesign.md（v3，Vera 复查后定稿）` <br>test-infra-redesign.md 头部加 `> ℹ️ v3 修订版（Vera 复查后定稿），初版见 test-infra-fix.md`） |
| `docs/需求功能说明书.md` | `docs/general/需求功能说明书.md` | PRD 文档，归入 general/ |
| `docs/README.md` | 不移动（保留在根级） | 文档索引，应在根级 |

### 2.3 active/ 已交付文档归档

active/ 中 33 个文件全部属于已交付版本（v3.4.0~v3.7.0），项目当前已到 v5.5.0。按版本归档。

**active/phases/ 逐文件归档明细**（12 个文件）：

| 源文件 | 目标路径 | 关联版本 |
|--------|---------|----------|
| `active/phases/v3.4.0-ios-engine-implementation-plan.md` | `archive/v3.4.x/v3.4.0-ios-engine-implementation-plan.md` | v3.4.0 |
| `active/phases/v3.4.0-macos-phase-a.md` | `archive/v3.4.x/v3.4.0-macos-phase-a.md` | v3.4.0 |
| `active/phases/v3.4.0-macos-phase-b.md` | `archive/v3.4.x/v3.4.0-macos-phase-b.md` | v3.4.0 |
| `active/phases/v3.4.0-macos-phase-c.md` | `archive/v3.4.x/v3.4.0-macos-phase-c.md` | v3.4.0 |
| `active/phases/v3.4.0-macos-phase-d.md` | `archive/v3.4.x/v3.4.0-macos-phase-d.md` | v3.4.0 |
| `active/phases/v3.4.0-macos-static-embed-common.md` | `archive/v3.4.x/v3.4.0-macos-static-embed-common.md` | v3.4.0 |
| `active/phases/v3.5.0-plan.md` | `archive/v3.5.x/v3.5.0-plan.md` | v3.5.0 |
| `active/phases/v3.6.0-plan.md` | `archive/v3.6.x/v3.6.0-plan.md` | v3.6.0 |
| `active/phases/v3.6.0-q3-achievement-design.md` | `archive/v3.6.x/v3.6.0-q3-achievement-design.md` | v3.6.0 |
| `active/phases/v3.6.0-quest-restructure-design.md` | `archive/v3.6.x/v3.6.0-quest-restructure-design.md` | v3.6.0 |
| `active/phases/v3.6.0-quest-restructure.md` | `archive/v3.6.x/v3.6.0-quest-restructure.md` | v3.6.0 |
| `active/phases/v3.7.0-game-record-design.md` | `archive/v3.7.x/v3.7.0-game-record-design.md` | v3.7.0 |

**active/design/ 逐文件归档明细**（12 个文件，按关联版本分散）：

| 源文件 | 目标路径 | 关联版本 |
|--------|---------|---------|
| `cmaes-parallel-design.md` | `archive/v3.6.x/design/cmaes-parallel-design.md` | v3.6.0 |
| `guided-puzzle-design.md` | `archive/v3.4.x/design/guided-puzzle-design.md` | v3.4.0 |
| `language-switch-fix.md` | `archive/v3.1/design/language-switch-fix.md` | v2.2.16（⚠️ 内容核对：此文件处理的是 v2.2.16 语言切换 bug，与 archive/v3.1/design/ 中的 `i18n-implementation-spec.md`（v3.1 R3-06a 实施方案）不重叠——前者是 bug 根因分析，后者是 i18n 实施规范。无引用关系，安全并存） |
| `p0-engine-lifecycle-fix.md` | `archive/v3.7.x/design/p0-engine-lifecycle-fix.md` | v3.7.0 |
| `p0-i18n-refactor-plan.md` | `archive/v3.7.x/design/p0-i18n-refactor-plan.md` | v3.7.0 |
| `quick-engine-toggle-design.md` | `archive/v3.6.x/design/quick-engine-toggle-design.md` | v3.6.0 |
| `r3-06c-spm-localization-fix.md` | `archive/v3.4.x/design/r3-06c-spm-localization-fix.md` | v3.4.0 |
| `r3-07-commercial-delivery-checklist.md` | `archive/v3.4.x/design/r3-07-commercial-delivery-checklist.md` | v3.4.0 |
| `replayboardview-design.md` | `archive/v3.4.x/design/replayboardview-design.md` | v3.4.0 |
| `replayviewmodel-observableobject-migration.md` | `archive/v3.4.x/design/replayviewmodel-observableobject-migration.md` | v3.4.0 |
| `v2.2.17-ios-bug-analysis.md` | `archive/v2.2.18/bugs/v2.2.17-ios-bug-analysis.md` | v2.2.17（并入 v2.2.18 归档） |
| `v3.4.0-code-quality-audit-plan.md` | `archive/v3.4.x/v3.4.0-code-quality-audit-plan.md` | v3.4.0 |

**active/ 根级归档明细**：

| 源文件 | 目标路径 | 说明 |
|--------|---------|------|
| `normalization-batch-1-2-task.md` | `archive/v3.7.x/normalization-batch-1-2-task.md` | 规范化批次任务（已完成） |
| `normalization-batch-3-4-6-task.md` | `archive/v3.7.x/normalization-batch-3-4-6-task.md` | 规范化批次任务（已完成） |
| `project-normalization-plan.md` | `archive/v3.7.x/project-normalization-plan.md` | 规范化方案（已完成） |

---

## 三、删除清单

### 3.1 DevTeam/docs/ 中的重复文件（项目内已有副本）

| 文件 | 项目内重复位置 | 操作 |
|------|---------------|------|
| `DevTeam/docs/v3.6.0-q3-achievement-design.md` | `chinese-chess/docs/active/phases/v3.6.0-q3-achievement-design.md` | 删除 DevTeam 副本（归档时用项目内版本） |
| `DevTeam/docs/v3.6.0-quest-restructure-design.md` | `chinese-chess/docs/active/phases/v3.6.0-quest-restructure-design.md` | 删除 DevTeam 副本（归档时用项目内版本） |
| `DevTeam/docs/phases/v2-phaseB2.md` | `chinese-chess/docs/phases/v2-phaseB2.md` | 删除 DevTeam 副本（`diff` 确认完全相同） |

### 3.1.1 archive/v3.4.0/ 合并到 v3.4.x/

当前 `archive/v3.4.0/` 含 1 个文件：`v3.4.0-macos-engine-embedding.deprecated.md`。

**操作**：将 `archive/v3.4.0/v3.4.0-macos-engine-embedding.deprecated.md` 迁移到 `archive/v3.4.x/v3.4.0-macos-engine-embedding.deprecated.md`，然后删除空的 `archive/v3.4.0/` 目录。

**理由**：同一版本（v3.4）的文档应在同一个归档目录，拆分两个目录会让后续维护者困惑。deprecated 文件放在 v3.4.x/ 根级即可，文件名中的 `.deprecated` 后缀已足够标识其状态。

**引用检查**：grep 确认仅 `normalization-batch-1-2-task.md` 中有一处 `rm` 命令引用（已执行过的清理脚本），无活跃引用。

### 3.2 空目录删除

| 目录 | 操作 |
|------|------|
| `chinese-chess/docs/active/bugs/` | 删除（空目录，0 文件） |
| `chinese-chess/docs/reviews/` | 删除（空目录，0 文件） |
| `chinese-chess/docs/screenshots/` | 删除（空目录，0 文件） |
| `chinese-chess/docs/archive/v3.1/bugs/` | 删除（空目录，0 文件） |

### 3.3 active/ 目录整体删除

所有 active/ 内文件迁移完成后，删除整个 `active/` 目录结构。

### 3.4 DevTeam/docs/ 整体删除

所有文件迁移/确认重复后，删除整个 `DevTeam/docs/` 目录：
- `.DEPRECATED`、`.DS_Store` — 无价值
- 已迁移的文件 — 迁移后删除源
- 重复文件 — §3.1 已确认

### 3.5 其他

| 文件 | 操作 | 原因 |
|------|------|------|
| `chinese-chess/docs/.DS_Store` | 删除 | macOS 系统文件 |
| `chinese-chess/docs/active/.DS_Store` | 删除 | macOS 系统文件（随 active/ 一并删除） |
| `chinese-chess/docs/archive/.DS_Store` | 删除 | macOS 系统文件 |
| `chinese-chess/docs/archive/v2.2.18/.DS_Store` | 删除 | macOS 系统文件 |

---

## 四、特例处理：competitor_icons/

### 现状

`DevTeam/docs/competitor_icons/` 含 12 个竞品 App 图标 PNG，无任何副本。

### 处理方案

1. **迁移到** `chinese-chess/docs/assets/competitor_icons/`
2. 保持原始文件名不变（`01_xiangqi_double.png` ~ `12_china_game.png`）
3. 在 `docs/assets/` 下新建 `competitor_icons/` 子目录
4. 迁移后确认 12 个文件完整（`ls -1 | wc -l` = 12）
5. 确认后再删除源目录

### 引用检查

grep 确认：`app-icon-redesign.md` 中有 12 处行内引用 `~/DevTeam/docs/competitor_icons/XX.png`。迁移后需更新为 `docs/assets/competitor_icons/XX.png`（见 §9.1 引用更新清单）。

### 迁移后补充（P2-3 修复）

在 `docs/assets/competitor_icons/` 下创建 `README.md`：
```markdown
# 竞品图标素材

采集日期：2026-06 ~ 2026-07
来源：App Store / Google Play 截图
用途：App 图标重设计参考（见 `docs/design/app-icon-redesign.md`）

| 编号 | 文件名 | 对应产品 |
|------|--------|---------|
| 01 | 01_xiangqi_double.png | 象棋-双人中国象棋 |
| 02 | 02_tiantian.png | 天天象棋（腾讯） |
| ... | ... | ... |
| 12 | 12_china_game.png | Chinese Chess-China game |
```

---

## 五、归档规则："交付即归档"机制

### 5.1 触发条件

文档在以下任一条件满足时**必须归档**：

| 触发条件 | 判定依据 | 示例 |
|---------|---------|------|
| Phase 验收完成 | Luke 验收通过 + git commit + tag 存在 | Phase A-D 全部通过 |
| 版本发布 | 洪涛确认版本号 + 打包完成 + git tag | v5.6.0 tag 创建 |
| 文档被 supersede | 新版本文档明确标注替代旧版 | v4.0 方案替代 v3.0 方案 |

### 5.2 归档路径规则

```
docs/archive/v<version>/
├── design/          — 该版本的设计文档
├── phases/          — 该版本的 Phase 文档
├── audits/          — 该版本的审计报告
├── bugs/            — 该版本的 Bug 记录
└── *.md             — 该版本的其他文档
```

**版本目录命名**：`v<major>.<minor>.x/`（patch 级别合并不拆分，如 `v3.4.x/`）

### 5.3 归档操作

- **触发者**：Luke（验收时触发）
- **执行者**：Cody（执行 `mv` 操作）
- **时机**：Luke 验收通过后、下一个 Phase 启动前
- **操作**：`mv docs/<category>/<file>.md docs/archive/v<version>.x/<category>/`
- **例外**：跨版本引用的通用文档（如 PRD、技术债务清单）保留在 `general/`，不归档

### 5.4 防遗忘机制（P2-2 修复）

为避免归档规则被遗忘执行（当前 active/ 积压 33 个文件正是"无执行约束"的后果），约定以下检查点：

1. **DEVTEAM.md 验收门禁增加**：在 Luke 的 Phase 验收 checklist 中增加一行：
   - [ ] 文档已归档（相关设计文档/Phase 文档已从 `docs/<category>/` 移到 `docs/archive/v<version>.x/`）

2. **丹妮监控检查**：丹妮在流水线监控时，如果发现 `docs/design/` 或 `docs/phases/` 中有已发布版本号的文档（通过文件名中的 `v<X.Y.Z>` 判断），提醒 Luke 执行归档。

3. **设计约束**：每次 Phase 验收时，Luke 确认 `docs/` 下不存在已交付版本号的未归档文档。

### 5.5 active/ 目录的处理

**取消 active/ 中间层**。理由：

1. active/ 制造了与根级目录的结构重复（`active/design/` vs `design/`、`active/phases/` vs `phases/`）
2. 当前活跃文档直接放在 `docs/design/`、`docs/phases/` 等根级分类目录中
3. 不活跃的文档归档到 `docs/archive/v<version>/`
4. "是否归档"由版本交付状态决定，不由目录位置决定

---

## 六、整理后目录结构

```
chinese-chess/docs/
├── README.md                              # 文档索引（需更新）
├── archive/                               # 历史归档（不动 + 新增）
│   ├── v2.x/                              # 🆕 v2 系列
│   │   ├── v2-common-auto-demo.md         # 🆕 迁自 DevTeam/docs/phases/
│   │   ├── v2-phase1.md                   # 🆕 迁自 DevTeam/docs/phases/
│   │   ├── v2-phase2.md                   # 🆕 迁自 DevTeam/docs/phases/
│   │   └── v2-phase3.md                   # 🆕 迁自 DevTeam/docs/phases/
│   ├── v2.2.18/                           # 已有
│   │   ├── README.md
│   │   ├── bugs/
│   │   ├── design/
│   │   └── qa/
│   ├── v3.0/                              # 已有
│   ├── v3.1/                              # 已有
│   ├── v3.2.x/                            # 已有
│   ├── v3.3.0/                            # 已有
│   ├── v3.4.x/                            # 合并原 v3.4.0/ + active/ 归档
│   │   ├── design/                        # 🆕 (5 个设计文档)
│   │   ├── v3.4.0-macos-engine-embedding.deprecated.md  # 迁自原 archive/v3.4.0/
│   │   ├── guided-puzzle-design.md
│   │   ├── nnue-embedding-investigation.md
│   │   ├── r3-06c-spm-localization-fix.md
│   │   ├── r3-07-commercial-delivery-checklist.md
│   │   ├── replayboardview-design.md
│   │   ├── replayviewmodel-observableobject-migration.md
│   │   ├── v3.4.0-code-quality-audit-plan.md
│   │   ├── v3.4.0-ios-engine-implementation-plan.md
│   │   ├── v3.4.0-macos-phase-a.md
│   │   ├── v3.4.0-macos-phase-b.md
│   │   ├── v3.4.0-macos-phase-c.md
│   │   ├── v3.4.0-macos-phase-d.md
│   │   └── v3.4.0-macos-static-embed-common.md
│   ├── v3.5.x/                            # 🆕
│   │   └── v3.5.0-plan.md
│   ├── v3.6.x/                            # 🆕
│   │   ├── design/
│   │   │   ├── cmaes-parallel-design.md
│   │   │   └── quick-engine-toggle-design.md
│   │   ├── v3.6.0-audit-report.md
│   │   ├── v3.6.0-plan.md
│   │   ├── v3.6.0-q3-achievement-design.md
│   │   ├── v3.6.0-quest-restructure-design.md
│   │   └── v3.6.0-quest-restructure.md
│   ├── v3.7.x/                            # 🆕
│   │   ├── design/
│   │   │   ├── p0-engine-lifecycle-fix.md
│   │   │   └── p0-i18n-refactor-plan.md
│   │   ├── audits/
│   │   │   ├── audit-v373-dimension4-i18n.md
│   │   │   ├── v3.7.3-dimension3-code-quality.md
│   │   │   └── v3.7.3-dimension4-cross-review.md
│   │   ├── normalization-batch-1-2-task.md
│   │   ├── normalization-batch-3-4-6-task.md
│   │   ├── project-normalization-plan.md
│   │   └── v3.7.0-game-record-design.md
│   ├── v3.8.x/                            # 🆕
│   │   └── v3.8.0-design.md
│   └── v3.x/                              # 🆕 跨版本
│       └── v3x-comprehensive-audit-plan.md
├── assets/                                # 图片资源
│   ├── competitor_icons/                  # 🆕 12 个竞品图标
│   │   └── README.md                     # 🆕 图标来源说明
│   ├── app-screenshot.png
│   ├── built_ios_icon.png
│   ├── icon_A_source.svg                  # 🆕 迁自 DevTeam/docs/
│   ├── ios_60@2x.png
│   └── source_ios_icon.png
├── audits/                                # 审计报告（当前活跃）
│   ├── v3.7.3-audit-dimension1.md         # 🆕 迁自 DevTeam/docs/
│   ├── v3.7.3-audit-dimension2-review.md  # 🆕
│   ├── v3.7.3-audit-dimension5-review.md  # 🆕
│   ├── v3.7.3-audit-summary.md            # 🆕
│   ├── tactical-group-annotation-rules.md
│   ├── v39-d1-comparison.md
│   ├── v39-d1-game-logic.md
│   ├── v39-d1-sub1-piece-moves.md
│   ├── v39-d1-sub2-win-loss.md
│   ├── v39-d1-sub3-ai-engine.md
│   ├── v39-d2-playability.md
│   ├── v39-d3-ux-operability.md
│   ├── v39-d4-feature-completeness.md
│   ├── v39-d5-i18n.md
│   ├── v39-phaseb-summary.md
│   └── v52-improvement-proposal.md
├── bugs/                                  # Bug 记录
│   ├── bug4-fallbackId-collision-fix.md   # 🆕 迁自根级
│   ├── elo-baseline-split.md
│   ├── v3-gap-fixes.md
│   ├── v5.0.0-bug4-rendering-analysis.md  # 🆕 迁自 DevTeam/docs/
│   └── v5.0.0-real-device-bug-analysis.md # 🆕
├── design/                                # 设计文档（当前活跃）
│   ├── app-icon-redesign.md               # 🆕 迁自 DevTeam/docs/
│   ├── auto-demo-design.md                # 🆕 迁自 DevTeam/docs/design/
│   ├── ai-engine-improvements.md
│   ├── ai-search-optimization-phase3.md
│   ├── board-thread-safety-fix.md         # 🆕 迁自 DevTeam/docs/
│   ├── bundle-id-fix-design.md
│   ├── demoboard-replay-rendering-unify.md
│   ├── draw-detection-analysis.md
│   ├── ios-toolbar-adaptation.md
│   ├── master-game-demo-entry.md
│   ├── opening-book-expansion.md
│   ├── puzzle-demo-entry.md
│   ├── puzzle-difficulty-analysis.md
│   ├── puzzle-difficulty-rework.md
│   ├── tutorial-redesign.md
│   ├── ui-board-layout-optimization.md
│   ├── ui-entry-points-design.md
│   ├── v4.0-ai-difficulty-design.md
│   ├── v4.0-analysis-optimization.md
│   ├── v4.0-architecture-assessment.md
│   ├── v4.0-daily-challenge-modes.md
│   ├── v4.0-perpetual-chase.md
│   ├── v4.1-opening-explorer-evaluation.md
│   ├── v4.1-phase7.2-swift-testing-filter.md
│   ├── v4.1-plan.md
│   ├── v5.0-cross-quality-check.md
│   └── v5.0-opening-explorer-upgrade.md
├── general/                               # 通用文档
│   ├── doc-organization-analysis.md
│   ├── doc-reorganization-plan.md         # 🆕 本方案文件（迁自 DevTeam/docs/）
│   ├── observable-sheet-risk-analysis.md
│   ├── tech-debt.md                       # 🆕 迁自根级
│   ├── test-debt-cleanup.md               # 🆕 迁自根级
│   ├── test-infra-fix.md                  # 🆕 迁自根级
│   ├── test-infra-redesign.md             # 🆕 迁自 DevTeam/docs/
│   ├── 需求功能说明书.md                    # 🆕 迁自根级
│   └── test-rules.md
├── guides/                                # 使用指南
│   └── ios-deploy-guide.md
├── phases/                                # Phase 文档（当前活跃）
│   ├── demoboard-phase1.md
│   ├── v2-common.md
│   ├── v2-phaseB2.md
│   ├── v2-phaseB3.md
│   ├── v3.7.0-phase2.md
│   ├── v3.7.1-common.md
│   └── v3.7.1-phase3.md
├── spikes/                                # 技术调研
│   ├── elo-baseline-results.md
│   ├── eval-calibration-methodology.md
│   └── pikafish-gplv3-evaluation.md
└── user-guide/                            # 用户文档
    └── pikafish-setup.md
```

---

## 七、DEVTEAM.md 文档规范同步更新

### 需要更新的内容

DEVTEAM.md 中的 `### 目录结构` 和 `### 命名规则` 需同步更新：

### 建议的新规范

```markdown
### 目录结构
```
docs/
├── README.md          — 文档索引
├── design/            — 当前活跃的设计文档
├── phases/            — 当前活跃的 Phase 文档
├── audits/            — 审计报告
├── bugs/              — Bug 记录
├── spikes/            — 技术调研
├── general/           — 通用文档（PRD、技术债务等）
├── guides/            — 使用指南
├── user-guide/        — 用户文档
├── assets/            — 图片/图标资源
└── archive/           — 按版本归档的历史文档
    └── v<version>.x/  — 版本归档子目录
```

> **注意**：不再使用 `active/` 中间层。当前活跃文档直接放在根级分类目录中；
> 不活跃文档归档到 `archive/v<version>.x/`。

### 命名规则（不变）
- Phase 文档：`v3.x.0-phase-<name>.md`
- 调研文档：`<topic>-investigation.md` 或 `<topic>-evaluation.md`
- 归档文档放入对应版本子目录（如 `archive/v3.4.x/`）

### 新增：归档规则
- Phase 验收完成 → Cody 将文档从 `docs/<category>/` 移到 `docs/archive/v<version>.x/<category>/`
- 版本发布后 → 同上
- 跨版本通用文档（PRD、技术债务清单）不归档，保留在 `general/`
```

---

## 八、执行顺序

> ⚠️ 本方案只设计不执行。以下为 Luke 安排执行时的推荐顺序。

| 步骤 | 操作 | 风险 | 前置条件 |
|------|------|------|---------|
| 1 | 迁移方案文件到 `docs/general/doc-reorganization-plan.md` | 无 | 无 |
| 2 | 创建新目录（`archive/v2.x/`、`archive/v3.4.x/design/` 等） | 无 | 无 |
| 3 | 合并 archive/v3.4.0/ → archive/v3.4.x/，删除空目录 | 低 | 步骤 2 |
| 4 | 迁移 competitor_icons/ 到 assets/，创建 README.md | 低 | 步骤 2 |
| 5 | 迁移 DevTeam/docs/ 非重复文件 | 低 | 步骤 2 |
| 6 | 归档 active/ 文件到对应 archive/ 子目录（逐文件按§2.3表格执行） | 中 | 步骤 2 |
| 7 | 归档根级散落文件到分类目录 | 低 | 无 |
| 8 | 在 test-infra-fix.md / test-infra-redesign.md 头部加交叉引用注释 | 无 | 步骤 5、7 |
| 9 | 删除空目录（active/bugs/、reviews/、screenshots/） | 无 | 步骤 6 |
| 10 | 删除 active/ 目录 | 低 | 步骤 6、9 |
| 11 | 删除 DevTeam/docs/ 重复文件 | 中 | 步骤 5 |
| 12 | 删除 DevTeam/docs/ 整个目录 | 高 | 步骤 5、11 |
| 13 | 更新活跃文档引用（§9.1 清单，含 app-icon-redesign.md 的 12 处路径替换） | 低 | 步骤 5 |
| 14 | 更新 README.md 索引 | 无 | 全部完成 |
| 15 | 更新 DEVTEAM.md 文档规范 | 无 | 全部完成 |
| 16 | 更新 knowledge/document-conventions.md | 无 | 全部完成 |
| 17 | 清理 .DS_Store 文件 | 无 | 无 |

---

## 九、引用更新清单

### 9.1 需更新的活跃文档引用

以下引用存在于**当前活跃文档**中，迁移后会断链，**必须更新**：

| 文件 | 行 | 旧引用 | 新引用 | 说明 |
|------|-----|--------|--------|------|
| `docs/design/puzzle-difficulty-rework.md` | L6 | `~/DevTeam/docs/v3.6.0-quest-restructure-design.md` | `docs/archive/v3.6.x/v3.6.0-quest-restructure-design.md` | 关联文档引用 |
| `docs/design/app-icon-redesign.md`（迁后） | L52-63 | `~/DevTeam/docs/competitor_icons/XX.png`（12 处） | `docs/assets/competitor_icons/XX.png` | 竞品图标路径，12 处批量替换 |
| `docs/audits/v39-d4-feature-completeness.md` | L11 | `docs/active/v3x-comprehensive-audit-plan.md` | `docs/archive/v3.x/v3x-comprehensive-audit-plan.md` | 审计参考 |
| `docs/audits/v3.7.3-audit-summary.md`（迁后） | L114 | `~/DevTeam/docs/v3.7.3-audit-dimension1.md` | `v3.7.3-dimension1.md`（同目录） | D1 引用 |
| `docs/audits/v3.7.3-audit-summary.md`（迁后） | L115 | `~/DevTeam/docs/v3.7.3-audit-dimension2-review.md` | `v3.7.3-dimension2-review.md`（同目录） | D2 引用 |
| `docs/audits/v3.7.3-audit-summary.md`（迁后） | L116 | `docs/active/audits/v3.7.3-dimension3-code-quality.md` | `../archive/v3.7.x/audits/v3.7.3-dimension3-code-quality.md` | D3 引用（活跃→归档） |
| `docs/audits/v3.7.3-audit-summary.md`（迁后） | L117 | `docs/active/audit-v373-dimension4-i18n.md` + `docs/active/audits/v3.7.3-dimension4-cross-review.md` | `../archive/v3.7.x/audits/audit-v373-dimension4-i18n.md` + `../archive/v3.7.x/audits/v3.7.3-dimension4-cross-review.md` | D4 引用（活跃→归档） |
| `~/DevTeam/knowledge/document-conventions.md` | L33,85,92-103 | 多处 `~/DevTeam/docs/` 引用 | 更新为项目内路径或标注"已删除" | 知识库文档，需同步更新 |

### 9.2 可忽略的引用（已归档文档内部互引）

以下引用在迁移后会断链，但因其所在文件本身已归档，**不需要更新**（历史文档保留原始路径即可）：

| 文件 | 旧引用 | 说明 |
|------|--------|------|
| `active/project-normalization-plan.md`（→ archive/v3.7.x/） | 多处 `~/DevTeam/docs/` | 规范化方案的历史记录，保留原始描述 |
| `active/normalization-batch-1-2-task.md`（→ archive/v3.7.x/） | 多处 `~/DevTeam/docs/phases/` | 批次任务的 mv 命令历史，已执行完毕 |
| `active/v3x-comprehensive-audit-plan.md`（→ archive/v3.x/） | `docs/active/phases/v3.4.0-*` | 审计计划的历史参考 |
| `active/v3x-comprehensive-audit-plan.md`（→ archive/v3.x/） | `docs/active/phases/v3.5.0-plan.md` | 同上 |
| `active/v3x-comprehensive-audit-plan.md`（→ archive/v3.x/） | `docs/active/phases/v3.6.0-*.md` | 同上 |
| `active/v3x-comprehensive-audit-plan.md`（→ archive/v3.x/） | `docs/active/v3.6.0-audit-report.md` | 同上 |
| `active/design/v3.4.0-code-quality-audit-plan.md`（→ archive/v3.4.x/） | `docs/active/phases/v3.4.0-macos-static-embed-common.md` | 设计文档引用同版本 Phase 文档，归档后断链可接受 |
| `active/phases/v3.6.0-q3-achievement-design.md`（→ archive/v3.6.x/） | `~/DevTeam/docs/v3.6.0-quest-restructure-design.md` | 同版本文档互引，归档后断链可接受 |
| `active/phases/v3.6.0-quest-restructure-design.md`（→ archive/v3.6.x/） | `docs/active/phases/v3.6.0-quest-restructure.md` | 同上 |
| `active/phases/v3.6.0-quest-restructure-design.md`（→ archive/v3.6.x/） | `docs/active/phases/v3.6.0-plan.md` | 同上 |
| `DevTeam/docs/v3.7.3-audit-summary.md`（→ audits/） | D1-D4 审计子报告引用 | ⚠️ **已移到 §9.1**（此文件迁到活跃目录，引用需更新） |
| `DevTeam/docs/v3.6.0-q3-achievement-design.md`（→ 删除，重复） | `~/DevTeam/docs/v3.6.0-quest-restructure-design.md` | 重复文件，直接删除 |
| `DevTeam/docs/v3.6.0-quest-restructure-design.md`（→ 删除，重复） | `docs/active/phases/v3.6.0-quest-restructure.md` | 同上 |
| `DevTeam/docs/phases/v3.8.0-design.md`（→ archive/v3.8.x/） | `~/DevTeam/docs/v3.7.3-audit-summary.md` | 同为 DevTeam/docs/ 内互引，迁移后均在项目内 |
| `vocab-game/docs/improvement-plan.md` | `~/DevTeam/docs/vocab-game-v2-proposal.md` | 另一项目的文档，不在本次整理范围 |

---

*v1.2 方案审查通过，待 Luke 安排执行。*
