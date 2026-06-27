# 中国象棋项目文档总索引

> 项目：Chinese Chess | 更新：2026-06-23

---

## 📁 文档目录结构

```
docs/
├── v2.2.18/                      # v2.2.18 版本归档
│   ├── qa/                       # QA 审计报告（13 个文档）
│   ├── bugs/                     # Bug 分析（4 个文档）
│   ├── design/                   # 设计文档（3 个文档）
│   └ README.md                   # v2.2.18 索引
│
├── v3.1/                         # v3.1 版本归档
│   ├── qa/                       # QA 审计报告（3 个文档）
│   ├── design/                   # 设计文档（5 个文档）
│   ├── bugs/                     # Bug 分析
│   └ README.md                   # v3.1 索引
│
├── design/                       # 通用设计文档
│   ├── ai-engine-improvements.md
│   ├── ai-search-optimization-phase3.md
│   ├── ios-toolbar-adaptation.md
│   ├── opening-book-expansion.md
│   └ ui-board-layout-optimization.md
│
├── guides/                       # 指南文档
│   └ ios-deploy-guide.md         # iOS 真机部署指南
│
├── bugs/                         # 通用 bug 分析
│   ├── elo-baseline-split.md
│   ├── v2221-analysis.md
│   ├── v2221-bug8-macos-replay.md
│   ├── v2221-ios-bugs.md
│   ├── v2.2.17-ios-bugs.md
│   └ v3-gap-fixes.md
│
├── spikes/                       # 技术验证
│   ├── elo-baseline-results.md
│   └ eval-calibration-methodology.md
│
├── general/                      # 通用文档
│   ├── test-rules.md             # 测试规则
│   ├── v2.1-checklist.md         # v2.1 清单
│   ├── v2.3-backlog.md           # v2.3 backlog
│   └ observable-sheet-risk-analysis.md
│
└── README.md                     # 本总索引文件
```

---

## 🎯 按版本查找文档

### v2.2.18（已发布）

**路径**：`docs/v2.2.18/`

**关键文档**：
- QA 总结：`qa/summary.md`
- 复盘崩溃 bug：`bugs/replay-crash.md`

**索引文件**：`docs/v2.2.18/README.md`

---

### v3.1（开发中）

**路径**：`docs/v3.1/`

**关键文档**：
- **全量审计报告**：`qa/comprehensive-audit.md`（主文档）
- **总体计划**：`design/plan.md`
- Phase 2c 设计：`design/phase2c-design.md`

**索引文件**：`docs/v3.1/README.md`

---

## 📊 QA 审计文档路径

| 版本 | 路径 | 关键文档 |
|------|------|----------|
| v2.2.18 | `docs/v2.2.18/qa/` | round-1.md ~ round-3.md, summary.md |
| v3.1 | `docs/v3.1/qa/` | **comprehensive-audit.md** |

---

## 📝 设计文档路径

| 类型 | 路径 | 说明 |
|------|------|------|
| 版本设计 | `docs/v{version}/design/` | 特定版本的 Phase 设计 |
| 通用设计 | `docs/design/` | AI 引擎、UI 通用设计 |

---

## 🐛 Bug 分析文档路径

| 类型 | 路径 |
|------|------|
| 版本 bug | `docs/v{version}/bugs/` |
| 通用 bug | `docs/bugs/` |

---

## 📖 指南文档路径

**路径**：`docs/guides/`

- iOS 真机部署指南：`ios-deploy-guide.md`
- Pikafish 集成指南：`pikafish-setup-guide.md`（待创建）

---

## 🔍 快速查找指南

| 查找内容 | 路径 |
|----------|------|
| v3.1 QA 审计结果 | `docs/v3.1/qa/comprehensive-audit.md` |
| v3.1 总体计划 | `docs/v3.1/design/plan.md` |
| v3.1 Phase 2c 设计 | `docs/v3.1/design/phase2c-design.md` |
| v2.2.18 QA 总结 | `docs/v2.2.18/qa/summary.md` |
| iOS 部署指南 | `docs/guides/ios-deploy-guide.md` |

---

## 📈 文档规范（2026-06-23 更新）

### 命名规范

- **版本归档目录**：`docs/v{version}/`
- **QA 审计**：`docs/v{version}/qa/`
- **设计文档**：`docs/v{version}/design/`
- **Bug 分析**：`docs/v{version}/bugs/`

### 文档索引

每个版本目录必须有 `README.md` 索引文件。

### 归档规则

- 版本发布后，所有相关文档归档到版本目录
- 通用文档（跨版本适用）放在 `docs/general/` 或对应子目录
- docs 根目录只保留子目录和总索引文件，不散落文档

---

## 🚨 当前任务（v3.1）

**第一批次 P0 任务**：见 `docs/v3.1/qa/comprehensive-audit.md`

---

**更新记录**：
- 2026-06-23：全面规范化文档组织，创建版本归档目录