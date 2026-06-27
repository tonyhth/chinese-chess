# 文档组织混乱问题分析与规范化方案

> 分析时间：2026-06-23 16:25
> 分析范围：workspace/tmp + 项目 docs/ 目录

---

## 📊 发现的问题

### 1. 审计报告散落（workspace/tmp）

**现状**：
- v3.1-comprehensive-audit-report.md（合并版）
- v3.1-phase1-2a-2b-implementation-audit.md
- v3.1-phase2c-implementation-audit.md

**问题**：
- workspace/tmp 是临时目录，审计报告应归档到项目 docs/ 下
- 三个报告内容重叠（合并版已包含全部信息）
- 命名不一致（implementation-audit vs comprehensive-audit）

---

### 2. 项目 docs 目录命名混乱

**现状**：
```
docs/
├── bug-position-analysis.md        （bug 分析）
├── bug-replay-crash-v2218.md       （bug 分析）
├── bugs/                           （bugs 子目录）
├── design/                         （设计文档）
├── phases/                         （Phase 设计）
├── qa-audit-round-1.md             （QA 审计）
├── qa-audit-round-2.md             （QA 审计）
├── qa-audit-round-3-fixes.md       （QA 审计）
├── ...
```

**问题**：
- bug-*.md 文件散落在根目录和 bugs 子目录，不一致
- qa-audit-round-*.md 命名不一致（有的带 -fixes，有的带 -ruby/-vera）
- r3-* 文件命名混乱（Phase？bug fix？）
- 缺少版本号组织（v2.2.18 的 QA 报告与 v3.1 混在一起）

---

### 3. 设计文档不完整（docs/phases）

**现状**：
```
docs/phases/
├── v2-phase6.md
├── v2-phase7.md
├── v3.1-phase2-design.md
```

**问题**：
- ❌ 缺少 v3.1-phase1-design.md（Phase 1 设计）
- ❌ 缺少 v3.1-plan.md（总体计划文档在 docs/ 根目录）
- Phase 2 拆分为 2a/2b/2c，但只有 phase2-design.md（Phase 2c）
- 命名不一致（v2-phase6 vs v3.1-phase2-design）

---

### 4. QA 审计命名不规范

**现状**：
- qa-audit-round-1.md（v2.2.18）
- qa-audit-round-2.md（v2.2.18）
- qa-audit-round-3-fixes.md（v2.2.18）
- qa-audit-round-3-ruby.md（v2.2.18）
- qa-audit-round-3-vera.md（v2.2.18）

**问题**：
- 缺少版本号标识（无法区分 v2.2.18 和 v3.1 的 QA）
- 角色特定报告（-ruby/-vera）命名混乱
- round-3 有多个文件（-fixes/-ruby/-vera），组织不清晰

---

## 🎯 规范化方案

### 1. 目录结构规范化

**建议结构**：
```
docs/
├── v2.2.18/                        （版本归档目录）
│   ├── qa/                         （QA 审计）
│   │   ├── round-1.md
│   │   ├── round-2.md
│   │   ├── round-3/
│   │   │   ├── fixes.md
│   │   │   ├── ruby.md
│   │   │   ├── vera.md
│   │   │   └── summary.md
│   │   └── plan.md
│   ├── bugs/                       （bug 分析）
│   │   ├── position-analysis.md
│   │   ├── replay-crash.md
│   │   └── ios-bugs.md
│   └── design/                     （设计文档）
│       ├── phase6.md
│       ├── phase7.md
│
├── v3.1/                           （版本归档目录）
│   ├── qa/                         （QA 审计）
│   │   ├── comprehensive-audit.md  （合并版审计报告）
│   │   ├── phase1-2a-2b-audit.md   （Phase 1/2a/2b 审计）
│   │   ├── phase2c-audit.md        （Phase 2c 审计）
│   │   └── plan.md                 （QA 审计计划）
│   ├── design/                     （设计文档）
│   │   ├── plan.md                 （总体计划）
│   │   ├── phase1-design.md        （Phase 1 设计）
│   │   ├── phase2a-design.md       （Phase 2a 设计）
│   │   ├── phase2b-design.md       （Phase 2b 设计）
│   │   ├── phase2c-design.md       （Phase 2c 设计）
│   │   └── opening-book-expansion.md
│   └── bugs/                       （验收发现的 bug）
│       ├── external-engine-bugs.md
│
├── design/                         （通用设计文档）
│   ├── ai-engine-improvements.md
│   ├── ai-search-optimization-phase3.md
│   ├── ios-toolbar-adaptation.md
│   └ ui-board-layout-optimization.md
│
├── guides/                         （指南文档）
│   ├── ios-deploy-guide.md
│   └── pikafish-setup-guide.md
│
└── spikes/                         （技术验证）
    └ elo-baseline-results.md
    └ eval-calibration-methodology.md
```

---

### 2. 文档命名规范

**版本归档目录**：`docs/v{version}/`

**QA 审计报告**：
- `docs/v{version}/qa/comprehensive-audit.md` — 合并版全量审计
- `docs/v{version}/qa/phase{N}-audit.md` — 单 Phase 审计
- `docs/v{version}/qa/round-{N}/` — QA 轮次归档

**设计文档**：
- `docs/v{version}/design/plan.md` — 总体计划
- `docs/v{version}/design/phase{N}-design.md` — Phase 设计

**Bug 分析**：
- `docs/v{version}/bugs/{bug-name}.md`

---

### 3. 具体操作步骤

#### 3.1 创建 v3.1 版本归档目录

```bash
mkdir -p ~/DevTeam/projects/chinese-chess/docs/v3.1/qa
mkdir -p ~/DevTeam/projects/chinese-chess/docs/v3.1/design
mkdir -p ~/DevTeam/projects/chinese-chess/docs/v3.1/bugs
mkdir -p ~/DevTeam/projects/chinese-chess/docs/guides
```

#### 3.2 移动审计报告

```bash
# 合并版审计报告作为主文档
mv workspace/tmp/v3.1-comprehensive-audit-report.md \
   ~/DevTeam/projects/chinese-chess/docs/v3.1/qa/comprehensive-audit.md

# Phase 1/2a/2b 审计作为参考
mv workspace/tmp/v3.1-phase1-2a-2b-implementation-audit.md \
   ~/DevTeam/projects/chinese-chess/docs/v3.1/qa/phase1-2a-2b-audit.md

# Phase 2c 审计作为参考
mv workspace/tmp/v3.1-phase2c-implementation-audit.md \
   ~/DevTeam/projects/chinese-chess/docs/v3.1/qa/phase2c-audit.md
```

#### 3.3 移动 v3.1 计划文档

```bash
mv ~/DevTeam/projects/chinese-chess/docs/v3.1-plan.md \
   ~/DevTeam/projects/chinese-chess/docs/v3.1/design/plan.md
```

#### 3.4 重命名设计文档

```bash
mv ~/DevTeam/projects/chinese-chess/docs/phases/v3.1-phase2-design.md \
   ~/DevTeam/projects/chinese-chess/docs/v3.1/design/phase2c-design.md
```

#### 3.5 归档 v2.2.18 文档（可选，后续处理）

---

### 4. 文档索引文件

创建 `docs/v3.1/README.md` 作为版本文档索引：

```markdown
# v3.1 文档索引

## 设计文档
- plan.md — 总体计划
- phase2c-design.md — Phase 2c 设计

## QA 审计
- comprehensive-audit.md — 全量审计报告（主文档）
- phase1-2a-2b-audit.md — Phase 1/2a/2b 审计
- phase2c-audit.md — Phase 2c 审计

## Bug 分析
- external-engine-bugs.md — 外部引擎验收发现的 bug

## 关键发现
- 完成率：55%（12/22 项已实现）
- P0 阻塞：4 项
- P1 重要：5 项
- P2 体验：5 项
```

---

## 📊 规范化收益

1. **版本隔离**：v2.2.18 和 v3.1 文档分离，避免混淆
2. **命名一致**：统一命名规范，易于查找
3. **归档清晰**：审计报告从临时目录归档到项目目录
4. **索引导航**：README.md 提供文档导航

---

## 结论

当前文档组织混乱的主要问题是：
- 版本未隔离（v2.2.18 和 v3.1 混在一起）
- 命名不规范（bug-*.md 散落）
- 设计文档不完整（缺少 Phase 1 设计）
- 审计报告在临时目录（workspace/tmp）

建议立即执行规范化方案，创建 `docs/v3.1/` 版本归档目录并移动相关文档。