import Foundation
import CoreGraphics

// MARK: - v6.4 C0：布局规格单源常量层（LayoutSpec）
//
// 依据：v6.4-layout-redesign.md §2 原则二/二b/六b + prototypes/v6.4-p1-final.html token 层
// 铁律：全后续期布局常量引用本文件，禁止单边散调（ui-debt-ledger 三次盲调教训）。
// 深色 token 槽位预留：本期不实现深色模式，新 token 登记 colorScheme 变体槽位（原则二 Vera P2-④）。

enum LayoutSpec {

    // MARK: 8pt 基网格（间距四档，原型 --s1..--s4）

    static let space1: CGFloat = 4      // 微间距（组内）
    static let space2: CGFloat = 8      // 标准间距（组间）
    static let space3: CGFloat = 16     // 区间距
    static let space4: CGFloat = 24     // 大区块间隔

    // MARK: 字阶三档（原型 --fs-*，12/13/15）

    static let fontSizeCaption: CGFloat = 12
    static let fontSizeBody: CGFloat = 13
    static let fontSizeTitle: CGFloat = 15

    // MARK: 面板规格（原则二：全 app 统一三档）

    static let panelWidthNarrow: CGFloat = 320
    static let panelWidthMedium: CGFloat = 400   // 对齐 v6.2 rightMin=400 经验值
    static let panelWidthWide: CGFloat = 480

    static let panelCornerRadius: CGFloat = 10
    static let panelHeaderHeight: CGFloat = 32

    // MARK: P1 对局页专用（v6.4-p1-final.html 定稿）

    /// P1 右通栏宽（原型 .rail width:264，定稿值）
    static let p1RailWidth: CGFloat = 264
    /// P1 最小可用宽 ≈660（非协商基线：900 窗宽 - 通栏 264 - 边距 24*2 ≈ 588 棋盘带 + 通栏）
    static let p1MinUsableWidth: CGFloat = 660

    // MARK: P3/P4 播放/演示页（v6.4-pages-all14 原型：P3 右栏 280 / P4 300，统一 300）

    static let p34RailWidth: CGFloat = 300

    // MARK: 收纳态迟滞带（原则二b：仅 P1/P3/P4 辅助信息侧栏适用）

    static let railCollapseBelow: CGFloat = 1000   // <1000 收
    static let railExpandAbove: CGFloat = 1080     // >1080 展
    static var railHysteresisBand: CGFloat { railExpandAbove - railCollapseBelow }

    // MARK: 连续插值域（原则五）

    /// 小窗退化带（900–1280）：右面板 480→400 连续收缩的端点
    static let compactWindowMin: CGFloat = 900
    static let compactWindowMax: CGFloat = 1280

    /// 线性插值（原则五核心：参数随窗口尺寸连续变化，禁离散跳变）
    static func interpolate(width: CGFloat, min lower: CGFloat, max upper: CGFloat, from: CGFloat, to: CGFloat) -> CGFloat {
        guard width <= lower else { return to }
        guard width > 0 else { return from }
        let t = Swift.max(0, (width - lower) / Swift.max(1, upper - lower))
        return from + (to - from) * t
    }
}
