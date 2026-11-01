# T-1101-7 唤醒/投递基建修复批 · 执行判词（Cody）

> **执行**：Cody（编码，coder）｜**日期**：2026-11-02 00:15-01:20
> **派单**：洪涛 00:06 派令、丹妮派发（依据 11-01 三连摩擦实证）、终裁 Luke｜**DDL**：11-02 18:00
> **对象**：run-tests-mutex.sh（m1 工作树）+ deliver-retry.sh（新增 ~/DevTeam/scripts/）
> **验收口径**：三件各带修复前后对照实证 + 判词件落盘（本件）

---

## 〇、根因大发现（贯穿三件的公共真凶）

**bash 3.2.57 多字节变量名吞雷**（受控复现矩阵：`~/DevTeam/evidence/t1101-7-cody/locale-matrix.txt`）：

```
set -u; WAKE_RC=1; echo "rc=$WAKE_RC）end"
LC_ALL=任意UTF-8 → line 1: WAKE_RC<U+FF09>: unbound variable [REPRO]
LC_ALL=C / 无locale → rc=1）end [PASS]
```

- **机理**：macOS 系统 bash 3.2 在 UTF-8 locale 下，`$VAR` 后紧跟全角字符（`）（：，`）时变量名扫描把多字节字符吞进名字 → set -u 判 unbound → **脚本静默死亡**（无输出、退出非零）
- **毒源**：**python3 spawn 子进程强制 LC_CTYPE=C.UTF-8**（python locale coercion）——exec 直跑无 locale（前台全过），python3 setsid 子进程（survive/daemon）必带雷
- **消音器**：v1-v4 的错误行恰落在复合块 `2>/dev/null` 内被吞——v5 拆块才现形
- **波及面**：runner wake 钩子（v1-v6 五轮"静默死亡"）、deliver-retry enqueue/死信路径（mini2 实证 + daemon attempt#5 之死）、**疑似本机历史 nohup 静默死亡家族部分真因**（chinese-chess-test-batches skill 有 4 例在档）
- **修复**：双管——①两脚本 `export LC_ALL=C`（locale 优先级压倒一切继承）②`$VAR`-全角邻接位全部转 ASCII（runner 4 处 + deliver-retry 3 处，结构性根治）

## 一、R1 批完结回调唤醒 ✅

- **修复前**：11-01 实例——xcresult 18:14 落盘、锁已释、会话停摆 4h 至催办方收（历史同族 10+ 例）；本批 v1-v4 四轮 survive 模式 wake 全静默死（证据：`evidence/t1101-7-r1-v2~v6.log`）
- **修复内容**：wake_owner v6（EXIT trap → 主流程直调）+ deliver-retry 队列化投递 + ensure-daemon 按需拉活。设计要点：trap 只留清理（锁释放零拖延）；`openclaw agent` 对忙会话阻塞等轮完成（40s rc=124 实测）→ 全异步走 daemon；输入服务端持久入列 pendingInputs（忙会话轮毕即消费）
- **修复后实证**（v7 全链，`evidence/t1101-7-r1-v7.log`）：
```
[mutex] 获得锁 → FAIL(zero-run) 汇总 → [retry] 已入队 263 bytes → daemon 已拉起 pid=7880
→ [runner-wake] ✅ 已入队 agent:coder:main (批 rc=1) → 锁释放 → [lang-lock] 已恢复原值
```
唤醒 job 即刻在列（daemon 重试投递中——目标会话忙时指数退避，空闲即达）。**端到端最后一环**：唤醒消息将作为发起会话下一轮输入到达（本判词撰写会话的 pendingInputs 中有活体 job 在途）

## 二、R2 投递失败自动重试 ✅

- **修复前**：SESSION_WORK_START_CHANGED 中断滞留（lead 会话 5 条 pendingInputs 实测样本；interrupted 态 retained 且 never run automatically——session-tool.md 亲读）；Ruby 复跑 flock 排队死、/tmp/ruby-verify-t1101/run.log 0 字节至今
- **修复内容**：`~/DevTeam/scripts/deliver-retry.sh`——enqueue/daemon/ensure-daemon/status 四模式。job 落盘 `~/DevTeam/.locks/delivery-retry/`；daemon（python3 setsid 孵化+单实例守卫）backoff=BASE×2^(n-1) 重投；超限死信；`env -u OPENCLAW_SHELL` 剥 exec 标记走 agent 注入通道
- **修复后实证**（`evidence/daemon-lifecycle.log` + 队列状态）：
```
attempt#1 failed → backoff 20s → #2 → 40s → #3 → 80s → #4 → 160s → #5 → DEAD-LETTER(attempts=5)
```
完整指数退避生命周期活体走完；ensure-daemon 幂等拉活（v7 自动孵化 pid=7880）
- **语义边界**：不做「复活滞留输入」（pendingInputs 元数据不授权 replay——文档亲读）；只做发送侧重投，全程留痕。历史 5 条滞留处置归 lead sweep 人工重发

## 三、R3 flock 排队守护 ✅

- **修复前**：Ruby 复跑排队中死（11-01 三连摩擦③）；排队态不可观测
- **修复内容**：①`RUNNER_SURVIVE=1` 自剥离——runner 首行 python3 setsid 重执行自身（新会话脱离进程组、输出投固定日志、免疫父树连坐；调用方秒回 rc=0，完结态由 R1 唤醒送达）②排队/持锁可观测——`queue.state`（pid|owner|state|ts）+ `holder.state`，亡行留痕即被杀在队的诊断证据
- **修复后实证**（v1/v2/v4/v6/v7 五轮 survive 批）：
```
queue.state: 3415|cody|waiting|00:52:04 → 获得锁 00:52:13（持锁方释放后接管）→ holder.state → 完结清理
竞争实测：短持锁者（10-25s）+ 排队者 → 排队登记 → 到期获取 → 全链完成 ✓（改动后脚本过 flock 竞争门）
```

## 四、纪律对表

- 零扩面 ✓（两脚本 + 证据/判词件，无其他触碰）
- 不动 m1 主干业务码 ✓（run-tests-mutex.sh 为基建脚本非业务码；src/ 零触碰）
- Phase2bTests.swift 未动 ✓（判别锚工件原样工作树）
- 互斥脚本改动过 flock 竞争实测 ✓（五轮含竞争场景）
- 长任务脱离规约 ✓（全批 setsid 形态，零盯进程）

## 五、遗留与建议

1. **唤醒送达的最终一环**：唤醒 job 目标会话忙时指数退避重试（5 次封顶死信）——owner 长忙批次（>10min）可能死信；建议后续批评估 DELIVER_TIMEOUT/封顶与忙会话语义调优
2. **run-tests-mutex.sh 与 deliver-retry.sh 的工作树变更待审查链**（Luke 排程）；建议 runner 侧 `export LC_ALL=C` 与去全角两修复随审查入库
3. **bash 3.2 locale 雷入 known-issues**：团队所有 bash 脚本凡 `$VAR`-全角邻接 + python3 spawn 语境均暴露此面（修复模板：LC_ALL=C + 邻接位 ASCII 化）；历史 nohup 静默死亡 4 例建议复查是否同根
4. R2 的 5 条滞留 pendingInputs 样本处置：lead sweep 人工重发（非本批范围）

## 六、证据索引

- 复现矩阵：`~/DevTeam/evidence/t1101-7-cody/locale-matrix.txt`
- v1-v7 全链日志：`~/DevTeam/evidence/t1101-7-cody/t1101-r1-*.log`
- daemon 生命周期：`~/DevTeam/evidence/t1101-7-cody/daemon-lifecycle.log`
- 队列活态：`bash ~/DevTeam/scripts/deliver-retry.sh status`
- 受控复现脚本：`~/DevTeam/evidence/t1101-7-cody/loc-test.sh`

*Cody·科迪｜2026-11-02｜完成通报随发 Luke+丹妮｜审查链候 Luke 排程*
