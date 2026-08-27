import XCTest
import SwiftUI
@testable import ChineseChess

// MARK: - v6.2.1 速度菜单零渲染像素差分回归（整行复刻，Ruby vtf_pick3 法移植）
//
// 背景：洪涛实机回归——速度 Menu(NSMenu 后端)在容器宽不足时 label 文字整体
// 零字形渲染（fixedSize 防不住）。Ruby 两轮像素差分定性：
// - 第一轮 direct wide：恢复点 ~392-400
// - 第二轮 VTF 结构（vtf_pick3）：死区 364-388pt、392 恢复 → rightMin=380 落死区（P1-1）
//
// 判定逻辑（Ruby 法）：整行复刻（controlRow 结构含 Menu + ViewThatFits 双态 +
// wide minWidth 400 死区补丁，与真视图唯一差别 = 不含 keyboardShortcut 隐藏按钮
// ——该类按钮导致任何离屏栅格化整体平面化），同一宽度渲染 speedText="0.5x" 与
// "" 两实例，暗像素计数差 > 30 = 文字渲染；≤30 = 零渲染回归。
//
// ⚠️ 渲染器选型（踩坑入档，2026-08-27/28）：
// - 真视图（含隐藏 keyboardShortcut）：ImageRenderer / NSHostingView.cacheDisplay /
//   离屏 NSWindow 全部整体平面化（内容不落图）→ 真视图像素级验证归 M4 手工（Tina）。
// - 不含 keyboardShortcut 的 Menu 行：NSHostingView+cacheDisplay 可正常渲染
//   （Ruby 两轮实验 + 本套件复刻三方证实）——故整行复刻为本套件唯一有效构造。
// - 旧 L2（fittingSize ≤ 提案宽）恒真（Spacer 吸收压缩），Ruby P1-2 判 D4 禁止
//   模式同族，已删除。

#if os(macOS)
@MainActor
final class V62SpeedMenuPixelTests: XCTestCase {

    // MARK: - 整行复刻（与 controlRow/VTF 结构 1:1，无 keyboardShortcut）

    private struct Row: View {
        var compact: Bool
        var speedText: String
        var body: some View {
            HStack(spacing: compact ? 6 : 10) {
                Button(action: {}) { Image(systemName: "backward.frame") }.disabled(true)
                Button(action: {}) { Image(systemName: "pause.fill") }
                Button(action: {}) { Image(systemName: "forward.frame") }.disabled(true)
                Divider().frame(height: 20)
                Menu { ForEach(0..<4) { _ in Button("x") {} } } label: {
                    HStack(spacing: 2) {
                        Text(speedText)
                            .font(.subheadline.monospacedDigit())
                            .fixedSize(horizontal: true, vertical: false)
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                    .padding(.horizontal, compact ? 4 : 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                Divider().frame(height: 20)
                Toggle(isOn: .constant(true)) { Image(systemName: "repeat") }
                    .toggleStyle(.button)
                if !compact { Spacer() }
                Button(action: {}) { Image(systemName: "gearshape") }
                Button(action: {}) { Image(systemName: "list.bullet") }
            }
            .controlSize(compact ? .small : .regular)
        }
    }

    private struct Bar: View {
        var speedText: String
        var body: some View {
            ViewThatFits(in: .horizontal) {
                Row(compact: false, speedText: speedText)
                    .frame(minWidth: 400)   // 4f2da6f 死区补丁同款
                Row(compact: true, speedText: speedText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white)
        }
    }

    /// 暗像素计数（Ruby vtf_pick3 同法：sRGB 暗像素 = 文字字形代理）
    private func darkPixelCount(_ view: some View, width: CGFloat) -> Int {
        let host = NSHostingView(
            rootView: view.frame(width: width)
                .environment(\.colorScheme, .light))
        host.frame = NSRect(x: 0, y: 0, width: width, height: 64)
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return -1 }
        host.cacheDisplay(in: host.bounds, to: rep)
        var dark = 0
        for x in 0..<rep.pixelsWide {
            for y in 0..<rep.pixelsHigh {
                if let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                   c.redComponent < 0.45, c.greenComponent < 0.45 {
                    dark += 1
                }
            }
        }
        return dark
    }

    // MARK: - 回归锚：死区边界档位全覆盖

    /// 360-424 step 4（覆盖 Ruby 实测死区 364-388 + 恢复点 392 两侧 + VTF 切换点 424 边界）。
    /// 修复生效 = 全档位选 compact（可用宽 <424）且文字渲染（diff > 30）。
    /// 若 ViewThatFits/minWidth400 补丁回归 → 364-388 档位 diff ≤ 30 直接红。
    func testSpeedLabelRendersAcrossDeadZoneBoundary() {
        for w in stride(from: 360.0, through: 424.0, by: 4.0) {
            let withText = darkPixelCount(Bar(speedText: "0.5x"), width: w)
            let withoutText = darkPixelCount(Bar(speedText: ""), width: w)
            XCTAssertGreaterThan(
                withText - withoutText, 30,
                String(format: "宽度 %.0fpt 下速度文字疑似零渲染（暗像素差 %d ≤ 30）——VTF 死区回归", w, withText - withoutText)
            )
        }
    }
}
#endif
