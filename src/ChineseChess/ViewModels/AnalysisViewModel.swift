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
    /// v6.4 A2①: 新增 recordId——启用 sidecar 持久化恢复（nil = 不启用，如临时分析）
    private(set) var persistenceRecordId: UUID?
    /// v6.4 A2①: 恢复的信封（movesHash/口径判定结果）
    private(set) var restoredEnvelope: AnalysisEnvelope?
    /// v6.4 A2①: 引擎/深度口径过期（后台静默重算 + 轻提示）
    private(set) var staleEngineProfile = false
    /// v6.4 A2①: 本分析批实际使用的引擎版本（落盘用，防止过期判定/落盘双取不一致）
    private var analysisRunEngineVersion = "unknown"
    /// v6.4 A2①: 持久化 store（测试注入临时目录 store；nil = 尚未触碰）。
    /// ⚠️ @Observable 宏不允许 lazy，用可选延迟解析实现同语义：
    /// GameRecordStore.shared.init 会 open ~/Documents/GameRecords/index.json，无 Documents
    /// TCC 授权的环境（测试宿主）open 无限阻塞（08-30 实测 103 分钟挂起根因）。
    /// 首次持久化访问（load recordId / 落盘）才解析，临时分析路径零触碰。
    var persistenceStore: GameRecordStore?

    /// 延迟解析共享 store（唯一触碰点）
    private func resolveStore() -> GameRecordStore {
        if let s = persistenceStore { return s }
        let s = GameRecordStore.shared
        persistenceStore = s
        return s
    }

    func load(moves: [String], initialFEN: String, gameMoves: [GameMove] = [], playerColorOverride: Side? = nil, recordId: UUID? = nil) {
        self.moves = moves
        self.initialFEN = initialFEN
        self.analyses = Array(repeating: nil, count: moves.count)
        self.currentIndex = 0
        self.persistenceRecordId = recordId
        self.restoredEnvelope = nil
        self.staleEngineProfile = false

        // v6.4 A2①：恢复持久化分析（movesHash 匹配才恢复；异常/不匹配走全量重跑）
        if let rid = recordId {
            let expectedHash = AnalysisMovesHash.compute(initialFEN: initialFEN, uciMoves: moves)
            if let env = resolveStore().loadAnalysisEnvelope(recordId: rid),
               env.movesHash == expectedHash {
                for (idx, a) in env.analyses where idx >= 0 && idx < analyses.count {
                    analyses[idx] = a
                }
                restoredEnvelope = env
            }
        }

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

        // v6.4 A2①：引擎/深度口径过期判定（decision v1.1 P2-2）——不匹配则丢弃恢复值后台静默重算 + 轻提示
        let currentEngineVersion = await AnalysisProfile.engineVersion()
        analysisRunEngineVersion = currentEngineVersion
        if let env = restoredEnvelope {
            if env.engineVersion != currentEngineVersion || env.depthSetting != AnalysisProfile.depth {
                staleEngineProfile = true
                analyses = Array(repeating: nil, count: moves.count)
                restoredEnvelope = nil
            }
        }

        // v4.0 Phase 3 #8: 进度总数改为玩家走法数
        let playerMoveCount = moves.indices.filter { isPlayerMove(at: $0) }.count
        analysisProgress = (0, playerMoveCount)

        // v6.4 A2①：恢复后剩余待分析数（增量从 analyzedMoveCount 起算；非玩家着不计数）
        let alreadyAnalyzed = moves.indices.filter { isPlayerMove(at: $0) && analyses[$0] != nil }.count
        let pendingCount = playerMoveCount - alreadyAnalyzed
        // 批 >30 步（待分析面）时半程 checkpoint（decision 待决点 2）
        let checkpointAt = pendingCount > 30 ? alreadyAnalyzed + pendingCount / 2 : -1

        var done = alreadyAnalyzed
        var nilCount = 0
        var checkpointTaken = false
        for (index, move) in moves.enumerated() {
            // 跳过非玩家走法
            guard isPlayerMove(at: index) else { continue }
            // v6.4 A2①：增量——已恢复/已分析的跳过（续弈仅新增着法有新分析）
            guard analyses[index] == nil else { continue }

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

            // v6.4 A2①：批中半程 checkpoint（analyzedMoveCount 单调不回退由 store 侧保证）
            // P2-3：用 >= 防将来循环 skip 逻辑变化时严格相等静默丢 checkpoint（Ruby 08-30）
            if checkpointAt >= 0 && done >= checkpointAt && !checkpointTaken {
                persistAnalysisEnvelope()
                checkpointTaken = true
            }
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

        // v6.4 A2①：批尾落盘（写序：先棋谱后 analysis——棋谱由对局流程保存，
        // 分析信封仅在分析批末尾写，天然满足先后序）
        persistAnalysisEnvelope()

        isAnalyzing = false
    }

    // MARK: - v6.4 A-Phase2 §2：变招供给 API（AnalysisPresentationProvider）

    /// 三要素中文着法转换（实际/推荐 → 中文记谱；失败回退 UCI 原文）
    /// 着前局面取 fenList[i]（v3.7.0 起精确重建）
    private func zhNotation(_ uci: String, atMoveIndex i: Int) -> String {
        guard i >= 0, i < fenList.count,
              let parsed = FENDecoder.parse(fen: fenList[i]) else { return uci }
        let board = Board(pieces: parsed.pieces)
        guard let move = ICCSParser.parse(uci, on: board) else { return uci }
        return NotationGenerator.chineseNotation(for: move, on: board)
    }

    private var analyzedCount: Int {
        moves.indices.filter { isPlayerMove(at: $0) && analyses[$0] != nil }.count
    }

    #if DEBUG
    /// 测试注入面（仅 DEBUG）：直接铺设 moves/analyses/fenList
    func loadForTest(moves: [String], analyses: [MoveAnalysis?]) {
        self.moves = moves
        self.analyses = analyses
        self.fenList = [FENParser.standardInitial]
    }
    #endif

    // MARK: - v6.4 A2① 持久化落盘

    /// 将当前分析结果写入 sidecar（仅 recordId 启用时）
    /// analyzedMoveCount = 已 non-nil 的玩家着数（尾部追加语义，单调不回退由 store 侧保证）
    private func persistAnalysisEnvelope() {
        guard let rid = persistenceRecordId, !moves.isEmpty else { return }
        var dict: [Int: MoveAnalysis] = [:]
        var analyzed = 0
        for i in moves.indices where isPlayerMove(at: i) {
            if let a = analyses[i] {
                dict[i] = a
                analyzed += 1
            }
        }
        guard analyzed > 0 else { return }
        let envelope = AnalysisEnvelope(
            schemaVersion: AnalysisProfile.schemaVersion,
            recordId: rid,
            movesHash: AnalysisMovesHash.compute(initialFEN: initialFEN, uciMoves: moves),
            analyzedMoveCount: analyzed,
            engineVersion: analysisRunEngineVersion,
            depthSetting: AnalysisProfile.depth,
            analyses: dict
        )
        resolveStore().saveAnalysisEnvelope(envelope)
        restoredEnvelope = envelope
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

// MARK: - v6.4 A-Phase2 §2：变招供给实现（读 analyses 即得，回看零引擎调用）

extension AnalysisViewModel: AnalysisPresentationProvider {

    /// 局面 k 的 top3 变招。k 域（v1.1 钉死）：k∈[1, N] 有效；k=0/k>N 返回 []，
    /// debug assert 防遇外不叫。变招数据属第 k 着分析结果（i=k-1）。
    func variations(atPosition k: Int) -> [Variation] {
        // v1.1 语义精读：k=0/k>N 属规格内边界（一律返 [] 不炸）；assert 仅防真正非法负 k
        assert(k >= 0, "k 域非法：负 k=\(k)")
        guard k >= 1, k <= moves.count else { return [] }
        let i = k - 1
        guard i < analyses.count else { return [] }
        return analyses[i]?.variations ?? []
    }

    /// 三要素：实际/推荐/亏损（第 i 着）。i 域外或该着未分析返回 nil。
    func moveReview(atMove i: Int) -> MoveReview? {
        guard i >= 0, i < analyses.count, let a = analyses[i] else { return nil }
        return MoveReview(
            played: zhNotation(a.playerMove, atMoveIndex: i),
            recommended: zhNotation(a.bestMove, atMoveIndex: i),
            lossCp: a.evalDelta
        )
    }

    func coachingPayload(atPosition k: Int) -> CoachingPayload {
        CoachingPayload(
            positionIndex: k,
            variations: variations(atPosition: k),
            moveReview: k >= 1 ? moveReview(atMove: k - 1) : nil
        )
    }
}
