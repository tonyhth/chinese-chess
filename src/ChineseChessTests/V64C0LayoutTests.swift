import Foundation
import Testing
@testable import ChineseChess

// MARK: - v6.4 C0 布局基建测试：LayoutSpec 单源 + AdaptiveRailState 迟滞 + LayoutDump 骨架

@Suite("v6.4 C0：布局基建", .serialized)
struct V64C0LayoutTests {

    // MARK: - LayoutSpec 单源常量

    @Test("8pt 栅格：间距四档均为 4 的倍数")
    func spacingOn8ptGrid() {
        for s in [LayoutSpec.space1, LayoutSpec.space2, LayoutSpec.space3, LayoutSpec.space4] {
            #expect(s.truncatingRemainder(dividingBy: 4) == 0, "\(s) 应为 4 的倍数")
        }
        #expect(LayoutSpec.space1 < LayoutSpec.space2)
        #expect(LayoutSpec.space2 < LayoutSpec.space3)
        #expect(LayoutSpec.space3 < LayoutSpec.space4)
    }

    @Test("面板三档宽度递增且窄≥320")
    func panelWidthTiers() {
        #expect(LayoutSpec.panelWidthNarrow == 320)   // v6.2 rightMin=400 对齐中档
        #expect(LayoutSpec.panelWidthMedium == 400)
        #expect(LayoutSpec.panelWidthWide == 480)
    }

    @Test("迟滞带 1000-1080（原则二b 定案值）")
    func hysteresisBand() {
        #expect(LayoutSpec.railCollapseBelow == 1000)
        #expect(LayoutSpec.railExpandAbove == 1080)
        #expect(LayoutSpec.railHysteresisBand == 80)
    }

    @Test("P1 专用常量（rail 264 / 最小可用宽 ≈660）")
    func p1Constants() {
        #expect(LayoutSpec.p1RailWidth == 264)
        #expect(LayoutSpec.p1MinUsableWidth == 660)
    }

    @Test("连续插值：单调无跳变（原则五）")
    func interpolationMonotonic() {
        var prev = LayoutSpec.interpolate(width: 900, min: 900, max: 1280, from: 400, to: 480)
        #expect(prev == 400, "下端点 = from")
        var w: CGFloat = 910
        while w <= 1280 {
            let v = LayoutSpec.interpolate(width: w, min: 900, max: 1280, from: 400, to: 480)
            #expect(v >= prev, "宽度 ↗ 值必须 ↗（w=\(w)）")
            #expect(v <= 480 && v >= 400)
            prev = v
            w += 20
        }
        #expect(LayoutSpec.interpolate(width: 1920, min: 900, max: 1280, from: 400, to: 480) == 480,
                "上端点封顶 = to（>1920 行为=封顶停增）")
    }

    // MARK: - AdaptiveRailState 迟滞（验收锚1：双向扫掠分离断言）

    @Test("up-sweep 900→1920：带内保持收，>1080 才展")
    func upSweepStaysCollapsedUntilAbove1080() {
        var state = AdaptiveRailState(initiallyExpanded: false)
        var width: CGFloat = 900
        while width <= 1920 {
            state.update(width: width)
            if width <= 1080 {
                #expect(state.isExpanded == false,
                        "up-sweep w=\(width) 带内/带下必须保持收（路径依赖）")
            } else {
                #expect(state.isExpanded == true, "up-sweep w=\(width) >1080 必须展")
            }
            width += 20
        }
    }

    @Test("down-sweep 1920→900：带内保持展，<1000 才收")
    func downSweepStaysExpandedUntilBelow1000() {
        var state = AdaptiveRailState(initiallyExpanded: true)
        var width: CGFloat = 1920
        while width >= 900 {
            state.update(width: width)
            if width >= 1000 {
                #expect(state.isExpanded == true,
                        "down-sweep w=\(width) 带内/带上必须保持展（路径依赖）")
            } else {
                #expect(state.isExpanded == false, "down-sweep w=\(width) <1000 必须收")
            }
            width -= 20
        }
    }

    @Test("迟滞带内路径依赖：1040 依来向而定（单序列断言恒假的实证）")
    func bandIsPathDependent() {
        // 同一宽度 1040，来向不同结果不同
        let fromBelow = AdaptiveRailState.nextState(isExpanded: false, width: 1040,
                                                    collapseBelow: 1000, expandAbove: 1080)
        let fromAbove = AdaptiveRailState.nextState(isExpanded: true, width: 1040,
                                                    collapseBelow: 1000, expandAbove: 1080)
        #expect(fromBelow == false)
        #expect(fromAbove == true)
        #expect(fromBelow != fromAbove, "1040 在带内：状态=现态保持，双向各锁方向")
    }

    @Test("边界值：999 收 / 1000 带内保持 / 1080 带内保持 / 1081 展")
    func boundaryValues() {
        #expect(AdaptiveRailState.nextState(isExpanded: false, width: 999, collapseBelow: 1000, expandAbove: 1080) == false)
        #expect(AdaptiveRailState.nextState(isExpanded: true, width: 1000, collapseBelow: 1000, expandAbove: 1080) == true)
        #expect(AdaptiveRailState.nextState(isExpanded: false, width: 1080, collapseBelow: 1000, expandAbove: 1080) == false)
        #expect(AdaptiveRailState.nextState(isExpanded: true, width: 1081, collapseBelow: 1000, expandAbove: 1080) == true)
    }

    @Test("状态机幂等：重复喂同宽不抖动")
    func updateIsIdempotent() {
        let state = AdaptiveRailState(initiallyExpanded: true)
        state.update(width: 950)
        let after = state.isExpanded
        state.update(width: 950)
        state.update(width: 950)
        #expect(state.isExpanded == after && state.isExpanded == false)
    }

    @Test("自定义阈值注入（P3/P4 复用可测性）")
    func injectableThresholds() {
        let state = AdaptiveRailState(initiallyExpanded: true, collapseBelow: 500, expandAbove: 600)
        state.update(width: 550)
        #expect(state.isExpanded == true, "带内保持")
        state.update(width: 450)
        #expect(state.isExpanded == false)
    }

    // MARK: - LayoutDump 骨架

    @Test("LAYOUT_DUMP 默认关（无 env 时isEnabled=false）")
    func dumpDisabledByDefault() {
        // 测试进程未设 LAYOUT_DUMP env（CI/本地一致）；显式 unset 防污染
        setenv("LAYOUT_DUMP", "0", 1)
        #expect(LayoutDump.isEnabled == false)
        // 不崩即可（骨架）
        LayoutDump.sample(page: "T", width: 1280, params: ["x": "1"])
    }
}
