# 棋谱自动演示 v2.2 — Phase 2：弃子点评 + 预生成数据 + BoardPlayer 抽取

> 通用设计见：docs/phases/v2-common.md
> 完整方案见：docs/design/auto-demo-design.md
> 前置：Phase 1 完成

---

## Phase 2 任务列表

| 任务 | 说明 |
|------|------|
| 弃子检测算法 | 完整序列前瞻分析 + 人工审核 |
| commentaries-index.json | 预生成点评数据（残局+大师对局） |
| BoardPlayer 抽取 | 从 ReplayViewModel + DemoViewModel 合并抽取 |
