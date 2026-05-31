import Foundation

// MARK: - 残局精确估值

/// 当场上总子力 ≤ 6 时，启用精确残局评估替代通用评估。
/// 基于规则匹配系统，覆盖约 20 种常见残局。
struct EndgameEvaluator {

    /// 残局规则
    private struct EndgameRule {
        let redPattern: [PieceKind]   // 红方子力组合（不含将）
        let blackPattern: [PieceKind] // 黑方子力组合（不含将）
        let redScore: Int              // 红方优势分数（负值 = 黑方优势）
    }

    /// 残局规则表：redScore 正值 = 红方胜势，负值 = 黑方胜势
    /// 分数基于通用评估尺度（子力价值 + 位置权重）
    private static let endgameRules: [EndgameRule] = [
        // 车类
        .init(redPattern: [.chariot], blackPattern: [], redScore: 8000),
        .init(redPattern: [], blackPattern: [.chariot], redScore: -8000),
        .init(redPattern: [.chariot], blackPattern: [.horse], redScore: 6000),
        .init(redPattern: [.horse], blackPattern: [.chariot], redScore: -6000),
        .init(redPattern: [.chariot], blackPattern: [.cannon], redScore: 5500),
        .init(redPattern: [.cannon], blackPattern: [.chariot], redScore: -5500),
        .init(redPattern: [.chariot], blackPattern: [.advisor, .elephant], redScore: 4000),
        .init(redPattern: [.advisor, .elephant], blackPattern: [.chariot], redScore: -4000),
        .init(redPattern: [.chariot], blackPattern: [.advisor], redScore: 5000),
        .init(redPattern: [.advisor], blackPattern: [.chariot], redScore: -5000),
        .init(redPattern: [.chariot], blackPattern: [.elephant], redScore: 5000),
        .init(redPattern: [.elephant], blackPattern: [.chariot], redScore: -5000),
        // 双车类
        .init(redPattern: [.chariot, .chariot], blackPattern: [.chariot], redScore: 5000),
        .init(redPattern: [.chariot], blackPattern: [.chariot, .chariot], redScore: -5000),
        // 马炮类
        .init(redPattern: [.horse, .cannon], blackPattern: [.horse], redScore: 3000),
        .init(redPattern: [.horse], blackPattern: [.horse, .cannon], redScore: -3000),
        .init(redPattern: [.horse, .cannon], blackPattern: [.cannon], redScore: 2500),
        .init(redPattern: [.cannon], blackPattern: [.horse, .cannon], redScore: -2500),
        .init(redPattern: [.horse, .cannon], blackPattern: [.advisor, .elephant], redScore: 3500),
        .init(redPattern: [.advisor, .elephant], blackPattern: [.horse, .cannon], redScore: -3500),
        // 双马/双炮
        .init(redPattern: [.horse, .horse], blackPattern: [.cannon, .cannon], redScore: 500),
        .init(redPattern: [.cannon, .cannon], blackPattern: [.horse, .horse], redScore: -500),
        // 单子残局
        .init(redPattern: [.horse], blackPattern: [], redScore: 2000),
        .init(redPattern: [], blackPattern: [.horse], redScore: -2000),
        .init(redPattern: [.cannon], blackPattern: [], redScore: 2000),
        .init(redPattern: [], blackPattern: [.cannon], redScore: -2000),
        // 炮+士 > 单马
        .init(redPattern: [.cannon, .advisor], blackPattern: [.horse], redScore: 1500),
        .init(redPattern: [.horse], blackPattern: [.cannon, .advisor], redScore: -1500),
    ]

    /// 残局精确评估。返回相对于 side 的分数（正值 = side 方优势）。
    /// 如果子力 > 6 或无匹配规则，返回 nil（使用通用评估）。
    static func evaluate(board: Board, for side: Side) -> Int? {
        let totalPieces = board.pieces.count
        guard totalPieces <= 6 else { return nil }

        let redPieces = classifyPieces(board.pieces(for: .red))
        let blackPieces = classifyPieces(board.pieces(for: .black))

        return lookupScore(red: redPieces, black: blackPieces, board: board, for: side)
    }

    /// 将一方的棋子分类（排除将/帅，只保留种类列表）
    private static func classifyPieces(_ pieces: [Piece]) -> [PieceKind] {
        pieces.filter { $0.kind != .general }.map { $0.kind }.sorted { kindOrder($0) < kindOrder($1) }
    }

    /// 种类排序（确保规则匹配时顺序一致）
    private static func kindOrder(_ kind: PieceKind) -> Int {
        switch kind {
        case .chariot: return 0
        case .cannon: return 1
        case .horse: return 2
        case .advisor: return 3
        case .elephant: return 4
        case .soldier: return 5
        case .general: return 6
        }
    }

    /// 在规则表中查找匹配的分数
    private static func lookupScore(red: [PieceKind], black: [PieceKind],
                                     board: Board, for side: Side) -> Int? {
        for rule in endgameRules {
            if matchPattern(red, rule.redPattern) && matchPattern(black, rule.blackPattern) {
                let raw = rule.redScore
                return (side == .red) ? raw : -raw
            }
        }
        return nil
    }

    /// 检查实际子力是否匹配规则模式
    /// 规则模式中列出的种类必须在实际子力中恰好出现对应次数
    private static func matchPattern(_ actual: [PieceKind], _ pattern: [PieceKind]) -> Bool {
        let actualCounts = Dictionary(grouping: actual, by: { $0 }).mapValues { $0.count }
        let patternCounts = Dictionary(grouping: pattern, by: { $0 }).mapValues { $0.count }
        return actualCounts == patternCounts
    }
}
