# 测试类工单模板（v6.3 H-1 固化，Tina 2026-08-29）

> 所有涉及"跑测试批"的工单派发时必须携带本模板的 §规约 节。
> 适用：功能验证批、正式批、r 系长跑基线、回归批。

## 工单头

- 工单号 / 派单人 / 执行人：
- 测试范围（suite 清单，精确类名，从源码 @Suite 行复制）：
- 基线 commit / 预期 Test run 数（锚）：
- 预计时长 / 起跑方式：

## §规约（必带，逐条勾选）

- [ ] **互斥起跑**：一切测试批经 `scripts/run-tests-mutex.sh` 起跑（flock 全局锁 `~/DevTeam/.locks/xcode-tests.lock`，抢不到即排队）。正式测试批与 r 系长跑基线**禁止同机并行**（08-28 前科：selcons 并行 → PikafishCAPITests 2 红 + r3f 卡死）。
- [ ] **语言锁**：由 runner 统一注入 `AppleLanguages=(zh-Hans)`，禁各批自设/依赖系统语言（跨 suite L10n 竞态假红指纹："前1英文后4中文"，08-28 二次实证）。
- [ ] **skip 单源**：skip 名单以 `docs/test/skip-registry.md` 为准，不复制粘贴到工单正文；新增/移除 skip 须同 commit 更新该表（含 reason）。
- [ ] **长跑脱离**：预计 >3 分钟的批必须 `nohup` 脱离 + 固定日志路径（`~/DevTeam/workdirs/logs/` 下，禁 /tmp 存产物），禁止盯进程轮询。
- [ ] **静默零跑门规**：结果宣告前对账 "Executed N tests / Test run with N tests"，N 与预期不符 = 批次作废。
- [ ] **产物持久**：长跑 binary/日志/登记表一律 `~/DevTeam/` 持久目录；发射必登记 LAUNCH-REGISTRY。

## 验收输出

- 轮次结果摘要（每轮 rc + Test run 对账行）
- 失败项定性与归属（存量/新回归/环境伪象——环境伪象须给隔离复跑证据）
- 变更文件清单 + commit hash
