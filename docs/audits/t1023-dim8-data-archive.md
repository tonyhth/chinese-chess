# T-1023-OC-01·P2·增补⑧ — 数据与存档兼容报告（dim8）

> 角色：Eric | 日期：2026-10-20 | 树态锚：m1 @ 1cfd109（v6.4.2-1-g1cfd109），检查全程零改动零编译零测试
> 依据：docs/plans/T-1023-OC-01-inspection-plan.md v1.1 §四增补⑧/§五.5（dim8=数据存档兼容，裁示②批准）；主问：schemaVersion 契约（v6.4.1 引入，非 Optional fail-fast 裁定）落地一致性、存档/统计文件格式漂移风险
> 方法：静态走查（Services 层持久化面定点进入），未做全库通读

## 一、存档面盘点（8 面）

| # | 存档面 | 载体 | 路径/键 | 版本机制 |
|---|---|---|---|---|
| 1 | 对局记录主档 GameRecordStore | JSON 文件 | Documents/GameRecords/index.json + {uuid}.json（GameRecordStore.swift:92/:128） | s2Migrated 标记+Optional 等效兼容（无显式 schemaVersion） |
| 2 | 分析信封 sidecar | JSON | {uuid}.analysis.json（AnalysisPersistence.swift:70/:86） | **schemaVersion=1 非 Optional**（:31/:49） |
| 3 | 统计报告 GameRecordStatsReport | JSON 导出 | exportJSON（GameRecordStatsAggregator.swift:596） | **schemaVersion=2**（:215，v6.4.1 patch 批 v1→v2） |
| 4 | 对局统计 StatsManager | UserDefaults | "chinesechess.stats"（StatsManager.swift:28） | 迁移版本标记 v6（:29） |
| 5 | 偏好/进度键族 | UserDefaults | chinesechess.* | 双迁移器（DataMigration+PreferencesMigration） |
| 6 | PGN 导入导出 | 文本 | PGNImporter/Exporter | 容错策略（PGNImporter.swift:56） |
| 7 | 大师棋谱库 | 只读资产 | MasterGameStore/MasterGameLoader | 无（只读消费） |
| 8 | 玩家档案 PlayerProfile | UserDefaults Codable | rank/成就/特权 | 解码接受旧中文键（PlayerProfile.swift:20-23） |

## 二、schemaVersion 契约落地一致性

### 2.1 AnalysisEnvelope（分析 sidecar）——契约已落，演进窗口待补

- **字段非 Optional ✓**：let schemaVersion: Int（AnalysisPersistence.swift:31）+ AnalysisProfile.schemaVersion = 1 单一事实源（:49，与 depth/engineVersion 共池防双口径漂移）
- **写入 ✓**：AnalysisViewModel.swift:278 写入 schemaVersion: AnalysisProfile.schemaVersion
- **fail-fast 语义 ✓**：旧档缺字段 → JSONDecoder decode 失败 → loadAnalysisEnvelope 返回 nil → 整谱重算（安全回退，:68-77）——v6.4.1 "非 Optional fail-fast" 裁定语义达成
- **缺口（P3）**：①无显式版本分支——单版本现状无实害，v2 结构演进前必须补分档逻辑（:68-77 现为直 decode）②损坏 sidecar 仅 DEBUG 日志（:76-77 #if DEBUG），**Release 构建静默重算无痕**——排查不可见（Ruby 08-30 P2-2 同源注记已在码，未覆盖 Release 面）

### 2.2 GameRecordStatsReport（统计报告）——v1→v2 演进已发生，一致

- schemaVersion = 2（GameRecordStatsAggregator.swift:215），v2 增量=durationExcludedUnfinishedCount（:214 注释 "v6.4.1 patch 批；v1=首版无该字段"）——版本字段+演进注记齐
- exportJSON（:596）单向导出，应用内无读回路径——版本字段为导出契约标注，无兼容门需求，**一致性 ✓**

### 2.3 GameRecord 主档——无 schemaVersion，等效机制判定

- 兼容机制：s2Migrated: Bool（GameRecord.swift:48）+ Optional difficulty（:35，v3.7.1 C5 导入记录无难度）+ 自定义 init(from:) decodeIfPresent（:59-95）：S2 前旧档（标记缺席）→ difficulty/双 PlayerInfo 经 s2MigratedRaw 映射迁移；S2 后新档零腐蚀直读；解码后内存置位防重入（:95）
- **判定：机制等效 ✓**（版本号缺失但迁移语义完整，挂点收窄至数据加载边界、单次应用防腐蚀——Enums.swift:190-194 设计注释与 Ruby P1-2/Luke 裁定链在案）
- **残余风险（P3）**：无版本号 = 未来**类型级**变更（非新增字段）无分档窗口，兼容性完全依赖"新增字段必须 Optional+decodeIfPresent"纪律

## 三、跨版本兼容机制面（存量关口逐核）

| 关口 | 机制 | 证据 | 判定 |
|---|---|---|---|
| v2.x → v3.0 数据迁移 | 幂等+备份（chinesechess.v3_migrated / v2x_backup，键值清单化） | DataMigration.swift:16-19/:47-58 | ✓ |
| v3.7.1 Bundle ID 偏离偏好丢失 | 跨 Bundle 全前缀 chinesechess.* 迁移（防固定清单遗漏）+幂等 | PreferencesMigration.swift:5-8/:17-24 | ✓ |
| S2 难度重映射 | s2MigrationMap 挂用户数据加载边界单次应用；类型级钩子三连风险已裁避 | Enums.swift:190-200 + GameRecord.swift:76-95 | ✓ |
| AIDifficulty 旧值解码 | rawValue lvl1-10 + legacy "medium"/"hard"/"master" 再合法化 | Enums.swift:63-81 | ✓ |
| stats 存档演进 | GameStats Codable + migrationVersionKey v6 | StatsManager.swift:16-29 | ✓ |
| PGN 导入容错 | 标签缺失→默认值/FEN 缺失→标准开局/单局非法→回滚该局/多局→部分成功 | PGNImporter.swift:56 | ✓ |
| 旧档中文段位键 | init 接受 "秀才"/"举人"/"进士"/"翰林" 解码 | PlayerProfile.swift:20-23 | ✓ |

## 四、发现项（P0×0 / P1×0 / P2×0 / P3×4）

1. **P3** sidecar 损坏 Release 静默：AnalysisPersistence.swift:68-77（try? 双处 + #if DEBUG 日志）｜P4 建议：Release 级轻量日志或损坏计数上报
2. **P3** loadAnalysisEnvelope 无版本分支：单版本无实害，v2 演进前置条件（AnalysisPersistence.swift:68-77）｜登记为演进门
3. **P3** GameRecord 主档无显式 schemaVersion：等效机制在位，类型级演进无窗口（GameRecord.swift:48-95）｜P4 候选：补 schemaVersion 或在 DEVTEAM.md 立编码纪律
4. **P3** 双版本系并存无统一注册表：AnalysisProfile.schemaVersion=1（AnalysisPersistence.swift:49）与 GameRecordStatsAggregator.schemaVersion=2（:215）各自独立定义，无集中登记｜P4 候选：归拢注释或单一注册点

跨维引用：engine 回退文案档名漂移（"业余高级"）已在 t1023-dim6-i18n.md §四 P2-1 登记——属呈现面缺陷，存档面不受影响（rawValue "lvl5" 稳定）。

## 五、结论

1. **无 P0/P1 静态风险**：全部已知跨版本关口（v2.x→v3.0、Bundle ID 偏离、S2 重映射、stats v6、difficulty 旧值、PGN 容错、中文段位键）均有幂等迁移或兼容解码在位，且多为审查链裁定后的防御性实现（Ruby/Luke 裁定注释在码）
2. **schemaVersion 契约（v6.4.1 裁定）落地一致性：通过**——两处落点字段非 Optional、写入点齐、fail-fast 语义达成；GameRecord 主档等效机制成立；4 条 P3 均为"未来演进窗口"性质，无当前数据错误证据
3. **P3 整改映射**（供 t1023-summary）：4 条全部为 P4 低成本加固项（日志/分支/注册表/纪律注记），建议打包为一个"存档面加固"整改条目

---
> 报告完。零 commit 零台账写入。Eric 2026-10-20