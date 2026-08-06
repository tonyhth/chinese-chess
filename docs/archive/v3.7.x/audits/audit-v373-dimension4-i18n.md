# v3.7.3 维度 4 — 国际化与本地化审计报告

**审计人**：Vera  
**日期**：2026-07-14  
**代码基线**：v3.7.3（commit 958132f，本地最新）

---

## 总览

| 指标 | 数值 |
|------|------|
| xcstrings 总 key 数 | 541 |
| 代码引用的 key 数 | 367（含动态构造） |
| 未被引用的 key | 174 |
| 缺失 key（代码引用但 xcstrings 未定义） | 1 |
| 缺少 en/zh-Hans 翻译的 key | 0 / 0 |
| 中文字符串字面量（排除注释后） | 180 处 |
| 其中用户可见硬编码 | ~40 处 |

### P0/P1/P2 分布

| 级别 | 数量 |
|------|------|
| P0 | 3 |
| P1 | 6 |
| P2 | 5 |
| **合计** | **14** |

---

## P0 — 必须修复

### 4-P0-1. `feature.gameRecordImport` key 缺失

- **文件**：`src/ChineseChess/Models/UnlockedFeature.swift:77`
- **问题**：代码调用 `L10n.shared.t("feature.gameRecordImport")`，但 xcstrings 中只定义了 `feature.gameRecordExport`（9 个 feature.* key），`gameRecordImport` 完全不存在。英文用户在段位升级弹窗中会看到原始 key 字符串 `"feature.gameRecordImport"` 而非翻译文本。
- **建议**：在 xcstrings 中添加该 key，zh-Hans `"棋谱导入"`，en `"Game Record Import"`。

### 4-P0-2. macOS CommandMenu 标题和按钮硬编码中文

- **文件**：`src/ChineseChess/App/ChineseChessApp.swift:542, 547`
- **问题**：`CommandMenu("引擎")` 和 `Button("配置引擎")` 直接硬编码中文。macOS 英文用户会在菜单栏看到中文菜单项。这两个是 SwiftUI `CommandMenu`/`Button` 的 label 参数，会被系统本地化机制渲染，但它们不是 `LocalizedStringKey` 走 xcstrings 的路径——取决于 SwiftUI 对 `String` vs `LocalizedStringKey` 的重载选择。`CommandMenu(_ titleKey:)` 实际上接受 `LocalizedStringKey`，但这里传入的字符串字面量不会自动查 xcstrings，因为 L10n 绕过了系统本地化。
- **建议**：改为 `CommandMenu(L10n.shared.t("engine.menuTitle"))` 并在 xcstrings 添加对应 key。同理 `"配置引擎"` 应改为 `L10n.shared.t("engine.configure")`。

### 4-P0-3. 棋盘"楚河汉界"硬编码

- **文件**：`src/ChineseChess/Views/ChessBoardView.swift:512,514,517,519`；`src/ChineseChess/Views/ReplayBoardView.swift:168,170`
- **问题**：共 6 处 `Text("楚  河")` / `Text("汉  界")` 硬编码。xcstrings 中已定义 `board.chuRiver` 和 `board.hanBorder` 但从未被引用——key 定义了却没用上。英文用户在棋盘上会看到中文字符。
- **建议**：将 `Text("楚  河")` 改为 `Text(L10n.shared.t("board.chuRiver"))`，`Text("汉  界")` 改为 `Text(L10n.shared.t("board.hanBorder"))`。需评估英文版棋盘是否显示 "Chu River" / "Han Border" 还是不显示（文化决策）。

---

## P1 — 高优先级

### 4-P1-1. BoardTheme 主题名和解锁条件全硬编码

- **文件**：`src/ChineseChess/Services/BoardTheme.swift:17-19, 36-39`
- **问题**：
  - `localizedName`：`classicWood` 和 `inkStone` 走了 `L10n.shared.t()`，但 `jadeGreen`→`"翡翠绿"`、`imperialGold`→`"帝王金"`、`crimson`→`"朱砂红"` 直接硬编码。
  - `unlockDescription`：全部 4 条直接硬编码中文（`"默认解锁"` / `"升至秀才段位解锁"` 等）。
  - 英文用户在主题选择界面和解锁提示中会看到中文。
- **建议**：xcstrings 已有 `theme.classicWood`、`theme.inkStone`、`theme.title`。需添加 `theme.jadeGreen`、`theme.imperialGold`、`theme.crimson`、`theme.unlockDefault`、`theme.unlockRank`（带参数）等 key。

### 4-P1-2. PGN 导出/导入错误信息和元数据硬编码

- **文件**：
  - `src/ChineseChess/Services/PGNExporter.swift:18-19, 32, 81, 136-139`
  - `src/ChineseChess/Services/PGNImporter.swift:13, 15, 17, 83, 85, 184-185, 212`
- **问题**：
  - PGNExporter 错误描述（`"走法列表为空"` / `"无效的棋盘位置"`）、PGN `[Site "中国象棋"]`、`[Event "导出失败"]`、来源翻译（`"人机对弈"` 等 4 条）全部硬编码。
  - PGNImporter 错误信息（`"第 X 步非法走法"` / `"无有效棋局"` / `"无效 FEN"` 等）、默认玩家名（`"红方"` / `"黑方"`）、默认标题（`"导入棋谱"`）全部硬编码。
  - **注意**：PGN 的 `[Site "中国象棋"]` 和来源标签是否应该国际化存在争议——PGN 标准建议英文，但中文 PGN 社区普遍使用中文。建议至少错误提示和默认标题国际化，PGN 元数据保持中文（兼容性优先）。
- **建议**：错误描述和用户可见的默认值走 i18n key；PGN 元数据（`[Site ...]`）可保留固定值或根据当前语言选择。

### 4-P1-3. SettingsView 语言选择器 "中文" 硬编码

- **文件**：`src/ChineseChess/Views/SettingsView.swift:65`
- **问题**：`Text("中文")` 硬编码。虽然语言名称通常用本语种显示（英文界面里 "中文" 也是正确的），但这里应该用一个不经过翻译的固定字符串（因为语言名称永远应该用自己语言显示），或者至少明确标注这是 intentional 的硬编码。当前代码中 `"English"` 也是硬编码的，两者应该保持一致的处理方式。
- **建议**：如果是 intentional（语言名用本语种显示），添加注释说明；否则提取为常量。

### 4-P1-4. AIEngine displayName 硬编码

- **文件**：`src/ChineseChess/AI/AIEngine.swift:628`
- **问题**：`var displayName: String { "内置引擎" }` 硬编码中文。该属性会在引擎选择 UI 中展示，英文用户看到中文。
- **建议**：改为 `L10n.shared.t("engine.builtIn")`（xcstrings 中已有此 key 且双语完整）。

### 4-P1-5. SelfPlayRunner / CMAESOptimizer / OpeningBookExpander CLI 输出全中文

- **文件**：
  - `src/ChineseChess/AI/SelfPlayRunner.swift:34-39, 262-272, 314-375`（~30 处）
  - `src/ChineseChess/AI/CMAESOptimizer.swift:267-523`（~15 处）
  - `src/ChineseChess/AI/OpeningBookExpander.swift:36-281`（~25 处）
- **问题**：这三个 CLI 工具的 `print()` 输出和 `NSError` 描述全部硬编码中文，包括进度报告、错误信息、使用帮助、报告内容。
- **降级说明**：这些是开发者工具（CLI / 调试用），不直接面向终端用户。但如果未来有非中文开发者协作，或日志被收集分析，会造成问题。
- **建议**：P1 优先处理 `OpeningBookExpander` 的 `NSError`（可能冒泡到 UI），其余 P2 处理。

### 4-P1-6. 174 个 xcstrings key 未被引用

- **文件**：`src/ChineseChess/Resources/Localizable.xcstrings`
- **问题**：541 个 key 中有 174 个未被任何 swift 文件引用（静态分析）。主要分布：
  - `achievement.*.desc/name`：~70 个（成就系统定义了但尚未接入 UI）
  - `daily.streak.*.desc/reward`：~16 个
  - `daily.type.*.desc/title`：~20 个（DailyChallenge 模式用了动态构造 `"daily.type.\(rawValue).title"`，所以实际有引用但静态分析看不到）
  - `chapter.*.title/subtitle`：~14 个
  - `move.quality.*`：6 个
  - `notation.*`：6 个
  - 其他散布
- **建议**：
  - 确认 `daily.type.\(rawValue).title/desc` 和 `daily.streak.day\(rawValue).desc/reward` 是动态构造，实际有引用——没问题。
  - 真正未接入的（achievement.*、chapter.* title/subtitle）应评估是预留还是废弃。预留的加注释说明，废弃的清理。

---

## P2 — 中低优先级

### 4-P2-1. DateFormatter 未设置 locale

- **文件**：
  - `src/ChineseChess/Models/DailyChallenge.swift:124, 239, 376`
  - `src/ChineseChess/Services/PGNExporter.swift:146`
  - `src/ChineseChess/Services/PGNImporter.swift:63`
- **问题**：所有 `DateFormatter` 实例都设置了 `dateFormat` 和部分设置了 `timeZone`，但**没有一个设置 `.locale`**。对于 `"yyyy-MM-dd"` 和 `"yyyy.MM.dd"` 这种纯数字格式，locale 影响极小（理论上可能影响日历系统）。但最佳实践是设置 `formatter.locale = Locale(identifier: "en_US_POSIX")` 确保格式稳定。
- **建议**：对所有固定格式 DateFormatter 添加 `.locale = Locale(identifier: "en_US_POSIX")`。

### 4-P2-2. NumberFormatter 未使用

- **文件**：全局
- **问题**：代码中没有找到任何 `NumberFormatter` 使用。数字格式化（如胜率百分比 `String(format: "%.1f%%", ...)`）全部用 `String(format:)`。这不是 bug，但在某些 locale（如阿拉伯语）下可能有显示差异。
- **建议**：当前只支持 zh-Hans 和 en，影响可忽略。如果未来扩展更多语言需重新评估。

### 4-P2-3. 领域术语翻译一致性

- **文件**：xcstrings `en` 翻译
- **问题**：抽查了核心术语的英文翻译：
  - 将军/将死 → `"Check"` / `"Checkmate"` ✓ 一致
  - 车马炮 → `chariot/horse/cannon` ✓ 一致
  - 段位（学童/秀才/.../棋圣）→ `student/scholar/.../sage` ✓ 一致
  - 楚河汉界 → 已有 key 但未接入（见 4-P0-3）
  - 杀法名称（马后炮/双车错等）→ 在 `PatternRecognizer` 注释中是中文，运行时是否显示需确认。xcstrings 中 `achievement.kill_mate_horse_cannon.desc` 有翻译。
- **状态**：基本一致，无明显冲突。

### 4-P2-4. PlayerProfile/DailyChallenge/Achievement 中文 init 兼容性

- **文件**：
  - `src/ChineseChess/Models/PlayerProfile.swift:19-25`（`case "student", "学童"`）
  - `src/ChineseChess/Models/Achievement.swift:20-24`（`case "bronze", "铜"`）
  - `src/ChineseChess/Models/DailyChallenge.swift:22-31`（`case "endgamePuzzle", "每日残局"`）
- **问题**：这些 `init?(rawValue:)` 或 `init?(string:)` 同时接受英文和中文 rawValue，用于向后兼容旧数据。这是合理的设计（数据迁移兼容），但中文映射分散在多个 Model 中，没有统一的映射表。
- **建议**：P2 维持现状。如果后续新增更多枚举的可本地化值，建议建立统一的 `LegacyStringMapping` 工具。

### 4-P2-5. NotationGenerator 中文记谱法不国际化

- **文件**：`src/ChineseChess/Services/NotationGenerator.swift:11, 16, 59-75, 109, 111, 130, 135`
- **问题**：中文记谱法（"炮二平五"、"进"、"退"、"平"、"前"、"后"）完全硬编码。这是**正确的设计**——中文象棋记谱法本身就是中文，英文版应使用 ICCS 或另一种记谱法（已在 `settings.notationFormat` 中提供了 ICCS 选项）。不需要国际化这些字符。
- **建议**：确认 Settings 中有 notation format 切换，确保英文用户默认使用 ICCS 格式而非中文记谱法。

---

## 附加发现

### 趋势对比（vs v3.4.0 P0-4）
v3.4.0 审计时报告 200+ 处硬编码中文。当前：
- 注释中的中文不计（~330 处，属正常内部文档）
- 字符串字面量 180 处，其中：
  - CLI 工具输出 ~70 处（开发者工具）
  - 棋子显示字符 14 处（领域固有）
  - 中文记谱法 ~20 处（领域固有）
  - enum 兼容映射 ~25 处（数据迁移）
  - **用户可见真正应国际化但遗漏的 ~40 处** ← 大幅改善

从 200+ 降到 ~40 处实质性问题，改善幅度约 80%。

### i18n 测试覆盖
已有 `I18nKeyCompletionTests.swift`（验证 3 个补全 key）和 `TutorialI18nTests.swift`（验证 25 个 tutorial key）。建议扩展为全量 key 完整性测试。

---

## 总结

核心问题集中在 **3 个 P0**：1 个 key 缺失（`feature.gameRecordImport`）、2 处用户可见 UI 硬编码（CommandMenu + 棋盘楚河汉界）。P1 主要是 BoardTheme 和 PGN 模块的系统性遗漏，以及 174 个未引用 key 的清理。整体 i18n 架构（L10n 运行时管理器 + xcstrings 双语）是健全的，问题在于部分模块接入 i18n 时遗漏。
