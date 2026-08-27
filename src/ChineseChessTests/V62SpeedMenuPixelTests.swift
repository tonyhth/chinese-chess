import XCTest
import SwiftUI
@testable import ChineseChess

// MARK: - v6.2.1 速度菜单零渲染回归（双层锚：行级像素差分 + 真视图布局拟合）
//
// 背景：洪涛实机回归——速度 Menu(NSMenu 后端)在容器宽不足时 label 文字整体
// 零字形渲染（fixedSize 防不住，阈值 ≈370pt，Ruby /tmp/speed_menu_spike.swift
// 像素差分定性）。本套件把该方法产品化为长期资产。
//
// ⚠️ 为什么不能直接栅格化真 DemoControlBar（踩坑入档，2026-08-27）：
// - DemoControlBar 含隐藏 keyboardShortcut 按钮（←/空格/→/1-4 承载），
//   该类按钮使 ImageRenderer 整体平面化（实测 nil/纯色）、NSHostingView
//   cacheDisplay 对多层 Material 组合同样平面化、离屏 NSWindow 亦然。
// - 故拆双层锚：
//   L1 行级像素差分：与 controlRow 速度 Menu label 同構造（同字体/fixedSize/
//      padding）的真实 Menu 渲染，0.5x vs 1x 差分非零 → label 在该宽度渲染。
//   L2 真视图布局拟合：NSHostingView 挂真 DemoControlBar，断言 fittingSize
//      宽 ≤ 提案宽 → ViewThatFits 选中了放得下的变体（宽态放不下必切窄态）。
// 真视图像素级验证归 M4 手工清单（Tina）。

#if os(macOS)
@MainActor
final class V62SpeedMenuPixelTests: XCTestCase {

    // MARK: - L1 行级像素差分（Ruby spike 法产品化）

    /// 与 controlRow Menu label 同構造的真实 Menu 行（不含 keyboardShortcut，
    /// 避免离屏渲染平面化）
    private func speedMenuRow(label: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.subheadline.monospacedDigit())
                .fixedSize(horizontal: true, vertical: false)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func rasterize(_ view: some View, width: CGFloat, height: CGFloat) -> NSBitmapImageRep? {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height))
        renderer.proposedSize = ProposedViewSize(width: width, height: height)
        renderer.scale = 2
        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: tiff)
    }

    private func pixelDiff(_ a: NSBitmapImageRep, _ b: NSBitmapImageRep) -> Int {
        guard let da = a.bitmapData, let db = b.bitmapData,
              a.bytesPerRow == b.bytesPerRow,
              a.pixelsHigh == b.pixelsHigh else { return Int.max }
        var diff = 0
        for i in 0..<(a.bytesPerRow * a.pixelsHigh) where da[i] != db[i] { diff += 1 }
        return diff
    }

    /// 覆盖 280-380（rightMin 380 之下全区间 + 阈值上界本身）
    func testSpeedLabelRendersAtAllNarrowWidths() {
        let widths: [CGFloat] = [280, 300, 320, 340, 360, 380]
        for width in widths {
            guard let repSlow = rasterize(speedMenuRow(label: "0.5x"), width: width, height: 32),
                  let repNormal = rasterize(speedMenuRow(label: "1x"), width: width, height: 32) else {
                XCTFail("宽度 \(width)pt ImageRenderer 栅格化失败")
                continue
            }
            XCTAssertGreaterThan(
                pixelDiff(repSlow, repNormal), 0,
                "宽度 \(width)pt 下速度 label 疑似零渲染（0.5x vs 1x 像素差分 = 0）"
            )
        }
    }

    // MARK: - L2 真视图布局拟合（ViewThatFits 变体选择）

    private func makeViewModel() -> DemoViewModel {
        let puzzle = Puzzle(
            id: "v62-pixel-\(UUID().uuidString.prefix(8))",
            name: "像素差分测试残局",
            category: "测试",
            difficulty: 1,
            stars: 1,
            description: "测试",
            playerSide: "red",
            initialFEN: "rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1",
            solution: ["h2e2"],
            hints: nil,
            maxMoves: 1
        )
        return DemoViewModel(puzzle: puzzle)
    }

    /// 真 DemoControlBar 在各窄态宽度下布局必须放得下（ViewThatFits 生效）：
    /// hostingSize 宽超过提案宽 = 宽态被强选/双态失效 → 红
    func testRealBarFitsAtAllNarrowWidths() {
        let widths: [CGFloat] = [280, 300, 320, 340, 360, 380]
        for width in widths {
            let vm = makeViewModel()
            let host = NSHostingView(rootView: DemoControlBar(viewModel: vm, onBackToList: {})
                .frame(width: width))
            host.setFrameSize(NSSize(width: width, height: 64))
            host.layoutSubtreeIfNeeded()
            let fitting = host.fittingSize.width
 XCTAssertLessThanOrEqual(
                fitting, width + 0.5,
                "宽度 \(width)pt 下真 DemoControlBar 布局溢出（fitting=\(fitting)）——ViewThatFits 双态疑似失效"
            )
        }
    }
}
#endif
