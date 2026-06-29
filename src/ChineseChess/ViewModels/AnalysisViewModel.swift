import Foundation

// MARK: - v3.6.0 Phase 1.2: 复盘分析 ViewModel

/// 复盘/分析会话状态管理
@Observable
final class AnalysisViewModel {

    /// 棋谱走法（UCI 格式）
    private(set) var moves: [String] = []
    /// 初始 FEN
    private(set) var initialFEN: String = ""

    /// v3.7.0 Phase 2: FEN 精确推算缓存
    private(set) var fenList: [String] = []

    /// 每步的分析结果（索引与 moves 对齐）
    private(set) var analyses: [MoveAnalysis?] = []

    /// 当前查看的步数索引（0 = 第一步走完后）
    var currentIndex: Int = 0

    /// 是否正在分析中
    var isAnalyzing: Bool = false
    /// 分析进度（已完成 / 总数）
    var analysisProgress: (done: Int, total: Int) = (0, 0)

    /// 初始化分析会话（v3.7.0: 新增 gameMoves 参数用于 FEN 推算）
    func load(moves: [String], initialFEN: String, gameMoves: [GameMove] = []) {
        self.moves = moves
        self.initialFEN = initialFEN
        self.analyses = Array(repeating: nil, count: moves.count)
        self.currentIndex = 0

        // v3.7.0 Phase 2: 预计算 FEN 列表（200+ 步 ≈ 20ms）
        if !gameMoves.isEmpty {
            self.fenList = FENRebuilder.computeAllFENs(initialFEN: initialFEN, moves: gameMoves)
        } else {
            self.fenList = [initialFEN]
        }
    }

    /// 执行完整分析（逐步）
    func analyzeAll() async {
        guard !moves.isEmpty else { return }

        isAnalyzing = true
        analysisProgress = (0, moves.count)

        for (index, move) in moves.enumerated() {
            // 计算走棋前的 FEN + moveHistory
            let moveHistory = Array(moves[0..<index])
            let fenBefore = computeFEN(before: index)

            let analysis = await PositionAnalyzer.shared.analyzeMove(
                fenBefore: fenBefore,
                playerMove: move,
                moveHistory: moveHistory
            )
            analyses[index] = analysis
            analysisProgress = (index + 1, moves.count)
        }

        isAnalyzing = false
    }

    /// 分析单步（按需分析）
    func analyzeStep(_ index: Int) async {
        guard index >= 0 && index < moves.count else { return }
        guard analyses[index] == nil else { return }

        let moveHistory = Array(moves[0..<index])
        let fenBefore = computeFEN(before: index)

        let analysis = await PositionAnalyzer.shared.analyzeMove(
            fenBefore: fenBefore,
            playerMove: moves[index],
            moveHistory: moveHistory
        )
        analyses[index] = analysis
    }

    // MARK: - 数据查询

    /// 获取评估分数序列（用于曲线图）
    var evalSequence: [(index: Int, score: Int)] {
        var result: [(Int, Int)] = []
        for (i, analysis) in analyses.enumerated() {
            if let a = analysis {
                result.append((i, a.playerEval))
            }
        }
        return result
    }

    /// 获取某步的质量
    func quality(at index: Int) -> MoveQuality? {
        guard index >= 0 && index < analyses.count else { return nil }
        return analyses[index]?.quality
    }

    /// 统计质量分布
    var qualityDistribution: [MoveQuality: Int] {
        var dist: [MoveQuality: Int] = [:]
        for analysis in analyses {
            if let a = analysis {
                dist[a.quality, default: 0] += 1
            }
        }
        return dist
    }

    // MARK: - FEN 计算

    /// v3.7.0 Phase 2: 从预计算的 fenList 取值
    /// fenList[0] = 初始局面，fenList[1] = 第一步走后，...
    /// computeFEN(before: index) = 第 index 步走棋前的 FEN = fenList[index]
    private func computeFEN(before index: Int) -> String {
        guard index >= 0 && index < fenList.count else { return initialFEN }
        return fenList[index]
    }
}
