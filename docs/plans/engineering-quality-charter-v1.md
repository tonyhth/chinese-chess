# 工程化质量保障规范 v1（Engineering Quality Charter v1）

> 起草：Alex（architect）｜2026-09-13｜依据：Luke 三方体检交叉裁决（Ruby 代码审查 / Tina 测试体系 / Vera 流程治理）
> 状态：**v1.2（2026-09-14 洪涛批准生效，Batch A 两件套启动）**
> 修订记录：v1（09-13 初稿）→ v1.1（09-13 Vera 审查修复 + Luke 定稿：P0×2/P1×7/P2×6，逐条见各节「v1.1」标记）→ v1.2（09-14 洪涛批准，看门狗方案换轨，变更记录见下）
> 定位：把"靠自觉的口头规范"变成"有机制兜底的制度"。本文是**规范正文 + 机制设计**，机制脚本的设计规格内嵌各节，实施归属见 §9 排期。

### v1.1 → v1.2 变更记录（2026-09-14，批准人：洪涛）

| 项 | 变更 | 理由 |
|----|------|------|
| 看门狗章节整体替换 | launchd agent 方案废弃 → **WorkBuddy 每日定时自动化（主哨）+ accept-gate 内嵌 macOS 原生通知（即时兜底）** | ① 宿主环境对 launchctl/plist 类操作拦截频繁（本周实证：unlink/sudo/ps 均被沙箱拦），自建 launchd 大概率踩权限坑；② launchd 提醒只达本机，用户不在场即失效；WorkBuddy 自动化结果直接进对话，用户在场性与可触达性远高于本机通知 |
| 心跳自证保留、形态改变 | 原脚本写心跳文件 → 自动化 prompt 要求**检查时附时间戳自证** | 设计思想不变（守望者自身必须可被检验），实现载体随主哨换轨 |
| Batch A 范围收窄 | 原三件套（TASK-LEDGER / accept-gate / watchdog+launchd）→ **两件套（TASK-LEDGER + accept-gate 含通知钩子）**；每日巡检由 Luke 建 WorkBuddy 定时自动化承载 | launchd 相关设计删除，timeline 对应工期划掉，Batch B/C 顺延不动 |

---

## 0. 背景与目标

### 0.1 为什么需要这份规范

三方体检结论一致指向同一个结构性问题：**代码与测试面的工程化水位较高（runner 互斥/预检/对账门规全在位），但流程规范的执行全靠自觉、无机制兜底**。实测已发生 8 天验证停滞（09-05 至 09-13），根因是四环全断：

| 环节 | 断裂形态 | 实证 |
|------|----------|------|
| 干了不留痕 | 工作完成但无任何记录 | 09-05 后 RUN-LEDGER 停更（Luke 08-18 纪律 08-25 衰减） |
| 留痕不回传 | 有记录但无人回传结论 | 台账类文件多处停更 |
| 回传无人催 | 派发后无超时检测 | 任务派发-回传闭环零机制（Vera P0-1） |
| 催办无机制 | 即使发现逾期也无升级通道 | "已派未结"状态根本不存在 |

另一实证：验收门禁纯约定——工作区现有 2 个未跟踪文件卡死验收却无人处理，而 `verify_delivery.sh [2/5]` 的树净检查是 **warn 不是 fail**（脚本 69-75 行），机制上"跑不过照样过"。

### 0.2 设计原则（每条规范自检三问）

1. **机制优先于口头约定**：能用脚本/cron/状态机保证的，不写"必须自觉遵守"。
2. **脚本优先于文档**：文档描述脚本做什么，而不是替代脚本。
3. **每条规范必须写明**：由什么机制保证、违反时如何被发现。写不出的条款降级为"惯例"标注，不算规范。

### 0.3 目标与非目标

- **目标**：任务闭环机制化（治 P0-1）、验收门禁脚本化（治 P0-2）、台账保鲜惯例、基建入库、并发条文、worktree 生命周期、测试体系落地序。
- **非目标**：不引入 CI（单机约束，见 §1.2）；不动 v6.4 主线需求与 Phase 拆分；不重写现有 runner（机制健全，只修缺口）。

---

## 1. 约束与机制选型基线

### 1.1 硬约束

- 单机（Intel macOS）、无 CI、无外部分页服务；7 个 agent 会话 + 1 个人类决策者（洪涛/Luke）。
- 团队沟通已有通道：飞书群 bot（Danny bot，230002 前鉴，08-16 Eric 首日清单已实测路由）。
- 已有可复用资产：`scripts/run-tests-mutex.sh`（flock 互斥+语言锁+预检+对账门规）、`scripts/verify_delivery.sh`（已入库）、`~/DevTeam/scripts/mkwt`、skip-registry 单源消费模式（awk 解析 markdown 表格——此模式已被证明可行，本规范复用）。
- 已有 cron 先例：RUN-LEDGER 中 p5-zd-harvest-wake / c4121492 one-shot cron（长跑批 ETA 唤醒）。

### 1.2 机制选型：WorkBuddy 定时自动化（主哨）+ one-shot cron（辅哨）+ 哨兵测试（域内）（v1.2 换轨）

**v1.2 变更**：原 v1.1 选定 launchd agent 作周期巡检主哨，洪涛 2026-09-14 裁定废弃换轨（宿主沙箱对 launchctl/plist 类操作拦截频繁，本周 unlink/sudo/ps 均被拦实证；且本机通知在用户不在场时失效）。候选路径对比更新如下：

| 路径 | 优点 | 缺点 | 裁定 |
|------|------|------|------|
| **WorkBuddy 定时自动化**（每日 09:00，检查 TASK-LEDGER 新鲜度 + 列超期项，结果直接进对话） | ① 提醒直达用户视野（对话界面），不依赖用户主动看本机文件；② 由宿主平台承载调度，无 launchctl/plist 权限面；③ 检查逻辑写在 prompt 里，迭代即改文案，无需脚本装机 | 触达依赖用户打开 WorkBuddy 会话；每日一档，无小时级响应 | **采用，作每日巡检主哨（A 档，洪涛已批准）**。Luke 建一条每日 09:00 自动化 |
| **macOS 原生通知**（accept-gate.sh 内嵌 osascript display notification） | 即时弹达（验收门被卡的当下就响，不等次日巡检）；零装机成本 | 只达本机；无聚合能力 | **采用，作即时兜底**：验收门卡住 = 最需要用户立刻知道的时刻，正好补每日巡检的响应粒度缺口 |
| **launchd agent**（v1.1 原方案） | 睡眠唤醒补跑；PATH 在 plist 显式声明 | **宿主沙箱拦截 launchctl/plist 类操作（本周实证），大概率装不上；装上了提醒也只达本机** | **废弃（v1.2）**。其"PATH 显式化"的设计教训由 §2.4 通知钩子与 cron 用法显式 export PATH 延续吸收 |
| **cron（one-shot）** | 先例在案（p5-zd-harvest-wake）；针对单一批次的 ETA 唤醒最轻量；用完即删不留常驻 | 错过即错过不补跑；PATH 极简需显式 export | **保留，仅限长跑批 ETA 定点唤醒**（沿用先例口径） |
| **哨兵测试**（RunnerHygieneTests 模式，判红即拦） | 与测试批强绑定、已在位、有 commit 1b70818 先例 | **非时间驱动**——只在有人跑测试批时才活；超时升级需要的是"没人动的时候也要响"，哨兵测试做不到 | **仅用于域内纪律**（runner 卫生、并发 lint），不承担台账超时巡检 |

裁定理由总结：超时升级的本质是**时间驱动 + 用户可触达**。WorkBuddy 自动化把巡检结果送进用户每天会看的对话流（主哨），accept-gate 通知在验收卡住的瞬间弹达（即时兜底），两者互补覆盖"每日盘点"与"当场反馈"两个时间粒度；cron one-shot 保留长跑批 ETA 唤醒；哨兵测试回归运行时纪律拦截。launchd 的两个原始论据（睡眠补跑、PATH 显式）分别由"每日 09:00 常驻档位天然容错过"与"cron/通知钩子显式 export PATH"承接，设计教训不因方案废弃而流失。

---

## 2. 任务闭环机制（治 P0-1，最高优先）

### 2.1 任务台账 TASK-LEDGER 设计

- **位置**：`~/DevTeam/TASK-LEDGER.md`（与 RUN-LEDGER 同级）。理由：任务横跨主树与多个 worktree，放仓内会被 worktree 隔离和分支合并冲掉；RUN-LEDGER 放 DevTeam 根的先例已验证此布局。
- **形式**：单文件、追加式、机器可解析管道表（复用 skip-registry 被 awk 消费的模式）。**不允许**自由叙事段落混入表区（表区外备注区放开）。

**表结构（每任务一行）**：

```
| ID | 任务名 | Owner | 派发时刻 | Deadline | 状态 | 证据路径 | 备注 |
```

- `ID`：`T-YYMMDD-n`（当日序号），派发时生成，永不复用。
- `Deadline`：ISO 时刻 `YYYY-MM-DD HH:MM`，必填——没有 deadline 的行 watchdog 判格式非法。
- `状态` 状态机（严格枚举，watchdog 校验）：

```
dispatched（派发）──→ wip（在制）──→ returned（回传）──[accept-gate 绿]──→ accepted（销账=终态）
     ↑                   ↑                │                            └→ rework（验收驳回，回到 wip）
     └───── rework（返工）┘                │
                                          └→ cancelled（撤销=终态，v1.1 增）
任何非终态（cancelled 除外）──超时──→ escalated（升级，Luke 介入；处理后回 wip 或裁定终态）
```

- `cancelled`（v1.1，Vera P1-②）：终态，**仅 Luke/派发者可写**；备注必填撤销原因 + 并入他批的 task-id。治"滚动并入他批的单永远挂 dispatched 致告警疲劳"——撤销是显式动作不是静默消失。watchdog 对 cancelled 静默。

- `证据路径`：回传时必填（审查报告/测试日志/验收报告的绝对路径），`returned`/`accepted` 状态证据路径为空 = watchdog 判非法。

**阈值分级（写入派发模板）**：

| 任务类别 | 超时阈值 | 说明 |
|----------|----------|------|
| 快验类（七锚快验/冒烟/单 suite 验证） | **24h** | 起跑分钟级，24h 足够含一轮排队 |
| 增量审（Ruby 代码审查/小型修复批） | **12h** | 审查是流水线卡点，超时直接堵下游 |
| 长跑批（全量/Elo/SPRT/自对弈） | **ETA + 25% 缓冲** | 派发时登记 ETA；ETA 时刻起 one-shot cron 唤醒收割巡检（p5-zd-harvest-wake 模式）；watchdog 以 ETA+缓冲为升级线 |
| 机制建设/设计类 | 48h | 本规范类任务 |

### 2.2 动作定义（谁在什么时候写什么）

| 动作 | 执行者 | 写入内容 |
|------|--------|----------|
| **派单即登记** | 派发者（Luke 或受托派单人） | 派发瞬间追加一行：ID/任务名/Owner/派发时刻/Deadline/dispatched。**无台账行的派单视为未派发**——工单模板（docs/general/ticket-template.md）同步加"台账行"必填项 |
| **接单转在制** | Owner | 状态 dispatched→wip（可选但建议，watchdog 对 dispatched 与 wip 同等催办） |
| **回传即登记** | Owner | 状态→returned + 证据路径必填。回传报告发 Luke 的同时必须改台账——**报告发了台账没改 = 未回传**（治"留痕不回传"环） |
| **验收（两段式，v1.1 改——治 P0-1 时序自指）** | Luke | ① 人工审查通过 → ② 跑 accept-gate（第 3 查口径 = **returned 且证据路径非空**，不是 accepted——gate 跑在销账之前）→ ③ **gate 全绿才允许写 accepted（销账 = gate 绿之后）**。驳回则→rework 并备注理由。"报了不裁"由 watchdog 的 returned 滞留 >24h 检查兜底（治"回传无人催"环） |
| **升级** | watchdog（自动）或任何人（手动） | 状态→escalated + 备注 `ESCALATED@时刻:原因`。升级通知见 §2.3 |
| **撤销** | Luke/派发者（v1.1 增） | 任何非终态→cancelled，备注必填：撤销原因 + 并入他批 task-id |

**写入协议（v1.1，P0-2 治并发写丢行）**：台账是 7 会话共享的单文件，无锁读-改-写会静默丢失更新——被抹掉的 dispatched 行对 watchdog 不可见，等于机制上复现"派了没人催"。因此：

- **一切写操作（追加行/改状态）必须经** `flock -x ~/DevTeam/.locks/task-ledger.lock`（.locks 目录已存在），锁内完成"读全文件→改→临时文件写回→原子 mv"全文件重写，禁止锁外局部编辑（sed -i 直改即违规形态）。
- **watchdog 只读、不加锁**（无死锁面，脏读无害——读到旧态只会多催一次，不会漏催）。
- 写协议违反的发现路径：Vera 月度审计抽查台账**行数单调性**（行只增不减，销账/撤销改状态不删行；行数回退 = 并发写事故实锤）。

### 2.3 每日巡检：WorkBuddy 定时自动化（v1.2 换轨，替代原 task-watchdog.sh + launchd）

- **载体**：Luke 在 WorkBuddy 建一条**每日 09:00 定时自动化**（A 档，洪涛已批准）。检查逻辑写在 automation prompt 里，无脚本装机、无 launchctl 权限面。
- **检查项**（原 watchdog 检查单全量继承，由自动化执行；每项独立报告，不互相短路）：
  1. **格式合法性**：TASK-LEDGER 表区每行 8 列、日期可解析、状态在枚举内、returned/accepted 行证据路径非空。非法行 → 报告并计入超期件。
  2. **超时催办**：非终态（**cancelled 静默**，v1.1）且 now > deadline → 超期件（分级：过期 <12h 标 `OVERDUE`，≥12h 标 `OVERDUE-SERIOUS`）。
  3. **回传滞留**：returned 且滞留 >24h → Luke 提醒件（"报了不裁"兜底）。
  4. **RUN-LEDGER 联检**：`运行中 | ETA=<ISO>` 行超过 ETA+缓冲 → 提醒件（第二张表）。
  5. **台账新鲜度**：TASK-LEDGER / WT-REGISTRY 文件 mtime——超过 72h 无任何更新即报告"台账疑似停摆"（09-05 至 09-13 停滞形态的针对性探针）。
  6. **worktree 卫生**：`git worktree prune`（幂等）+ `git worktree list` 与 WT-REGISTRY 比对（未登记告警，§7.2）+ prunable 残留检测。
  7. **时间戳自证**（心跳自证的 v1.2 形态）：报告**首行**必须附本次检查执行时刻 + 上次台账最后修改时刻——"报告自己何时跑的"成为报告的一部分，任何人读到无时间戳报告即视为无效报告；digest 文件超 26h 无新增 = 巡检本身停摆，用户在会话里"今天 09:00 没看到报告"即为最直接的可见信号（守望者之死必须可被发现，此性质在会话流里天然成立）。
- **动作权限**：自动化对超期项**可直接执行升级动作**——按 §2.2 写入协议（flock 加锁）翻 escalated + 备注；保守档 = 仅报告进对话由 Luke 确认后翻（ Luke 建 prompt 时二选一并写明档位）。
- **留痕**：自动化每次运行把报告追加至 `~/DevTeam/escalations/digest-YYYY-MM-DD.md`（审计链保留——月度审计抽查的输入源不因换轨而断档）。
- **升级触达**（三级，全部机制内）：
  1. 台账行状态翻转 escalated（内带通道，Luke/任何会话读台账即见）；
  2. 每日自动化报告直接进对话（主触达——用户每天看到的地方）+ digest 留痕（外带审计）；
  3. 若已配置飞书 escalation hook 则同步推送——**推荐项：一周内配置**（Luke 拍板洪涛确认）；未配置期间 1+2 已闭环兜底，机制有效性不依赖它。

### 2.4 即时兜底：accept-gate 通知钩子（v1.2，替代原 launchd agent 配置节）

- **实现**：accept-gate.sh 在**任一查 fail 时**内嵌执行：
  `osascript -e 'display notification "验收门未过（<phase-label> <task-id>）：<失败项摘要>" with title "chinese-chess accept-gate"'`
  （失败摘要取 gate 输出的首个 ❌ 行；osascript 失败静默——通知是兜底不是依赖，绝不让通知故障影响 gate 退出码。）
- **设计理由**：验收门被卡的当下 = 最需要用户立刻知道的时刻，每日巡检的最坏响应粒度是 24h，通知钩子把这个场景补到秒级；且零装机成本（osascript 系统自带，无权限面）。
- **PATH 纪律延续**（launchd 教训的载体转移）：gate 脚本与其内嵌命令一律**显式 PATH 处理**（脚本头 `export PATH=/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH`）——flock 在 /usr/local/bin 不在默认 PATH 的 4h 锁等待教训，在 v1.2 由"凡调度类/工具类脚本必须自带 PATH export"条款制度化（cron one-shot 唤醒同理）。
- **巡检停摆的发现路径**（v1.2 形态）：① 会话里当日 09:00 无报告（用户直接可见）；② digest 文件超 26h 无新增；③ 报告缺时间戳自证 = 无效报告。三者任一可见。

### 2.5 治理映射（四环对账）

| 断裂环 | 机制覆盖 |
|--------|----------|
| 干了不留痕 | 任务行全程状态机 + RUN-LEDGER 联检（§2.3 第 4 项） + 台账新鲜度探针（§2.3 第 5 项，v1.2） |
| 留痕不回传 | 回传动作定义 = 改台账 + 证据路径强制（§2.2） |
| 回传无人催 | 每日 09:00 自动化超时/滞留检查（§2.3 第 2/3 项）+ accept-gate 通知即时兜底（§2.4） |
| 催办无机制 | escalated 状态 + 升级触达三级（§2.3） |

---

## 3. 验收门禁脚本化（治 P0-2）

### 3.1 accept-gate.sh 设计

- **位置**：仓内 `scripts/accept-gate.sh`（入库，与 verify_delivery.sh 同目录）。
- **用法**：`bash scripts/accept-gate.sh <phase-label> [<task-id>]`，例如 `bash scripts/accept-gate.sh phase-2a T-0913-1`。
- **验收三查**（任一 fail 即退出码 1，**零 warn 档**——验收不是交付，没有"带病通过"）：

| # | 检查 | 实现 | 治什么 |
|---|------|------|--------|
| 1 | 树净 | `git status --porcelain` 为空（未提交+未跟踪都算不净） | 当前 2 个未跟踪文件卡验收无人处理的形态；`verify_delivery.sh [2/5]` warn-only 的洞（69-75 行） |
| 2 | Phase commit 存在 | `git log --extended-regexp --grep="^(feat\|fix\|refactor\|test)\(${label}\)"`（v1.1 修：ERE + 锚定行首 + 四 type 全含 + label 做正则转义）至少 1 条命中 | DEVTEAM 铁律"Phase 完成必须提交"从清单条文变成脚本判定。原草案 BRE 裸括号永不匹配——首跑必红且会被随手改宽松（Vera P1-③），此查的正则正确性本身列 gate 脚本自测用例 |
| 3 | 台账已回传 | TASK-LEDGER 中 `<task-id>` 行状态 = **returned 且证据路径非空**（v1.1 修：不查 accepted） | 验收与任务闭环咬合。**v1.1 两段式（治 P0-1 时序自指）**：若查 accepted，则"验收第一步跑 gate"时销账尚未发生，第 3 查必红——验收动作本身会改变它查询的状态。改为查 returned 后，时序成立：人工审查→gate 三查（returned 在场）→gate 绿→Luke 才写 accepted 完成销账 |

- **审计留痕**：每次运行把完整输出追加到 `~/DevTeam/evidence/accept-gate/gate-<phase>-<date>.log`。验收报告必须粘贴 gate 输出——**无 gate 输出的验收报告无效**（Vera 流程审查的检查点）。
- **执行位（v1.1 两段式）**：Luke 验收动作定义——① 人工审查通过 → ② 跑 accept-gate → **gate 红 = 验收中止，不进入销账动作**；gate 绿 → 写 accepted 销账。脚本不过 = 验收不成立。写入 DEVTEAM.md 铁律区（§6 草案同步含此条）。

### 3.2 与 verify_delivery.sh 的整合

两者是**两道不同的门**，不合并、不嵌套调用，但共享判定口径：

| 脚本 | 门 | 触发时机 | 树净语义 |
|------|-----|----------|----------|
| `accept-gate.sh` | Phase 验收门 | 每次 Luke 验收 | **fail**（验收时树必须净） |
| `verify_delivery.sh` | 打包交付门 | 每次打包发版 | **warn→fail 升格**（同 commit 改 69-75 行；交付时树不净同样是事故形态——版本边界对应不上，v3.8.2→v5.0.1 的 86 文件教训） |

**v1.1 补（Vera P1-①，R4 对策实质化）**：`[3/5]` 禁止清单须与 warn→fail **同 commit** 扩充——增加 `*.png`（根目录级）与 `.build-test-cache/`。Vera 实核：已入库的 8.4MB 违规件（截图×4+诊断文件）恰好全在现有两类检查面之外，不扩充则"防误收"对策是空的。此项为 §5.3 收编 commit 链的**②前置**（先扩检查面、再清退旧违规件，清退结果由扩充后的检查反向验证）。

理由：合并会让打包门承担验收语义（打包可能发生在非验收时刻，如 repack），嵌套调用则失败归因混淆。共享口径 = 都以 `git status --porcelain` 为唯一真相源。

### 3.3 违反时如何被发现

gate 日志留痕（evidence/accept-gate/）+ 验收报告必须附输出 → Vera 月度流程审计抽查 gate 日志与验收报告一一对应；对不上 = 流程违规件，进 Luke 周会清单。

---

## 4. 台账保鲜惯例

### 4.1 tech-debt 与版本发布强制对账

- **规则**：每次打 tag 发版，`scripts/techdebt-reconcile.sh` 必须跑过（exit 0）才能打包。
- **脚本设计**：解析 tech-debt.md 各 TD 条目的涉及文件/模块字段 → 逐条核验：① 文件存在性（TD-002 指向已删文件的形态）；② grep 关键符号是否仍在（TD-001 已修未勾的形态）；③ 输出漂移报告（条目 vs 代码现实），漂移 = exit 1 + 待办清单（勾销/改写/重开）。
- **机制保证**：对账脚本挂进发版 checklist 的脚本位（打包前必跑，同 verify_delivery），不跑就打包 = gate 日志缺档，§3.3 审计可见。
- **归属**：脚本实现 Cody（#7 批顺手），对账执行 Ruby（复审她审查域的账）。
- **v1.1 补（Vera P2）**：tech-debt.md 先落最小机器可读表结构——每条目四字段 `ID / 状态 / 涉及文件 / 关键符号`（表区外自由叙事保留不动）；**reconcile v1 只做文件存在性层核验**，符号 grep 层待表结构普及后升级——对自由叙事文本做强解析只会制造假红。

### 4.2 README 版本行进发版流程

- 发版 checklist 增加两步：① `check-readme-version.sh`（README 版本串 vs 最新 tag 比对，进 techdebt-reconcile 同一入口）；② **README 命令块与 DEVTEAM.md 单源对齐**——README 中出现的构建/测试命令必须从 DEVTEAM.md 复制，Vera 发版时抽查（当前 README 教新人裸跑命令、与 DEVTEAM 打包路径互矛盾的三重漂移，靠此步堵新增，存量由 Eric #8 批清偿）。
- **打包路径口径修正（v1.1，Vera P2）**：统一为**根目录构建产物、发版产物归档 `releases/`**——随 Eric #8 批落 README 与 DEVTEAM 对齐，本规范不重复展开细则。

### 4.3 RUN-LEDGER 终态回填规则

- **规则**：起跑行（已有惯例，**v1.1 定机器可读格式：`运行中 | ETA=<ISO时刻>`**——watchdog ETA 联检的解析依据，无 ETA 的运行中行判格式非法）+ 终态行（新增强制）：批次结束 1h 内回填终态；`运行中` 行被 watchdog ETA 联检（§2.3 第 4 项）盯住，ETA 超时未回填进当日 digest。**存量 2 条悬挂"运行中"行 Batch A 人工销案（Tina，v1.1 P2）**。
- **机制保证**：长跑批起跑时同时登记 one-shot cron 唤醒（ETA 时刻），唤醒动作 = 巡检产物 + 无人处理则写 digest——复用 p5-zd-harvest-wake 先例，把它从"单次发明"升级为"标准动作"。

---

## 5. 基建入库方案

### 5.1 现状与风险

- 仓内 `scripts/` 32 项仅 5 项跟踪；`~/DevTeam/scripts/` 完全在 git 外（单机单点，mkwt/preflight 等核心基建丢了就没了）。
- `.gitignore` 当前形态：`scripts/*` + `*.py` + `*.sh` 全局忽略 + `!` 逐项豁免（结构性风险：**新增基建默认被忽略，入库靠记得加 `!` 行**——与"规范靠自觉"同构的问题）。
- 8.4MB 违规产物已入库（截图×4+诊断文件），先清退再收编，防收编 commit 混入。

### 5.2 收编范围裁定

**必须入库（仓内 scripts/）**——判定标准：任何出现在 DEVTEAM.md 规范命令里的脚本、或验收/测试链依赖的脚本：

| 脚本 | 状态 | 动作 |
|------|------|------|
| run-tests-mutex.sh / verify_delivery.sh / build-release.sh | 已跟踪 | 无 |
| test-batch.sh / test-full.sh / test-runner.sh / test-phase1a2.sh | 未跟踪 | Tina 先裁定哪些仍活着（Phase1 系名暗示陈旧），活的入库、死的删除 |
| build-app.sh / fetch-arm64-pikafish.sh | 未跟踪 | 入库 |
| accept-gate.sh / techdebt-reconcile.sh / check-readme-version.sh / lint-concurrency.sh | 新建 | 入库（§3/§4/§6 产物） |

**必须入库（~/DevTeam/scripts/）**：preflight-test-assets.sh、mkwt、deploy-ios.sh、onboard-verify.sh、sprt_eval.py、sprt_sim.py、paired_diff_ci.py（v1.2 删 task-watchdog.sh——每日巡检由 WorkBuddy 自动化承载，不再是脚本件）。**入哪个仓**：建议在 `~/DevTeam` 建 git 仓（.gitignore 只排 evidence/ 日志类）——不进 chinese-chess（它们服务多项目），继续裸放则单点风险原样保留。Luke 拍板项。

**豁免**：一次性分析脚本（analyze_* 全家）、C 源码+编译产物（analyze_*.c/.app）、JSON/MD 报告（difficulty_scores.json 等）、traditional-puzzles 数据、__pycache__。**动作**：豁免项中仍有个体价值的，移出 `scripts/` 至 `~/DevTeam/analysis/` 归档，让 scripts/ 回到"纯基建"语义（根目录卫生规范的一部分）。

**去重**：verify_delivery.sh 在两处各有一份——裁仓内为单源，DevTeam 侧留薄 wrapper（`exec` 转发），防止双份漂移（README 三重漂移同款风险）。

### 5.3 .gitignore 白名单化方向

- **目标形态**：`scripts/` 目录**默认跟踪**，忽略规则改为显式黑名单（只忽略明确产物型：`*.app`、`*.json` 报告、`__pycache__`）；全局 `*.py`/`*.sh` 忽略行**删除**，由 §5.2 裁定表决定去留。
- **迁移三步**（一个 commit 链）：① 8.4MB 违规产物 `git rm --cached` 清退 + gitignore 补漏 + **verify_delivery [3/5] 禁止清单扩充（`*.png` 根目录级 / `.build-test-cache/`，与 warn→fail 同 commit）——先扩检查面再清退，清退结果由扩充后的检查反向验证（v1.1，Vera P1-①）**；② 收编 commit（`git add` 按 §5.2 裁定表逐文件，配合扩充后的 [3/5] 禁止文件检查防误收）；③ gitignore 规则翻转 commit（删全局忽略行）。
- **机制保证**：翻转后"新增基建默认入库"，反向风险（误收产物）由 verify_delivery [3/5] 禁止文件检查 + 收编后首月 Vera 抽查兜底。
- **风险与对策**：gitignore 翻转可能暴露历史上被全局忽略的其他杂散文件 → 第 ② 步前先 `git status --dry-run` 全量盘点，杂散文件按 §5.2 豁免规则处置完再翻转。

---

## 6. 并发规范条文（DEVTEAM.md 增补草案，可直接粘贴）

> 粘贴位：DEVTEAM.md「Git 规范」之后新建一级章节。起草 Alex，Ruby（并发审查域主）复核措辞，Luke 定稿合入。
>
> **v1.1 增补修订指令（Vera P1-④，防三头口径）**：合入并发章节的同一 commit，必须**整体替换** DEVTEAM.md 两段旧验收清单——「Luke 验收检查清单增加」代码块（L24-28 一带，git log/git diff 手工两行）与「丹妮 Phase 验收门禁」段（L185-192 一带）——统一替换为一行：
> `验收第一步：bash scripts/accept-gate.sh <phase-label> <task-id>，输出贴进验收报告；gate 绿后写台账 accepted 销账。`
> 旧三查条文已被 gate 脚本全量覆盖，保留旧文 = 第三套口径漂移源（README 三重漂移同款病灶，此处不让它再发生一次）。

```markdown
## 并发规范（2026-09 起，chess-quality-audit 产线）

> 背景：三方体检确认并发三范式混用——引擎域 actor 纪律好，ViewModel 域是洼地
>（AnalysisViewModel 无 @MainActor 无重入防护，Ruby P1-①）；TD-002 揭示 continuation
> 不响应取消导致测试僵死。本节条文全部有机制对应（见各条"机制"行）。

### C-1 @Observable ViewModel 隔离
- 所有 `@Observable` ViewModel 类**必须**标注 `@MainActor`。
- 涉及 UI 状态的方法在入口做重入防护（in-flight guard 或 task 取消旧任务）。
- 机制：`scripts/lint-concurrency.sh` 进 accept-gate 预检——扫描 `@Observable` 类缺
  `@MainActor` 标注即 fail；存量豁免清单显式登记（豁免行须带理由与清偿 Phase），
  增量零豁免。违反时如何被发现：验收 gate 红。

### C-2 引擎域 actor 惯例
- 引擎可变状态（Pikafish 进程句柄、UCI 会话、评估配置）只存在于 actor 内；
  ViewModel 不得直接持有引擎可变引用，跨域调用一律 async 接口。
- 单实例资源（引擎进程/构建目录锁）归专属 actor 所有，禁止旁路直取单例尾巴
  （EvalConfigManager 默认参数直读是 Ruby P1-③，此条即其防复发条款）。
- 机制：Ruby 增量审清单固定项（审查报告必须含"并发域检查"段）；lint 脚本对
  `.shared` 直读做存量计数，计数只许降不许升（升 = 审查驳回）。违反时如何被
  发现：审查报告缺段 = 提审无效；计数回升 = lint 报告红。

### C-3 Task 取消检查点
- 长循环（自对弈/批量评估/搜索）每次迭代或固定时间片必须检查取消
  （`Task.checkCancellation()` 或 `Task.isCancelled`）。
- 一切 `withCheckedContinuation` 包装必须配 `withTaskCancellationHandler`
  ——continuation 永不 resume 即永久阻塞（TD-002 实证：进程 0% CPU 僵死）。
- 机制：新增超时/取消 wrapper 必须带负例测试（取消后限时返回）；哨兵测试
  RunnerHygieneTests 模式可扩展收编。违反时如何被发现：负例测试缺位 = Ruby
  审查驳回项；现场僵死 = RUN-LEDGER 记录 + tech-debt 立案。
```

---

## 7. worktree 生命周期规则

### 7.1 现状

`git worktree list` 实测：8 个登记项中 1 个已 prunable（/private/tmp/v64-c2，目录被外部删除未走 git 通道）；3.0G 占用中约 2.4G（5 个）可退役。问题与任务台账同构：**建了不登记、用完不拆、拆不走正道**。

### 7.2 规则（建/用/退役三段）

**建**：
- 只经 `mkwt` 建（已有基建，内置资产 rsync 约定）；建后**立即登记** `~/DevTeam/WT-REGISTRY.md` 一行：`| 路径 | 分支/HEAD | Owner | 用途 | 建立日期 | 预期寿命 |`。预期寿命取值：任务级（收敛型，随批退役）/ 常驻（生长型，如 Eric 驻地）。
- 机制：watchdog 联检 `git worktree list` vs WT-REGISTRY——**git 有、登记无 = 未登记告警**（新 worktree 逃不过比对）。

**用**：既有规范不动（资产 rsync、禁 `add -A`、index.lock 礼让、合并归 Luke 单口）。

**退役**：
- **触发条件**（满足其一）：① 收敛型任务的批次验收销账（TASK-LEDGER accepted）；② 分支已由 Luke 合并入主干；③ 闲置 >14 天（无 commit 且无在制任务行引用；**v1.1 修：仅任务级行生效，常驻地豁免**——Eric 驻地这类生长型 worktree"闲置"是正常态，闲置≠废弃，退役判定必须带预期寿命字段）。
- **拆前检查单**（固化为 `~/DevTeam/scripts/wt-retire.sh <path>`，人工执行但检查由脚本判）：
  1. **提交保护核验**：`git status --porcelain` 为空（有未提交 → 拒拆）； detached HEAD 的必须有"产物已收割"确认（evidence 路径写入登记行）。
  2. **未合并检查**：分支型 `git log <main>..<branch>` 为空；非空 → 拒拆并列出孤儿 commit（防拆掉唯一副本）。
  3. **资产清理**：删除 rsync 进来的 gitignored 重资产（DerivedData/data/Pikafish lib/nnue）——5 个可退役 worktree 2.4G 的回收主要在这一步。
  4. **正道拆除**：`git worktree remove`（**禁止 rm -rf**——prunable 悬挂的唯一来源）；随后 WT-REGISTRY 行改 `retired@日期`。
- **防悬挂**：每日巡检（§2.3 第 6 项）跑 `git worktree prune` 幂等清理 + prunable 检测入 digest；retire 脚本把"检查单全绿才允许 remove"做进退出码。

### 7.3 机制保证

未登记（watchdog 比对告警）、该退不退（闲置检测进 digest + 收敛型任务销账时 Luke 验收清单提示退役项）、拆错（retire 脚本退出码拦截）。

---

## 8. 测试体系改进落地序（Tina 五条建议排期）

| 序 | 项 | 优先级 | 迭代归属 | 理由 |
|----|-----|--------|----------|------|
| T1 | skip-registry 加 target 列（CalibrationV3"仅全量批跳"但 runner 无条件 skip，定向批误跳） | **P0** | 本周 Batch A（与 #7 Cody 批并行） | 活 bug：定向批被误跳 = 测试证据失真，与 v6.4 A 线 Phase 2A 的 CalibV3 定向验证直接冲突 |
| T2 | awk 子串匹配改严格（整字段匹配） | **P0** | 与 T1 同 commit | 同域 5 行级修复；skip 消费是所有批次的咽喉，脆匹配 = 随机假绿 |
| T3 | EloBaseline 隔离机制化（非 .runner 裸跑仅半机制隔离） | P1 | v6.4 前半（Phase 3A Elo 校准轨启动前） | Phase 3A 就是对局跑批采集轨，Elo 隔离不机制化则新轨裸奔同款风险 |
| T4 | Phase 编号 suite 重名并表（Phase1* ≥6 文件） | P2 | v6.4 中段 Tina 专项批 | 机械性整理，但降低"文件名≠suite 名静默零跑"复发面（09-29 实证过一次） |
| T5 | 覆盖盲区补齐（TrendAnalyzer / OpeningCoachSession / PatternRecognizer / CMAESOptimizer） | P1 分批 | **随域落位**：TrendAnalyzer+PatternRecognizer → A 线 Phase 2A/4A（分析展示域顺手）；OpeningCoachSession → C 线 C4 前置检查（Eric 域）；CMAESOptimizer → TD-001 重构批（对账脚本核验该条目时触发） | 盲区测试与功能开发同域同批，避免"为补而补"的孤儿测试；CMAES 挂 TD-001 是因为它无测试保护的重构风险最大 |

排期原则：T1/T2 是 runner 正确性（先于一切新批次）；T3 卡在 Phase 3A 前是硬依赖；T4/T5 不占独立里程碑，搭车清偿（复用 v6.4 §0.5 清偿域落位规则）。

---

## 9. 实施排期与人力分工

### 9.1 三批节奏（与 v6.4 主线并行，零主线阻塞）

**Batch A：P0 机制周（本周，~2 人日×2 人）**
- D1：TASK-LEDGER 建档 + 派发模板改造（Alex 定格式，Cody 落地；**含 flock 写入协议**）；accept-gate.sh（Cody，正则自测用例随脚本）；T1+T2 skip 修复（Tina，同 commit）。
- D2：~~task-watchdog.sh + launchd agent 装配（Cody）~~（**v1.2 划掉**——launchd 方案废弃；每日巡检改由 Luke 建 WorkBuddy 每日 09:00 定时自动化，配置一次性完成不入 Batch A 工期）；首批 backlog 任务全部补登记入台账（Vera 扫三方体检待办件回填；**当前 m1 树 2 个未跟踪文件的清理也登记为台账首批任务行——它就是 shadow 期 DoD 的实测负例样本，v1.1**）；RUN-LEDGER 存量 2 条悬挂"运行中"行人工销案（Tina）。
- worktree 退役批拆两步（**v1.1，Vera P1-⑥**）：
  - **D2 执行（零决策件×3）**：pa-fix / r3g-e9c / v633-rebuild——Eric 按 wt-retire 手工检查单拆（脚本随后补，人工核验同单）。
  - **滚动进 Batch B（有裁定件×3，Luke 已裁、执行待洪涛点头）**：v62（退役 worktree、**保 v6.2 分支**——fd7d9ef 历史支线不合并，m1 已演进两版本）；p5-wt-m1legacy（**WIP 先 `git stash` 保全**再退役）；v64-sample（正常退役、保分支）。
- 出口判据（v1.2 更新）：每日自动化连续两天 09:00 出报告且首行时间戳自证在位；accept-gate 在当前 m1 树上跑出预期红（2 个未跟踪文件，**含通知钩子弹出实测**）；T1 定向批复跑 CalibrationV3 不再误跳。

**Batch B：P1 基建批（v6.4 周期内，A 线 Phase 2A 期间穿插）**
- 基建入库三步 commit 链（§5.3）+ 8.4MB 清退（Cody 主，Vera 验收）；[3/5] 禁止清单扩充（`*.png` / `.build-test-cache/`）+ warn→fail 为**收编②前置、同 commit**（v1.1）。
- worktree 退役滚动批：v62 / p5-wt-m1legacy / v64-sample，按 Luke 裁定执行（洪涛点头后放行，裁定细节见 §9.1 Batch A）。
- techdebt-reconcile + check-readme-version（Cody 脚本，Ruby 首跑对账；tech-debt.md 最小表结构四字段先行落地，v1.1）。
- lint-concurrency.sh（Ruby 定规则，Cody 实现；**存量 advisory-only 上线**，增量即 blocking——防止把 A 线 Phase 2A 堵死在存量债上）。
- DEVTEAM.md 并发章节合入（Alex 草案 → Ruby 复核 → Vera 审 → Luke 定稿；**同 commit 整体替换两段旧验收清单，见 §6 修订指令**）。
- README 三重漂移清偿 + 命令块单源化 + 打包路径口径（根目录构建、归档 releases/）（Eric，#8 批已含）。**v1.1 归属标注（Vera P1-⑤）**：docs 治理两项——DEVTEAM 目录结构段对齐现实、"docs/*.md 由 gitignore 排除"口径修正——已增补给 Eric #8 批随 README 同批清偿，不在本规范另开任务。

**Batch C：P1 收尾批（v6.4 后半）**
- T3 Elo 隔离机制化（Tina，Phase 3A 启动前硬门）。
- wt-retire.sh 脚本化 + WT-REGISTRY 联检并入每日巡检 automation prompt（Cody 出检查逻辑，Luke 并入 prompt）。
- T4 suite 并表（Tina 专项批）；docs/ 索引复活（Vera，364 文件建立索引页并挂"索引保鲜 = 发版 checklist 项"）。
- **active→archive 归档触发条件落地（v1.1，Vera P1-⑤③）并列入 Batch C 验收判据**：触发条件 = 每次版本 tag 发布时，该版本相关的 active 文档全部归档至 archive/，由 techdebt-reconcile 同入口核验（active/ 内文档的版本归属字段 ≤ 最新 tag 的前一版本即告警）——索引页建好但没有归档纪律 = 索引半年后再死一次。

### 9.2 人力分工（7 人）

| 人 | 主责 | 兼责 |
|----|------|------|
| Alex | 本规范设计/修订、审查清单应对 | 并发条文措辞、机制选型仲裁 |
| Cody | 机制脚本实现（accept-gate/reconcile/lint；巡检逻辑由 Luke 落 automation prompt，非脚本件） | #7 P1 修复批（已派） |
| Eric | C 线主线（C3 ~4 人日不动摇） | worktree 退役批、README 清偿（#8 已派） |
| Ruby | 并发条款审查域执行（C-2 固定检查段） | tech-debt 首轮对账复核 |
| Tina | T1-T5 测试体系改进 | RUN-LEDGER 终态回填首批示范 |
| Vera | 本规范 SOP 审查、收编验收、docs 索引复活 | 月度 gate 日志 vs 验收报告对账审计 |
| Luke | 派发登记示范首批、验收走新 gate、升级件处理、合并仲裁 | escalation-hook 配置拍板、DevTeam 建仓拍板 |

### 9.3 与 v6.4 主线的并行安全论证

- C3（Eric）不碰任何机制脚本与 docs/ 治理文件 → 零交集。
- A 线 Phase 2A（Cody）与 Batch B 同人——已按"穿插"排（机制脚本总量 ~3 人日，Phase 2A 关键路径上让位，机制项全在非关键路径等待位）。
- lint-concurrency **存量 advisory** 是关键并行决策：C-1 违例存量集中在 ViewModel 域，若上线即 blocking，A 线 Phase 2A（分析展示域）会被自己的存量债卡死；advisory→blocking 切换点 = 存量豁免清单清空时（清单本身进 tech-debt 台账，由 §4.1 对账脚本盯）。

---

## 10. 风险与对策

| # | 风险 | 等级 | 对策 |
|---|------|------|------|
| R1 | 台账成为新的"自觉负担"，登记动作被省略 → 机制空转 | 高 | 三重减压：追加式一行写入（成本压到最低）；派发模板必填项（漏登 = 模板不完整）；Luke 验收只认台账行——未登记任务验收 gate 第 3 查直接红。**漏登检测（v1.1 降级，Vera P1-⑦）：原"watchdog 比对工单流量与台账行数"砍掉——无机器可读信号源，比对只能比出虚假安全感；降级为 Vera 月度审计抽查台账覆盖率**（近期工单 vs 台账行抽样比对，漏登进月报违规件清单） |
| R2 | 巡检载体失效（v1.2 更新：WorkBuddy 自动化被误删/停用，或宿主平台故障） | 中 | 时间戳自证（§2.3 第 7 项）——当日 09:00 无报告即用户直接可见；digest 超 26h 无新增可查；自动化 prompt 全文抄录进本文档附录位（Luke 建 prompt 时回贴），可随时一键重建；缺时间戳的报告视为无效（v1.2 降档说明：原 launchd 场景的"机器重启失效"风险随方案废弃消失，新载体风险转为平台可用性，等级中→中） |
| R3 | lint 误报阻塞主线 | 中 | 存量 advisory-only + 豁免清单显式登记（§9.3），切换点绑定清单清空而非日历 |
| R4 | 收编 commit 误收大文件/产物 | 中 | 三步迁移 + dry-run 全量盘点前置（§5.3）+ verify_delivery [3/5] 禁止文件检查。**v1.1 补（Vera P1-①）：[3/5] 清单同 commit 扩充 `*.png`（根目录级）与 `.build-test-cache/`**——已入库 8.4MB 违规件恰在原检查面外，不扩充则本对策为空；扩充后清退由它反向验证 |
| R5 | 单机单点：磁盘故障 = 台账/脚本/证据全灭 | 高（接受） | 本规范不做异地（超范围）；缓解 = DevTeam 建 git 仓（脚本）+ 台账/ledger 每日 digest 即天然快照；建议 Luke 拍板 DevTeam 仓加远端（超出 v1 范围，列为 v2 候选） |
| R6 | 巡检/门禁机制自身有 bug 造成误升级/误拦截（v1.2 更新载体：automation prompt 判定错 / accept-gate 脚本 bug） | 中 | 上线首周 shadow 模式（只报告不翻状态/不拦验收）；accept-gate 自测用例随脚本同 commit（对齐 skip-registry"修复落地同 commit"惯例）；automation prompt 判定异常时 Luke 可当场改 prompt 修正——换轨后修错成本从"改脚本+装机"降为"改文案"，是 v1.2 方案的附加收益 |
| R7 | 升级风暴（多个任务同时逾期 → Luke 被刷屏） | 低 | digest 聚合（单文件全集而非逐条触达）；OVERDUE 分级只有 SERIOUS 档进升级触达三级通道 |

---

## 11. 验收判据（本规范自身的 Definition of Done）

1. TASK-LEDGER 存在且三方体检全部待办件已回填登记（Vera 验）。
2. 每日巡检（WorkBuddy 自动化）连续 48h 出报告且时间戳自证在位，且至少一次真实催办-升级-处理链走通（Luke 验）。**shadow 语义（v1.2 同 3）：自动化首周只报告不翻状态，期满转执行档后复核。**
3. accept-gate 在 m1 树实测红（2 个未跟踪文件）、清理后实测绿（Luke 验）。**shadow 语义（v1.1）：首周 shadow 模式（只出报告不拦验收），本判据在 shadow 期满、转 blocking 后复核一次**。
4. T1+T2 落地：CalibrationV3Tests 定向批复跑不被误跳（Tina 验）。
5. worktree 退役批两步完成：D2 零决策件×3 + Batch B 滚动件×3（按 Luke 裁定、洪涛点头后），磁盘回收 ≥2G（Eric 验）。
6. 并发章节进 DEVTEAM.md，lint-concurrency 存量报告产出（Ruby 验）。
7. 8.4MB 违规产物出库，scripts/ 收编 commit 完成（Vera 验）。

> 以上 1-7 项本身登记为 TASK-LEDGER 首批任务行（含 m1 树 2 个未跟踪文件清理行——它同时是 DoD-3 的实测样本）——**规范从诞生第一刻起用自己的机制管理自己**。
