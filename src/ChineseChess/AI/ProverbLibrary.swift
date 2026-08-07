import Foundation

// MARK: - 棋谚库

/// 棋谚分类
enum ProverbCategory {
    case initiative    // 先手类
    case attack        // 攻杀类
    case defense       // 防守类
    case endgame       // 残局类
    case general       // 通用
}

/// 单条棋谚
struct ChessProverb {
    let text: String
    let phase: GamePhase
    let category: ProverbCategory
}

/// 棋谚库（20 条）
enum ProverbLibrary {

    static let proverbs: [ChessProverb] = [
        // 先手类
        .init(text: "宁失数子，不失一先", phase: .opening, category: .initiative),
        .init(text: "先下手为强", phase: .opening, category: .initiative),
        .init(text: "得势不得子，胜似得子", phase: .middle, category: .initiative),

        // 攻杀类
        .init(text: "攻其不备，出其不意", phase: .middle, category: .attack),
        .init(text: "车正永无沉底月", phase: .middle, category: .attack),
        .init(text: "临杀勿急", phase: .middle, category: .attack),
        .init(text: "入局勿迟", phase: .middle, category: .attack),

        // 防守类
        .init(text: "马退窝心老将发昏", phase: .middle, category: .defense),
        .init(text: "炮勿轻发", phase: .opening, category: .defense),
        .init(text: "高车保马，马保车", phase: .middle, category: .defense),
        .init(text: "以静制动", phase: .middle, category: .defense),

        // 残局类
        .init(text: "残棋炮归家", phase: .endgame, category: .endgame),
        .init(text: "单车难破士相全", phase: .endgame, category: .endgame),
        .init(text: "马兵难破士相全", phase: .endgame, category: .endgame),
        .init(text: "残局炮胜马，马胜炮", phase: .endgame, category: .endgame),
        .init(text: "老将出马，一个顶俩", phase: .endgame, category: .endgame),

        // 通用
        .init(text: "一步不慎，满盘皆输", phase: .all, category: .general),
        .init(text: "棋场如战场", phase: .all, category: .general),
        .init(text: "胜败乃兵家常事", phase: .all, category: .general),
        .init(text: "当局者迷，旁观者清", phase: .all, category: .general),
    ]

    /// 随机选取一条棋谚
    /// - Parameter phase: 当前局面阶段
    /// - Returns: 匹配阶段的棋谚文本，或 nil
    static func randomProverb(for phase: GamePhase) -> String? {
        let candidates = proverbs.filter { $0.phase == phase || $0.phase == .all }
        guard let proverb = candidates.randomElement() else { return nil }
        return proverb.text
    }
}
