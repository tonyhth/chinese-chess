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
    /// 分析不可用提示（自研引擎回退时）
    var analysisUnavailableMessage: String? = nil

    // v4.0 Phase 3 #8: 玩家方判断（策略 B）
    /// 先手方颜色（从 FEN 推断，固定值）
    private(set) var firstMoverColor: Side = .red
    /// 玩家方颜色（默认等于先手方，可被 override 覆盖）
    private(set) var playerColor: Side = .red

    /// 玩家是否为先手方
    private var playerIsFirstMover: Bool {
        playerColor == firstMoverColor
    }

    /// 判断某步是否是玩家走法
    /// 先手方的走法总在偶数 index（0, 2, 4…）
    func isPlayerMove(at index: Int) -> Bool {
        let isFirstMoverStep = (index % 2 == 0)
        return playerIsFirstMover ? isFirstMoverStep : !isFirstMoverStep
    }

    /// 初始化分析会话（v3.7.0: 新增 gameMoves 参数用于 FEN 推算）
    /// v4.0 Phase 3 #8: 新增 playerColorOverride 参数
    func load(moves: [String], initialFEN: String, gameMoves: [GameMove] = [], playerColorOverride: Side? = nil) {
        self.moves = moves
        self.initialFEN = initialFEN
        self.analyses = Array(repeating: nil, count: moves.count)
        self.currentIndex = 0

        // v4.0 Phase 3 #8: 从 FEN 解析先手方
        let fenParts = initialFEN.split(separator: " ")
        firstMoverColor = (fenParts.count >= 2 && fenParts[1] == "b") ? .black : .red

        // 玩家方 = 默认等于先手方，可被调用方覆盖
        if let override = playerColorOverride {
            self.playerColor = override
        } else {
            self.playerColor = firstMoverColor
        }

        // v3.7.0 Phase 2: 预计算 FEN 列表（200+ 步 ≈ 20ms）
        if !gameMoves.isEmpty {
            self.fenList = FENRebuilder.computeAllFENs(initialFEN: initialFEN, moves: gameMoves)
        } else {
            self.fenList = [initialFEN]
        }
    }

    /// 执行完整分析（逐步）
    /// v4.0 Phase 3 #8: 只分析玩家方走法（策略 B）
    func analyzeAll() async {
        guard !moves.isEmpty else { return }

        // 检查引擎是否可用
        let engine = await EngineRouter.shared.switchEngineIfNeeded()
        if engine as? EmbeddedPikafishEngine == nil {
            #if DEBUG
            AppLog.analysis.error("[Analysis] Engine is not EmbeddedPikafishEngine: \(String(describing: type(of: engine)))")
            #endif
            analysisUnavailableMessage = L10n.shared.t("analysis.engineUnavailable")
            isAnalyzing = false
            return
        }

        #if DEBUG
        AppLog.analysis.info("[Analysis] Engine check passed, starting analysis of \(self.moves.count) moves")
        #endif

        isAnalyzing = true

        // v4.0 Phase 3 #8: 进度总数改为玩家走法数
        let playerMoveCount = moves.indices.filter { isPlayerMove(at: $0) }.count
        analysisProgress = (0, playerMoveCount)

        var done = 0
        var nilCount = 0
        for (index, move) in moves.enumerated() {
            // 跳过非玩家走法
            guard isPlayerMove(at: index) else { continue }

            let fenBefore = computeFEN(before: index)

            // v6.3.1 发布阻塞修复：fenBefore 已由 FENRebuilder 烘焙全部历史（v3.7.0 起精确重建），
            // 此前另传 moveHistory 致 C 层着法双重应用 → set_position 非法 → r=-1 → 静默 nil
            // （复盘第 2 着起全空指纹；C 探针实证 fen2+history=-1，洪涛 PROBE 日志 20-40ms 快失败同形）
            let analysis = await PositionAnalyzer.shared.analyzeMove(
                fenBefore: fenBefore,
                playerMove: move,
                moveHistory: []
            )
            analyses[index] = analysis
            done += 1
            analysisProgress = (done, playerMoveCount)

            #if DEBUG
            if analysis == nil {
                nilCount += 1
                AppLog.analysis.warning("[Analysis] Move #\(index) returned nil (\(nilCount)/\(done) nil so far)")
            }
            #endif
        }

        #if DEBUG
        let nonNil = done - nilCount
        AppLog.analysis.info("[Analysis] Complete: \(done) analyzed, \(nonNil) non-nil, \(nilCount) nil")
        #endif

        // Bug 1 fix: 引擎存在但分析全 nil（NNUE 未加载成功等），设置不可用提示
        if analyses.allSatisfy({ $0 == nil }) {
            #if DEBUG
            AppLog.analysis.error("[Analysis] All analyses nil — engine likely not ready (NNUE not loaded?)")
            #endif
            analysisUnavailableMessage = L10n.shared.t("analysis.engineUnavailable")
        }

        isAnalyzing = false
    }

    /// 分析单步（按需分析）
    /// v4.0 Phase 3 #8: 默认跳过 AI 走法（策略 B 一致性）
    /// - Parameter force: true 时强制分析（用于用户主动点击 AI 走法步）
    func analyzeStep(_ index: Int, force: Bool = false) async {
        guard index >= 0 && index < moves.count else { return }
        guard analyses[index] == nil else { return }
        if !force && !isPlayerMove(at: index) { return }

        let fenBefore = computeFEN(before: index)

        // v6.3.1 同修（双写历史根因见 analyzeAll 注）
        let analysis = await PositionAnalyzer.shared.analyzeMove(
            fenBefore: fenBefore,
            playerMove: moves[index],
            moveHistory: []
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
