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

    /// 残局规则表：v3.0 Phase 7 扩展至 50 种
    /// redScore 正值 = 红方胜势，负值 = 黑方胜势
    private static let endgameRules: [EndgameRule] = [
        // === 车类残局 ===
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
        // v3.0: 车胜双士
        .init(redPattern: [.chariot], blackPattern: [.advisor, .advisor], redScore: 4500),
        .init(redPattern: [.advisor, .advisor], blackPattern: [.chariot], redScore: -4500),
        // v3.0: 车胜双象
        .init(redPattern: [.chariot], blackPattern: [.elephant, .elephant], redScore: 4500),
        .init(redPattern: [.elephant, .elephant], blackPattern: [.chariot], redScore: -4500),

        // === 双车类 ===
        .init(redPattern: [.chariot, .chariot], blackPattern: [.chariot], redScore: 5000),
        .init(redPattern: [.chariot], blackPattern: [.chariot, .chariot], redScore: -5000),
        // v3.0: 双车胜车马
        .init(redPattern: [.chariot, .chariot], blackPattern: [.chariot, .horse], redScore: 4000),
        .init(redPattern: [.chariot, .horse], blackPattern: [.chariot, .chariot], redScore: -4000),
        // v3.0: 双车胜车炮
        .init(redPattern: [.chariot, .chariot], blackPattern: [.chariot, .cannon], redScore: 4000),
        .init(redPattern: [.chariot, .cannon], blackPattern: [.chariot, .chariot], redScore: -4000),

        // === 马炮类 ===
        .init(redPattern: [.horse, .cannon], blackPattern: [.horse], redScore: 3000),
        .init(redPattern: [.horse], blackPattern: [.horse, .cannon], redScore: -3000),
        .init(redPattern: [.horse, .cannon], blackPattern: [.cannon], redScore: 2500),
        .init(redPattern: [.cannon], blackPattern: [.horse, .cannon], redScore: -2500),
        .init(redPattern: [.horse, .cannon], blackPattern: [.advisor, .elephant], redScore: 3500),
        .init(redPattern: [.advisor, .elephant], blackPattern: [.horse, .cannon], redScore: -3500),

        // === 双马/双炮 ===
        .init(redPattern: [.horse, .horse], blackPattern: [.cannon, .cannon], redScore: 500),
        .init(redPattern: [.cannon, .cannon], blackPattern: [.horse, .horse], redScore: -500),
        // v3.0: 双马胜双士
        .init(redPattern: [.horse, .horse], blackPattern: [.advisor, .advisor], redScore: 1500),
        .init(redPattern: [.advisor, .advisor], blackPattern: [.horse, .horse], redScore: -1500),
        // v3.0: 双炮胜双士
        .init(redPattern: [.cannon, .cannon], blackPattern: [.advisor, .advisor], redScore: 1200),
        .init(redPattern: [.advisor, .advisor], blackPattern: [.cannon, .cannon], redScore: -1200),
        // v3.0: 双炮和双象（和棋）
        .init(redPattern: [.cannon, .cannon], blackPattern: [.elephant, .elephant], redScore: 0),
        .init(redPattern: [.elephant, .elephant], blackPattern: [.cannon, .cannon], redScore: 0),

        // === 单子残局 ===
        .init(redPattern: [.horse], blackPattern: [], redScore: 2000),
        .init(redPattern: [], blackPattern: [.horse], redScore: -2000),
        .init(redPattern: [.cannon], blackPattern: [], redScore: 2000),
        .init(redPattern: [], blackPattern: [.cannon], redScore: -2000),
        // v3.0: 炮+士 > 单马
        .init(redPattern: [.cannon, .advisor], blackPattern: [.horse], redScore: 1500),
        .init(redPattern: [.horse], blackPattern: [.cannon, .advisor], redScore: -1500),
        // v3.0: 炮+象 > 单马
        .init(redPattern: [.cannon, .elephant], blackPattern: [.horse], redScore: 1300),
        .init(redPattern: [.horse], blackPattern: [.cannon, .elephant], redScore: -1300),

        // === 兵/卒残局 ===
        .init(redPattern: [.soldier], blackPattern: [], redScore: 800),
        .init(redPattern: [], blackPattern: [.soldier], redScore: -800),
        .init(redPattern: [.soldier, .soldier], blackPattern: [], redScore: 1500),
        .init(redPattern: [], blackPattern: [.soldier, .soldier], redScore: -1500),
        .init(redPattern: [.soldier], blackPattern: [.advisor], redScore: 500),
        .init(redPattern: [.advisor], blackPattern: [.soldier], redScore: -500),
        .init(redPattern: [.soldier], blackPattern: [.elephant], redScore: 500),
        .init(redPattern: [.elephant], blackPattern: [.soldier], redScore: -500),
        .init(redPattern: [.chariot, .soldier], blackPattern: [.chariot], redScore: 2000),
        .init(redPattern: [.chariot], blackPattern: [.chariot, .soldier], redScore: -2000),
        .init(redPattern: [.cannon, .soldier], blackPattern: [.cannon], redScore: 800),
        .init(redPattern: [.cannon], blackPattern: [.cannon, .soldier], redScore: -800),
        .init(redPattern: [.horse, .soldier], blackPattern: [.horse], redScore: 800),
        .init(redPattern: [.horse], blackPattern: [.horse, .soldier], redScore: -800),

        // v3.0: === 基础杀法 ===
        // 双兵胜单士象
        .init(redPattern: [.soldier, .soldier], blackPattern: [.advisor], redScore: 1200),
        .init(redPattern: [.advisor], blackPattern: [.soldier, .soldier], redScore: -1200),
        .init(redPattern: [.soldier, .soldier], blackPattern: [.elephant], redScore: 1200),
        .init(redPattern: [.elephant], blackPattern: [.soldier, .soldier], redScore: -1200),
        // 三兵胜士象全
        .init(redPattern: [.soldier, .soldier, .soldier], blackPattern: [.advisor, .advisor, .elephant, .elephant], redScore: 2000),
        .init(redPattern: [.advisor, .advisor, .elephant, .elephant], blackPattern: [.soldier, .soldier, .soldier], redScore: -2000),
        // v3.0: 车兵胜单车
        .init(redPattern: [.chariot, .soldier], blackPattern: [.chariot], redScore: 2500),
        .init(redPattern: [.chariot], blackPattern: [.chariot, .soldier], redScore: -2500),
        // v3.0: 马兵胜单马
        .init(redPattern: [.horse, .soldier], blackPattern: [.horse], redScore: 1000),
        .init(redPattern: [.horse], blackPattern: [.horse, .soldier], redScore: -1000),
        // v3.0: 炮兵胜单炮
        .init(redPattern: [.cannon, .soldier], blackPattern: [.cannon], redScore: 1000),
        .init(redPattern: [.cannon], blackPattern: [.cannon, .soldier], redScore: -1000),

        // v3.0: === 复杂杀法 ===
        // 双车错（双车无阻拦）
        .init(redPattern: [.chariot, .chariot], blackPattern: [.advisor, .elephant], redScore: 6000),
        .init(redPattern: [.advisor, .elephant], blackPattern: [.chariot, .chariot], redScore: -6000),
        // 马后炮（马炮组合在对方将附近）
        .init(redPattern: [.horse, .cannon], blackPattern: [.advisor], redScore: 4000),
        .init(redPattern: [.advisor], blackPattern: [.horse, .cannon], redScore: -4000),
        // 天地炮（上下炮夹击）
        .init(redPattern: [.cannon, .cannon], blackPattern: [.advisor], redScore: 3500),
        .init(redPattern: [.advisor], blackPattern: [.cannon, .cannon], redScore: -3500),
        // 大刀剜心（车坐中心）
        .init(redPattern: [.chariot], blackPattern: [.advisor, .advisor], redScore: 3500),
        .init(redPattern: [.advisor, .advisor], blackPattern: [.chariot], redScore: -3500),

        // v3.0: === 实用残局 ===
        // 车炮胜车（有炮架）
        .init(redPattern: [.chariot, .cannon], blackPattern: [.chariot], redScore: 3000),
        .init(redPattern: [.chariot], blackPattern: [.chariot, .cannon], redScore: -3000),
        // 车马胜车
        .init(redPattern: [.chariot, .horse], blackPattern: [.chariot], redScore: 3500),
        .init(redPattern: [.chariot], blackPattern: [.chariot, .horse], redScore: -3500),
        // 马炮胜双士
        .init(redPattern: [.horse, .cannon], blackPattern: [.advisor, .advisor], redScore: 2500),
        .init(redPattern: [.advisor, .advisor], blackPattern: [.horse, .cannon], redScore: -2500),

        // v3.0: 和棋判定中的「车和马」「车和炮」被前面的车胜马(6000)/车胜炮(5000)覆盖
        // 删除死代码，保留双炮和双象的和棋判定（不与前面的规则冲突）
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
