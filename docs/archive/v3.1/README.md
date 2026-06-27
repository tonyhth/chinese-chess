# v3.1 文档索引

> 版本：v3.1 | 状态：开发中 | 更新：2026-06-23

---

## 📁 目录结构

```
v3.1/
├── qa/                          # QA 审计
│   ├── comprehensive-audit.md   # 全量审计报告（主文档）
│   ├── phase1-2a-2b-audit.md    # Phase 1/2a/2b 审计
│   └ phase2c-audit.md           # Phase 2c 审计
├── design/                      # 设计文档
│   ├── plan.md                  # 总体计划（Phase 1-3）
│   └── phase2c-design.md        # Phase 2c 详细设计
├── bugs/                        # Bug 分析
└── README.md                    # 本索引文件
```

---

## 🎯 设计文档

| 文档 | 说明 |
|------|------|
| **plan.md** | v3.1 总体计划（Phase 1-3，优先级 P0-P2） |
| **phase2c-design.md** | Phase 2c 详细设计（外部引擎设置界面 + 双引擎切换） |

**关键设计决策**：
- Phase 1：自研引擎自动调参（P0，2-3 周）
- Phase 2：macOS UCI 外部引擎支持（P1，1-2 周）
- Phase 3：评估规则扩充 + 搜索优化（P2，2-3 周）

---

## 📊 QA 审计报告

| 文档 | 说明 | 完成率 |
|------|------|--------|
| **comprehensive-audit.md** | 全量审计（Phase 1+2a+2b+2c） | **55%** |
| phase1-2a-2b-audit.md | Phase 1/2a/2b 审计 | Phase 1: 33% / 2a: 100% / 2b: 75% |
| phase2c-audit.md | Phase 2c 审计 | 45% |

**关键发现**：
- 🚨 P0 阻塞：4 项（外部引擎 bug + Phase 1 核心功能）
- ⚠️ P1 重要：5 项
- 📌 P2 体验：5 项
- ✅ 已解决：2 项

---

## 🚨 当前阻塞任务（第一批次 P0）

| # | 任务 | 状态 |
|---|------|------|
| 1 | 外部引擎走了玩家的棋 | 🔄 Cody 排查中 |
| 2 | 走法走棋方验证 | ⏳ 待实现 |
| 3 | CMA-ES 自动调参算法 | ⏳ 待实现 |
| 4 | 开局库扩展（4602→10000） | ⏳ 待实现 |

---

## 📝 QA 流程加固建议

**新增检查步骤**：
- R1：对照设计文档功能点清单逐项检查
- R2：设计文档完整性核验
- R3：设计文档逐项验证 + macOS/iOS UI 差异专项
- R4：设计文档 + 竞品功能对比

---

## 🔗 相关文档

**项目根目录**：`~/DevTeam/projects/chinese-chess/`

**通用设计文档**：`docs/design/`
- ai-engine-improvements.md
- opening-book-expansion.md

**指南文档**：`docs/guides/`
- ios-deploy-guide.md
- pikafish-setup-guide.md（待创建）

---

## 📈 版本进度

| 指标 | 状态 |
|------|------|
| 设计项总数 | 22 |
| 已实现 | 12（55%） |
| 未实现 | 8 |
| 部分实现 | 2 |
| 预估完成时间 | 6-10 天 |

---

**更新记录**：
- 2026-06-23：创建 v3.1 版本归档目录，规范化文档组织