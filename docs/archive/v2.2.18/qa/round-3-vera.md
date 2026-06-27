# Round 3: App Store 审核指南合规检查

**审查者**: Vera  
**日期**: 2025-06-08  
**项目**: ChineseChess  
**规模**: 49 Swift 文件 / 6311 行

---

## 1. 隐私政策

**结论: P1 — 需补充隐私政策**

- App 使用 `UserDefaults` 存储对局历史、残局进度、统计数据、主题偏好（`GameHistoryStore`、`PuzzleStore`、`StatsManager`、`BoardTheme`）
- 所有数据均为设备本地存储，**无网络请求、无第三方 SDK、无数据上传**
- 不收集用户个人身份信息（无账号系统、无注册、无邮箱）
- **但**：App Store 要求所有 App 必须提供隐私政策 URL（即使不收集数据），上架前需准备
- App Store Connect 的 App Privacy 数据声明需填写：**"No Data Collected"**

**行动项**：
- [ ] 准备隐私政策页面（可使用"本应用不收集任何个人数据"的极简版本）
- [ ] 在 App Store Connect 填写隐私数据声明

---

## 2. 权限声明

**结论: ✅ 通过 — 无需特殊权限声明**

经扫描，App 仅使用以下系统框架：
- `AVFoundation`：仅 `AVAudioPlayer`（播放音效），**不录音**，不需要 `NSMicrophoneUsageDescription`
- `Foundation`、`SwiftUI`：基础框架

**未使用的权限**：定位、相机、麦克风（录音）、照片、通讯录、日历、健康、运动

> ⚠️ 注意：`AVFoundation` import 存在，但仅用于音频播放。若未来添加录音功能，需补充 `NSMicrophoneUsageDescription`。当前无需声明。

**Info.plist 状态**：项目使用 SPM（`Package.swift`），无 Xcode project 文件，Info.plist 需在 Xcode 工程化时确认。当前无自定义 Info.plist。

---

## 3. 无障碍（Accessibility）

**结论: P1 — 缺失严重**

### 3.1 VoiceOver

**0 个** `accessibilityLabel`、`accessibilityHint`、`accessibilityValue`、`accessibilityTrait` 声明。

棋类 App 的无障碍支持对视障用户尤为关键：
- 棋盘格子无 VoiceOver 标签（应标注"红帅 e1""黑车 a0"等）
- 走法记录面板无语义化标注
- 按钮仅有文字标签（"新局""悔棋"），SwiftUI `Label` 自动提供基本支持，但自定义 View 缺失

### 3.2 动态字体

**未实现**。无 `@Environment(\.sizeCategory)`、无 `minimumScaleFactor`、无 `UIFontMetrics`。所有字体大小硬编码。

### 3.3 对比度

存在潜在低对比度组合：
- `ReplayControlView`: 白色文字 + `Color(red: 50/255, green: 30/255, blue: 20/255)` 深色背景 → **对比度足够**
- `PuzzleSelectView`: `.gray` 文字 + 深色背景 → ⚠️ `.gray` 在深色背景上可能对比度不足（WCAG AA 要求 4.5:1）
- `ThemePickerView`: `.gray` 文字/边框 → 同上

**行动项**：
- [ ] 为棋盘格子添加 VoiceOver 标签
- [ ] 为关键交互元素添加 `accessibilityHint`
- [ ] 支持动态字体（至少使用 `.title`、`.body` 等语义字体）
- [ ] 验证 `.gray` 在深色背景上的对比度

---

## 4. 性能基线

**结论: P2 — 需实测验证**

静态分析发现：
- **AI 引擎**：`AIEngine.bestMove` 在 `Task.detached` 中运行，不阻塞主线程 ✅
- **音效引擎**：`SoundEngine` 使用串行队列，`AVAudioPlayer` 播放不阻塞 ✅
- **开局库**：`OpeningBook` 从 JSON 加载，首次加载可能有延迟
- **残局库**：`PuzzleStore` 从 JSON 加载，同上
- **字体注册**：`FontRegistry` 使用 CoreText `CTFontManagerRegisterFontsForURL`，启动时注册

**未发现明显性能陷阱**，但需实测：
- [ ] 冷启动时间（目标 < 2s）
- [ ] AI 思考时内存峰值（TranspositionTable 容量）
- [ ] 长对局（100+ 步）的历史记录渲染性能

---

## 5. App Store 元数据

**结论: P1 — 需准备**

项目无 App Store 元数据文件。上架前需准备：

- [ ] 应用描述（简述 + 详细描述）
- [ ] 关键词（象棋、中国象棋、残局、棋谱 等）
- [ ] 截图：6.7" / 6.5" / 5.5" 三种尺寸
- [ ] 应用图标（1024×1024）
- [ ] 分类：Games → Board / Strategy
- [ ] 年龄分级：4+（无暴力、无色情、无赌博）
- [ ] 隐私政策 URL
- [ ] 支持网址 URL

---

## 6. 审核指南合规

**结论: ✅ 通过 — 无明显违规**

逐项检查：

| 审核条款 | 状态 | 说明 |
|---------|------|------|
| 2.1 性能 | ✅ | App 功能完整，非原型/占位 |
| 2.2 最小功能 | ✅ | 有完整游戏循环、AI、残局、回放 |
| 2.3 元数据准确 | P1 | 需准备（见 §5） |
| 2.4 硬件/软件要求 | ✅ | iOS 17+ / macOS 14+ 合理 |
| 2.5 热更新/OTA | ✅ | **无** JSPatch/Rollout/React Native/WebView 远程代码 |
| 2.6 私有 API | ✅ | **无** dlopen/objc_msgSend/performSelector/method swizzle |
| 3.1 付费/IAP | ✅ | **无** StoreKit/IAP，免费 App |
| 4.1 位置/隐私 | ✅ | 无定位/相机/麦克风录音 |
| 4.2 误导性 UI | ✅ | 无模仿系统 UI 或其他 App |
| 4.3 推送通知 | ✅ | 未使用推送 |
| 5.1 数据收集 | ✅ | 无数据收集/上传/第三方 SDK |
| 5.2 数据安全 | ✅ | 仅 UserDefaults 本地存储 |

---

## 7. 代码签名

**结论: P2 — 需在 Xcode 工程化时确认**

当前项目使用 SPM（`Package.swift`），无 `.xcodeproj`/`.xcworkspace`。代码签名配置需在创建 Xcode 工程时设置：

- [ ] 创建 Xcode 项目（或生成 `.xcodeproj`）
- [ ] 配置 Team ID 和 Provisioning Profile
- [ ] 确认 Bundle ID 唯一性
- [ ] 配置 App Store Distribution 证书
- [ ] 如需 TestFlight，配置内部/外部测试组

---

## 8. 国际化

**结论: P1 — 未实现国际化**

### 8.1 硬编码中文字符串

发现 **30+ 处**硬编码中文字符串，分布在：

| 文件 | 示例 |
|------|------|
| `StatusBarView` | "红方走棋" / "黑方走棋" / "AI 思考中..." / "回合" |
| `ToolbarView` | "新局" / "悔棋" / "提示" |
| `SettingsView` | "AI 难度" / "中文传统" / "ICCS 坐标" |
| `PuzzleSelectView` | "通关 ✅" / "星级:" / "悔棋" / "提示" |
| `GameOverOverlay` | "黑方获胜！" / "和棋！" |
| `GameHistoryView` | "删除" / "步" |
| `ChineseChessiOSApp` | "棋谱" / "残局" / "回放" / "难度" / "统计" / "历史" / "主题" / "设置" / "更多" |
| `StatsPanelView` | "胜" / "负" / "和" |
| `Puzzle.swift` | "杀局" / "妙手" / "挑战" |
| `NotationGenerator` | "前" / "后" / "进" / "退" |
| `GameViewModel` | "人机对局" |
| `ReplayView` | "红" |

### 8.2 无 Localizable.strings / .xcstrings

项目无任何本地化文件。

### 8.3 日期格式硬编码

`GameHistoryView` 和 `GameViewModel` 中 `DateFormatter` 的 `dateFormat` 硬编码为 `"yyyy-MM-dd HH:mm"` 和 `"MM-dd HH:mm"`，未跟随 Locale。

**行动项**：
- [ ] 提取所有用户可见中文字符串到 `Localizable.strings` 或 `.xcstrings`
- [ ] 为 `DateFormatter` 使用 `dateStyle`/`timeStyle` 而非硬编码 format
- [ ] 如仅面向中文市场，可标注为"仅中文"，但仍建议提取字符串以便未来扩展

---

## 问题清单

| 优先级 | 编号 | 问题 | 章节 |
|--------|------|------|------|
| **P1** | R3-01 | 缺少隐私政策页面和 URL | §1 |
| **P1** | R3-02 | App Store Connect 隐私数据声明未填写 | §1 |
| **P1** | R3-03 | VoiceOver 标签完全缺失（0 个声明） | §3 |
| **P1** | R3-04 | 不支持动态字体 | §3 |
| **P1** | R3-05 | App Store 元数据未准备（描述、截图、图标、分类） | §5 |
| **P1** | R3-06 | 30+ 处硬编码中文字符串未提取 | §8 |
| **P1** | R3-07 | 日期格式硬编码，未跟随 Locale | §8 |
| **P2** | R3-08 | `.gray` 文字在深色背景上可能对比度不足 | §3 |
| **P2** | R3-09 | 性能基线未实测（启动时间、内存、长对局渲染） | §4 |
| **P2** | R3-10 | 无 Xcode 工程，代码签名未配置 | §7 |

---

## 总结

**审核指南合规性**：良好。无私有 API、无热更新、无数据收集、无误导性 UI，核心合规风险低。

**主要上架阻碍**（P1）：
1. 隐私政策缺失 — 上架必需
2. App Store 元数据缺失 — 上架必需
3. 国际化缺失 — 如仅面向中文市场可标注"仅中文"，但字符串仍建议提取
4. 无障碍缺失 — Apple 对游戏类 App 的 VoiceOver 要求趋严，可能被拒审

**建议优先级**：R3-01/02（隐私政策）→ R3-05（元数据）→ R3-06/07（国际化）→ R3-03/04（无障碍）→ P2 项
