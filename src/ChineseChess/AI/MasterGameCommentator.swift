import Foundation

// MARK: - 大师棋谱智能点评器

/// 大师棋谱播放时的异步引擎分析点评
///
/// 复用 PositionAnalyzer.shared（通过 analyzeMoveLite），不创建独立引擎实例。
/// 节流：正在分析时拒绝新请求。
/// 过滤：仅 evalDelta ≤ 10（精妙）或 > 100（失误）才返回点评。
actor MasterGameCommentator {

    static let shared = MasterGameCommentator()

    /// 正在分析中时拒绝新请求
    private var isAnalyzing = false

    /// 分析单步走法，生成点评
    /// - Parameters:
    ///   - fenBefore: 走法执行前的 FEN
    ///   - playerMove: 走法（UCI 格式）
    ///   - moveHistory: 走法历史（UCI 格式）
    /// - Returns: 点评结果，或 nil（普通走法不点评 / 分析忙 / 分析失败）
    func analyzeStep(
        fenBefore: String,
        playerMove: String,
        moveHistory: [String]
    ) async -> CommentaryItem? {
        guard !isAnalyzing else { return nil }
        isAnalyzing = true
        defer { isAnalyzing = false }

        // 轻量引擎分析
        guard let analysis = await PositionAnalyzer.shared.analyzeMoveLite(
            fenBefore: fenBefore,
            playerMove: playerMove,
            moveHistory: moveHistory,
            depth: 12,
            timeMs: 800,
            multiPVCount: 2
        ) else { return nil }

        // 过滤：普通走法不点评
        let delta = analysis.evalDelta
        guard delta <= 10 || delta > 100 else { return nil }

        // 构建棋盘用于阶段判断
        let board = Board(fen: fenBefore)
        let moveNumber = moveHistory.count

        // 模板讲解（新签名：支持阶段判断 + 棋谚）
        let explanation = await CoachExplainer.shared.explain(
            analysis: analysis,
            fenBefore: fenBefore,
            playerMove: playerMove,
            bestMove: analysis.bestMove,
            moveNumber: moveNumber,
            board: board
        )

        let type: CommentaryType
        switch analysis.quality {
        case .brilliant, .good:
            type = .keyMove
        case .doubtful, .blunder, .losing:
            type = .mistake
        default:
            type = .keyMove
        }

        var item = CommentaryItem(type: type, text: explanation.detail)
        // 带方向的 delta：偶数步=红走，奇数步=黑走
        // 正值=红方失误（delta 大且红走），负值=黑方失误
        let signedDelta: Int
        if moveHistory.count % 2 == 0 {
            signedDelta = delta  // 红方走
        } else {
            signedDelta = -delta  // 黑方走
        }
        item.evalDelta = signedDelta
        return item
    }
}
