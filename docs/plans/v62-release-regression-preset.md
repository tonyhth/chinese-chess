# v6.2 发布回归批 · 预制起跑单（Tina 08-29 备案，只备不发）

> Luke 派单口径：终裁一到零等待起跑。起跑器：`~/DevTeam/workdirs/logs/v62-release/v62-release-regression.sh`（nohup 模板见脚本头注）。

## 四件构成与覆盖映射

| # | 件 | suite 清单（精确名） | 覆盖 |
|---|---|---|---|
| 1 | SIGILL 回归指纹 | SigillIronGateRegressionTests（4 例：id 轮转隔离带/同盘撞盘现场/铁门栓防御分支/**KingSafety 崩点 e2e 指纹 = "终局退化+重复 id bestMove 全搜索不崩"**）+ AIEngineTests + MoveValidatorTests（原崩邻段） | 7d0104d+021128b 已入库部分直接引用，零新造 |
| 2 | 四指纹套件 | EngineReliabilityFingerprintTests（①MultiPV depth=0=PA-1 指纹A ②evaluate 超时 nil=PA-1 指纹B ③大师中局跳库=r3 红2 ④连将杀=r3 红5）+ EngineTimeContractTests（契约 3 例） | PA-1×2 + ETC3 + r3 两真红全落 |
| 3 | 全量批双平台 | runner --full（串行+owner 门禁+总对账门禁）→ iOS 双工程门禁 + I4I6 六轮链（已入 C1 收编，随 iOS 段复跑可选） | L2/C4 全量面 |
| 4 | skip 清单核对 | 单源 docs/test/skip-registry.md，脚本段 4 自动导出生效行对账（预期 9 行） | 见下核对结论 |

## skip 清单核对（08-29 最新口径，人工逐行）

| Suite | 状态 | 依据核对 |
|---|---|---|
| EloBaselineTests | skip | DEVTEAM 铁律 ✅ |
| V370 五类（P1/P2S/P3/P4/V371） | skip | GameRecordStore 死锁族（08-28 实测挂点）✅ |
| UILayoutOptTests | skip | 第二实例 Pikafish init 死锁（r3f 定位）✅ |
| PikafishCAPITests | skip | r3f 挂点嫌疑 + 并行干扰（08-29 Luke 裁）✅ |
| CalibrationV3Tests | skip（仅全量批） | r3 #2 首崩点 180s 挂起→引擎楔死连坐，隔离 23/23 绿 ✅ |

**新跳过遗漏核查**：08-29 全量批新增批内伪象红三处（DifficultyV42 amateurMid 480s 负载超时 / Phase2a pristine 断言 / P0AIFix 引擎连坐）——均**隔离复跑全绿、已报裁（观察项 + P3 工单）**，按"基线成员必须确定性"口径未入 skip（隔离态确定性成立），维持不动；若 Luke 裁定全量批豁免面扩大再增补。

## 判据（起跑后）
- 1/2 段全 PASS（Test run 对账逐批）
- 3a 段总对账 ≥2100（270+ suite 口径）且 SIGILL/ trap/ crash 零命中；3b SUCCEEDED
- 4 段 9 行对账
- 全程 owner=tina 留痕，日志固定 ~/DevTeam/workdirs/logs/v62-release/

## 附：真机抽检段（洪涛工单④，随回归批/复测执行）

> 前置：iOS 真机连接（devicectl coredevice 可见）。装机：deploy-ios.sh 部署重打包产物。

### A. 难度 6→10 各走 2 着（专业级路由真机抽检）
- 操作：真机逐级（lvl6 棋友 → lvl10 棋圣）开新局，每级人机各走 ≥2 着，确认引擎应着非挂死/非秒败
- 判据：每级 2 着内引擎应着、无"Pikafish引擎未准备就绪" toast、无 ANR 感知卡死
- 记录：每级截图 1 张（难度选择 + 棋面），入 v62-release/ 目录

### B. ③运行时遥测日志行确认（Cody 侧③实现后生效；指引先占位）
- 目标格式（占位，以 Cody 实现为准）：
  `[Engine] move#N lvl=X engine=embedded budget=Yms elapsed=Zms`
- 取证：真机抽检期间 Console.app 抓 ChineseChess 进程日志，或 idevicesyslog/`log stream` 等价通道
- 判据：lvl6-10 每级 ≥2 条遥测行；engine=embedded 恒成立（E5 后专业级恒路由）；elapsed ≤ budget+2s（watchdog 契约）
- 未实现时处置：标注"③遥测未上线，格式占位待 Cody 工单"跳过 B 段不阻塞 A 段
