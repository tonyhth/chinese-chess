# 技能质量监控方案 v0.2

**作者**: Alex（架构师）  
**日期**: 2026-04-12  
**版本**: v0.2（基于 Vera v0.1 审查清单修订 + 复审修正）  
**状态**: 待 Luke 定稿  

> **v0.1 → v0.2 核心变更**：砍掉 `.quality` 文件，只保留 JSONL 日志，运行时计算所有指标。单一数据源，消除双写一致性风险。
> **v0.2 复审修正**：累计失败（非连续）描述修正、failRate 规则 totalCalls 提升到 10、override 加 expires 字段、告警消息含失败类型分布。

---

## 1. 核心设计原则

1. **单写点**：只在一个地方写入——追加 JSONL 日志。不维护任何独立的状态文件。
2. **运行时计算**：所有指标（failCount、lastOk、连续 skip 天数等）从日志计算得出，不持久化中间状态。
3. **明确判定责任**：触发 skill 的 agent 负责标记执行结果，框架层负责捕获异常。
4. **冷启动安全**：新安装技能无历史数据时不触发告警，首次使用后开始累计。

---

## 2. 日志格式与存储

### 2.1 文件位置

```
memory/skill-usage/YYYY-MM-DD.log
```

按日期分文件，每天一个。解决 v0.1 单文件并发写风险和全量扫描问题。

### 2.2 JSONL 格式

每行一条记录：

```jsonl
{"ts":"2026-04-12T09:15:32+08:00","skill":"weather","status":"ok","agent":"main","note":"查询上海天气成功"}
{"ts":"2026-04-12T09:16:01+08:00","skill":"coding-agent","status":"fail","agent":"main","note":"Codex 超时，15分钟无输出","failType":"soft"}
{"ts":"2026-04-12T09:17:22+08:00","skill":"excel-xlsx","status":"skip","agent":"main","note":"用户上传的是 PDF，非 Excel，不匹配"}
{"ts":"2026-04-12T10:05:00+08:00","skill":"himalaya","status":"fail","agent":"main","note":"SMTP 连接超时","failType":"hard"}
```

### 2.3 字段定义

| 字段 | 必填 | 说明 |
|------|------|------|
| `ts` | ✅ | ISO 8601 时间戳，含时区 |
| `skill` | ✅ | 技能名称（与 SKILL.md 目录名一致） |
| `status` | ✅ | `ok` / `fail` / `skip` |
| `agent` | ✅ | 触发该 skill 的 agent 标识 |
| `note` | ✅ | 简短说明。`skip` 必填原因（如"不匹配文件类型"），`fail` 必填错误摘要 |
| `failType` | `fail` 时必填 | `hard`（超时/报错/崩溃，框架层捕获）或 `soft`（执行完成但未达预期效果，agent 判断） |

### 2.4 并发写入

同一分钟内多个 agent 触发 skill 的概率极低（当前只有丹妮一个主 agent）。即使偶尔出现：

- JSONL 每行独立完整，行交错最坏情况是某行损坏，晚回顾解析时跳过即可
- 如未来多 agent 并发频繁，引入文件锁或改为每 agent 独立日志文件

---

## 3. 执行结果判定

### 3.1 判定责任

| 情况 | 判定者 | status | failType |
|------|--------|--------|----------|
| 脚本/命令超时 | OpenClaw 框架自动捕获 | `fail` | `hard` |
| 脚本抛异常/返回非零 | OpenClaw 框架自动捕获 | `fail` | `hard` |
| 执行完成但结果不符合预期 | 触发 skill 的 agent（丹妮） | `fail` | `soft` |
| 执行完成，目标达成 | 触发 skill 的 agent（丹妮） | `ok` | — |
| 判断不适用，未触发 | 触发 skill 的 agent（丹妮） | `skip` | — |

### 3.2 写入时机

- **ok/fail**：skill 执行完毕后，agent 写入日志
- **hard fail**：如果 agent 崩溃来不及写，由框架层兜底写入（需要在 OpenClaw 层面实现，v0.2 暂不涉及，记为 TODO）
- **skip**：agent 判断不适用时，立即写入（含原因）

---

## 4. 指标计算（运行时）

### 4.1 计算时机

只在两个时点计算，不实时维护：

1. **晚回顾**（每日一次）—— 计算当日指标，检查告警阈值
2. **月度维护**（每月一次）—— 计算当月汇总，生成健康度报告

### 4.2 计算方法

从日志文件中读取近期数据，按 skill 分组计算：

```
给定时间窗口 W（晚回顾：当日；月度：近30天）

对每个 skill：
  records = 从日志中筛选 skill=name 且 ts 在 W 内的记录
  failCount = records 中 status=fail 的数量
  okCount = records 中 status=ok 的数量
  skipCount = records 中 status=skip 的数量
  lastOk = records 中 status=ok 的最后一条的 ts（无则为 null）
  totalCalls = failCount + okCount + skipCount
  failRate = failCount / totalCalls（totalCalls > 0 时）
```

### 4.3 告警规则

| 规则 | 阈值 | 告警级别 | 备注 |
|------|------|---------|------|
| 当日累计失败 | `failCount >= 3`（同一 skill） | ⚠️ 警告 | 少量调用场景：3 次失败已说明问题 |
| 当日 fail 率偏高 | `failRate > 50%`（totalCalls >= 10） | ⚠️ 警告 | 大量调用场景：半数以上失败 |
| 长期未成功 | `lastOk == null` 且调用跨度 > 14 天 | ⚠️ 警告 | 月度检查 |
| 长期未使用 | 近 60 天无任何记录 | 💤 建议归档 | 月度检查 |

**冷启动豁免**：skill 首次出现在日志中的 14 天内，"长期未成功"和"长期未使用"规则不触发。

### 4.4 告警流程

晚回顾发现告警时：

1. **告警目标**：发送到群聊（洪涛可观察，不强制要求行动）
2. **告警格式**：
   ```
   ⚠️ 技能质量告警
   - weather：今日失败 3 次（超时 2 次，解析错误 1 次）
   - 建议：检查天气 API 是否可用
   ```
3. **洪涛的决策选项**（非强制）：
   - 忽略（已知临时问题）
   - 手动标记 `status: paused`（见 4.5）
   - 排查修复

### 4.5 手动干预

通过 `memory/skill-override.json` 文件支持人工标记：

```json
{
  "himalaya": { "status": "paused", "reason": "邮件服务器迁移中", "expires": "2026-04-20" },
  "old-skill": { "status": "archived", "reason": "已废弃" }
}
```

- `paused`：该 skill 仍可触发，但质量告警规则对其豁免
- `archived`：该 skill 视为已归档，不参与质量统计
- `expires`（可选）：ISO 日期，晚回顾时检查是否到期，到期自动清除该条 override
- 此文件为人工维护，agent 只读不写

---

## 5. 日志生命周期

### 5.1 归档策略

按月归档，每月一个文件，不按行数阈值归档。

```
memory/skill-usage/
├── 2026-04-12.log    ← 当日
├── 2026-04-11.log
├── 2026-04-10.log
└── ...
```

### 5.2 保留期限

- 近 90 天日志：保留，用于指标计算
- 超过 90 天：月度维护时自动删除
- 月度维护汇总写入 `memory/skill-usage/monthly-summary.json`（长期保留）

### 5.3 月度汇总格式

```json
{
  "month": "2026-03",
  "skills": {
    "weather": { "ok": 45, "fail": 2, "skip": 8, "failRate": "3.6%" },
    "himalaya": { "ok": 12, "fail": 5, "skip": 0, "failRate": "29.4%", "note": "SMTP 不稳定" }
  },
  "alerts": ["himalaya failRate 偏高（29.4%），建议检查"],
  "generatedAt": "2026-04-01T06:00:00+08:00"
}
```

---

## 6. 与现有流程的集成

### 6.1 晚回顾

晚回顾增加以下步骤（在现有回顾流程末尾追加）：

1. 读取当日日志文件 `memory/skill-usage/YYYY-MM-DD.log`
2. 按 skill 分组统计 ok/fail/skip
3. 检查告警规则（§4.3）
4. 如有告警，发送到群聊（§4.4）
5. 检查 `skill-override.json`：清除已过期（`expires` 早于今日）的 `paused` 条目，未过期的不动

### 6.2 月度维护

月度维护增加以下步骤：

1. 读取近 30 天所有日志文件
2. 计算每个 skill 的月度汇总
3. 写入 `monthly-summary.json`
4. 检查长期未使用（60天）和长期未成功（14天）的 skill
5. 删除 > 90 天的日志文件
6. 清理 `skill-override.json` 中对应的已卸载 skill 条目

### 6.3 自进化审计

月度维护产出的 `monthly-summary.json` 作为自进化审计的输入：

- 如果某 skill 连续 2 个月 failRate > 30%，自进化审计应考虑替换或升级
- 如果某 skill 已 paused 超 30 天，自进化审计应考虑正式归档

> v0.1 中月度维护与自进化审计的关系不清，v0.2 明确了数据流向：月度维护 → monthly-summary.json → 自进化审计消费。

---

## 7. 实现要点

### 7.1 写入伪代码（agent 侧）

```python
def log_skill_usage(skill_name, status, note, fail_type=None):
    record = {
        "ts": now().isoformat(),
        "skill": skill_name,
        "status": status,  # ok / fail / skip
        "agent": "main",
        "note": note
    }
    if status == "fail":
        record["failType"] = fail_type  # hard / soft
    
    today = now().strftime("%Y-%m-%d")
    log_path = f"memory/skill-usage/{today}.log"
    append_line(log_path, json.dumps(record, ensure_ascii=False))
```

### 7.2 计算伪代码（晚回顾/月度维护）

```python
def compute_skill_stats(days_back=1):
    records = []
    for day in date_range(days_back):
        path = f"memory/skill-usage/{day}.log"
        if exists(path):
            records.extend(read_jsonl(path))
    
    # 加载 override
    overrides = read_json("memory/skill-override.json") or {}
    
    stats = {}
    for r in records:
        name = r["skill"]
        if name not in stats:
            stats[name] = {"ok": 0, "fail": 0, "skip": 0, "lastOk": None, "failTypes": []}
        s = stats[name]
        if r["status"] == "ok":
            s["ok"] += 1
            s["lastOk"] = r["ts"]
        elif r["status"] == "fail":
            s["fail"] += 1
            s["failTypes"].append(r.get("failType", "unknown"))
        else:
            s["skip"] += 1
    
    # 告警检查
    alerts = []
    for name, s in stats.items():
        override = overrides.get(name, {})
        if override.get("status") in ("paused", "archived"):
            continue
        total = s["ok"] + s["fail"] + s["skip"]
        # 生成失败类型摘要（如 "超时 2 次, API 404 1 次"）
        fail_summary = summarize_fail_types(s["failTypes"])
        if s["fail"] >= 3:
            alerts.append(f"{name}：今日失败 {s['fail']} 次（{fail_summary}）")
        if total >= 10 and s["fail"] / total > 0.5:
            alerts.append(f"{name}：fail 率 {s['fail']/total:.0%}（{total} 次调用中 {s['fail']} 次失败）")
    
    return stats, alerts
```

---

## 8. v0.1 → v0.2 变更对照

| # | Vera 审查问题 | v0.2 处理 |
|---|-------------|----------|
| 1 | 单文件并发写风险 | ✅ 按日期分文件 |
| 2 | `.quality` 被更新覆盖 | ✅ 砍掉 `.quality`，不存在此问题 |
| 3 | 失败定义模糊 | ✅ 明确 hard/soft 两层，§3.1 |
| 4 | skip 缺原因 | ✅ note 对 skip 必填原因 |
| 5 | 数据量未评估 | ✅ 按月归档，90天保留，§5 |
| 6 | 成功每次写磁盘 | ✅ 不再有 `.quality`，成功只追加一行 log |
| 7 | 晚回顾细节不足 | ✅ §4.4 明确告警目标/格式/决策 |
| 8 | 缺手动干预 | ✅ §4.5 `skill-override.json` |
| 9 | 月度维护与自进化关系不清 | ✅ §6.3 明确数据流向 |
| 10 | 双写复杂度高 | ✅ 单写点，运行时计算 |
| 11 | 新安装无基线 | ✅ 14天冷启动豁免 |
| 12 | 卸载后残留 | ✅ 月度维护清理 override + >90天日志自动删除 |

---

## 9. Vera 复审结论

v0.2 通过复审。4 个小问题已在文档中修正：
1. ✅ "连续失败"改为"累计失败"，与计算方法一致
2. ✅ failRate 规则 totalCalls 阈值从 5 提升到 10，与 failCount >=3 形成阶梯
3. ✅ override 加 `expires` 字段，晚回顾自动清理
4. ✅ 告警消息包含失败类型分布

Vera 对 3 个待确认项的回复：
- hard fail 兜底：v0.2 先不依赖，未来框架支持后加 `agentCrashes` 计数
- 告警持久化：不需要，群消息即持久化
- monthly-summary 保留 12 个月，超期删除
