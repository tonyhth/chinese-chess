# Phase 5: 体验提升 + 收尾

> **通用设计见 v2-common.md**,本文件仅包含 Phase 5 特定的设计细节和交付物。

- **Phase**: 5 — 体验提升 + 收尾
- **依赖**: Phase 2a-4（全部前置 Phase 完成）
- **验证**: `swift build` + `swift test`（全平台集成测试通过）
- **工期**: 2-3 天

---

## Phase 5 交付物

1. 音效扩充(将军、将死、悔棋、胜利、失败)
2. 走子动画增强(spring、吃子消除、选中呼吸)
3. `BoardTheme.swift` + 主题切换 UI
4. iOS 适配收尾(NavigationStack、屏幕适配、交互优化)
5. 走法提示功能(P2,如时间允许)
6. 全平台集成测试
7. Bug 修复 + 最终交付

## 验证标准

- 音效在 Debug/Release 模式下均正常(fallback 正确)
- 动画流畅无卡顿
- 主题切换即时生效
- macOS + iOS 均编译通过
- 集成测试全部通过

---

## 8. P1 体验提升设计

### 8.1 音效升级

扩展 `SoundEngine`:

```swift
class SoundEngine {
    // v1.0 已有
    func playMove()
    func playCapture()

    // v2.0 新增
    func playCheck()        // 将军 - 急促的金属碰撞音
    func playCheckmate()    // 将死 - 胜利鼓声
    func playUndo()         // 悔棋 - 轻柔的回退音
    func playVictory()      // 胜利 - 欢快的古筝旋律
    func playDefeat()       // 失败 - 低沉的鼓声
}
```

音效文件放在 `Resources/Sounds/`,保持 fallback 策略:
- **Debug 模式**:音效文件缺失时打印 `print("[Sound] missing: \(name).\(ext)")`
- **Release 模式**:静默跳过,不影响游戏流程
- 加载逻辑统一在 `loadSound(name:ext:)` 中处理,返回 nil 时该音效方法为空操作

### 8.2 走子动画

**棋子移动**(已有 `.easeInOut(duration: 0.25)`,增强):

```swift
// PieceView 中
.animation(.spring(response: 0.3, dampingFraction: 0.8), value: piece.position)
```

**吃子消除效果**:

```swift
// 在 BoardView 中,检测到 captured 时
// 被吃棋子播放缩小+淡出动画
.transition(.opacity.combined(with: .scale(scale: 0.5)))
```

**选中棋子效果**(替代当前 scaleEffect):

```swift
// PieceView 中
.overlay(
    Circle()
        .stroke(Color.yellow, lineWidth: 2)
        .frame(width: pieceDiameter + 4, height: pieceDiameter + 4)
        .opacity(isSelected ? 1 : 0)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(
            .easeInOut(duration: 0.8)
            .repeatForever(autoreverses: true),
            value: isSelected
        )
)
```

### 8.3 棋盘主题

```swift
enum BoardTheme: String, CaseIterable {
    case classicWood    // 经典木纹(v1.0 默认)
    case inkStone       // 石材水墨
}

struct ThemeColors {
    let boardBackground: [Color]     // 渐变色
    let lineColor: Color
    let textColor: Color
    let redPieceText: Color
    let blackPieceText: Color
    let pieceFill: [Color]           // 棋子底色渐变

    static func forTheme(_ theme: BoardTheme) -> ThemeColors
}
```

**石材水墨主题**:
- 棋盘底色:灰白渐变(仿石板质感)
- 线条:深灰
- 棋子底色:米白/浅灰(扁平风格,无立体感)
- 红方字色:朱红
- 黑方字色:墨黑
- 楚河汉界:楷体+水墨风

**主题切换**:
- 在设置中添加主题选择器(`ThemePickerView`)
- 存储在 UserDefaults,key = "chinesechess.theme"
- `BoardView` 和 `PieceView` 接受 `ThemeColors` 参数

---

## 9. 图标设计

### 9.1 设计方案

**风格**:中国风 + 现代扁平

**概念**:深色木质棋盘背景,一颗精致的红色"帅"棋子居中,金色边框,整体圆形构图。

**配色**:
- 背景:深棕 (#2C1808) 到 (#4A2E1A) 渐变
- 棋子底色:米白 (#FFF5E6)
- 棋子文字:朱红 (#CC0000)
- 边框:金色 (#C9A94E)

**尺寸要求**(AppIcon.appiconset):

| 用途 | 尺寸 (px) |
|------|-----------|
| Mac 512pt @2x | 1024×1024 |
| Mac 512pt @1x | 512×512 |
| Mac 256pt @2x | 512×512 |
| Mac 256pt @1x | 256×256 |
| Mac 128pt @2x | 256×256 |
| Mac 128pt @1x | 128×128 |
| Mac 32pt @2x | 64×64 |
| Mac 32pt @1x | 32×32 |
| Mac 16pt @2x | 32×32 |
| Mac 16pt @1x | 16×16 |
| iPhone 60pt @3x | 180×180 |
| iPhone 60pt @2x | 120×120 |
| iPad 76pt @2x | 152×152 |
| App Store | 1024×1024 |

### 9.2 产出物

- `Resources/Assets.xcassets/AppIcon.appiconset/` 完整目录
- `Contents.json` 正确配置各尺寸
- 图标源文件(1024×1024 master)

### 9.3 时机

Phase 1 编码前完成。Cody 开始编码时项目已包含图标。
