import Foundation

// MARK: - v3.6.0 Phase 3.1: AI 教练讲解器
//
// 设计决策（v1.1）：新增场景的 title/detail 文案存代码内（中文 only），不走 xcstrings。
// 象棋是中文文化产品，i18n 不是当前优先级。Phase 3 如需国际化再迁移到 xcstrings。

/// 教练讲解场景类型
enum CoachScenario: String, CaseIterable {
    // 旧场景（8 种）
    case blunder            // 送子/失误
    case missedMate         // 错失杀机
    case missedCheck        // 将军机会
    case missedCapture      // 吃子机会
    case developPiece       // 兵力展开
    case defensiveMove      // 防守优先
    case centerControl      // 控制中线
    case generic            // 通用 fallback

    // 开局阶段场景（4 种）
    case openingInitiative  // 抢先手
    case openingSolid       // 稳健布阵
    case openingPoorDev     // 布阵失误
    case openingZhongPao    // 中炮应对

    // 中局阶段场景（5 种）
    case sacrificeAttack    // 弃子攻杀
    case winMaterial        // 交换得子
    case controlPoint       // 控制要点
    case tacticCombo        // 战术组合
    case mutualAttack       // 对攻互缠

    // 残局阶段场景（3 种）
    case endgameWinning     // 例胜定式
    case endgameHolding     // 求和技巧
    case kingCoordination   // 王棋配合

    // 跨阶段战术场景（4 种）
    case tacticFork         // 闪击
    case tacticPin          // 牵制
    case tacticDoubleCheck  // 双将
    case tacticSkewer       // 串打

    // 局面转折场景（2 种）
    case advantageEstablished  // 优势确立
    case suddenChange          // 局面突变
}

/// 教练讲解结果
struct CoachExplanation {
    let scenario: CoachScenario
    let title: String        // 简短标题
    let detail: String       // 详细讲解
    let betterMove: String   // 推荐走法（UCI）
    let evalDelta: Int       // 评估差距（cp）
}

// MARK: - CoachExplainer

/// AI 教练讲解器
///
/// 基于 PositionAnalyzer 的分析结果，生成自然语言讲解。
/// 8 类场景模板 + fallback。
actor CoachExplainer {

    static let shared = CoachExplainer()

    private let l10n = L10n.shared

    // MARK: - 核心方法

    /// 生成单步走法的教练讲解（旧接口，保留向后兼容）
    func explain(
        analysis: MoveAnalysis,
        fenBefore: String,
        playerMove: String,
        bestMove: String
    ) -> CoachExplanation {
        explain(analysis: analysis, fenBefore: fenBefore,
                playerMove: playerMove, bestMove: bestMove,
                moveNumber: 0, board: Board(fen: fenBefore))
    }

    /// 扩展接口——支持阶段判断和趋势感知
    func explain(
        analysis: MoveAnalysis,
        fenBefore: String,
        playerMove: String,
        bestMove: String,
        moveNumber: Int,
        board: Board
    ) -> CoachExplanation {
        let delta = analysis.evalDelta
        let phase = PhaseDetector.detect(moveNumber: moveNumber, board: board)
        let scenario = classifyScenario(
            analysis: analysis,
            fenBefore: fenBefore,
            playerMove: playerMove,
            bestMove: bestMove,
            moveNumber: moveNumber,
            phase: phase
        )

        let detail = detailFor(
            scenario: scenario,
            delta: delta,
            betterMove: bestMove,
            analysis: analysis,
            phase: phase
        )

        return CoachExplanation(
            scenario: scenario,
            title: titleFor(scenario: scenario, delta: delta),
            detail: detail,
            betterMove: bestMove,
            evalDelta: delta
        )
    }

    // MARK: - 场景分类

    /// 旧接口（保留向后兼容）
    private func classifyScenario(
        analysis: MoveAnalysis,
        fenBefore: String,
        playerMove: String,
        bestMove: String
    ) -> CoachScenario {
        return classifyScenario(analysis: analysis, fenBefore: fenBefore,
                                playerMove: playerMove, bestMove: bestMove,
                                moveNumber: 0, phase: .middle)
    }

    /// 扩展接口——支持阶段判断
    private func classifyScenario(
        analysis: MoveAnalysis,
        fenBefore: String,
        playerMove: String,
        bestMove: String,
        moveNumber: Int,
        phase: GamePhase
    ) -> CoachScenario {
        let delta = analysis.evalDelta

        // 阶段优先判断
        switch phase {
        case .opening:
            return classifyOpening(delta: delta, bestMove: bestMove, moveNumber: moveNumber, fenBefore: fenBefore)
        case .endgame:
            return classifyEndgame(delta: delta, bestMove: bestMove, moveNumber: moveNumber)
        case .middle, .all:
            return classifyMiddle(delta: delta, bestMove: bestMove, analysis: analysis, fenBefore: fenBefore)
        }
    }

    // MARK: 开局场景判断

    private func classifyOpening(delta: Int, bestMove: String, moveNumber: Int, fenBefore: String) -> CoachScenario {
        if delta > 100 { return .openingPoorDev }
        if delta <= 30 && isDevelopmentMove(bestMove, fen: fenBefore) { return .openingInitiative }
        if delta < 10 { return .openingSolid }
        return .generic
    }

    // MARK: 中局场景判断

    private func classifyMiddle(delta: Int, bestMove: String, analysis: MoveAnalysis, fenBefore: String) -> CoachScenario {
        // 大失误
        if delta >= 300 {
            if isMateScore(analysis.bestEval) && !isMateScore(analysis.playerEval) {
                return .missedMate
            }
            return .blunder
        }

        // 中等落差
        if delta >= 50 {
            if isCheckingMove(bestMove, fen: fenBefore) { return .missedCheck }
            if isSafeCapture(bestMove, fen: fenBefore) { return .missedCapture }
            if isDefensiveMove(bestMove, fen: fenBefore, analysis: analysis) { return .defensiveMove }
            return .generic
        }

        // 低 delta——好棋场景
        if delta <= 10 {
            // 检查战术类型
            if isCheckingMove(bestMove, fen: fenBefore) { return .tacticDoubleCheck }
            if isCenterControlMove(bestMove, fen: fenBefore) { return .controlPoint }
            return .tacticCombo
        }

        if isDevelopmentMove(bestMove, fen: fenBefore) { return .developPiece }
        if isCenterControlMove(bestMove, fen: fenBefore) { return .centerControl }

        return .generic
    }

    // MARK: 残局场景判断

    private func classifyEndgame(delta: Int, bestMove: String, moveNumber: Int) -> CoachScenario {
        if delta > 150 { return .blunder }
        if delta <= 10 { return .endgameWinning }
        if delta < 50 { return .kingCoordination }
        return .generic
    }

    // MARK: - 模板文案（变体系统）

    /// 上次文案，避免连续重复
    private var lastTextHash: String = ""

    private func pickVariant(from variants: [String]) -> String {
        let candidates = variants.filter { $0 != lastTextHash }
        let picked = candidates.randomElement() ?? variants[0]
        lastTextHash = picked
        return picked
    }

    /// ~15% 概率插入棋谚
    private func maybeAppendProverb(to text: String, phase: GamePhase) -> String {
        guard Int.random(in: 0..<100) < 15 else { return text }
        guard let proverb = ProverbLibrary.randomProverb(for: phase) else { return text }
        return text + "——" + proverb
    }

    private func titleFor(scenario: CoachScenario, delta: Int) -> String {
        switch scenario {
        case .blunder:
            return delta >= 700 ? l10n.t("coach.blunder.severe") : l10n.t("coach.blunder.title")
        case .missedMate: return l10n.t("coach.missedMate.title")
        case .missedCheck: return l10n.t("coach.missedCheck.title")
        case .missedCapture: return l10n.t("coach.missedCapture.title")
        case .developPiece: return l10n.t("coach.develop.title")
        case .defensiveMove: return l10n.t("coach.defensive.title")
        case .centerControl: return l10n.t("coach.center.title")
        case .generic: return l10n.t("coach.generic.title")
        case .openingInitiative: return "抢先手"
        case .openingSolid: return "稳健布阵"
        case .openingPoorDev: return "布阵失误"
        case .openingZhongPao: return "中炮应对"
        case .sacrificeAttack: return "弃子攻杀"
        case .winMaterial: return "交换得子"
        case .controlPoint: return "控制要点"
        case .tacticCombo: return "精妙组合"
        case .mutualAttack: return "对攻互缠"
        case .endgameWinning: return "例胜定式"
        case .endgameHolding: return "求和技巧"
        case .kingCoordination: return "王棋配合"
        case .tacticFork: return "闪击"
        case .tacticPin: return "牵制"
        case .tacticDoubleCheck: return "双将"
        case .tacticSkewer: return "串打"
        case .advantageEstablished: return "优势确立"
        case .suddenChange: return "局面突变"
        }
    }

    private func detailFor(
        scenario: CoachScenario,
        delta: Int,
        betterMove: String,
        analysis: MoveAnalysis,
        phase: GamePhase = .middle
    ) -> String {
        let deltaStr = String(delta)

        let detail: String
        switch scenario {
        case .blunder:
            detail = String(format: l10n.t("coach.blunder.detail"), betterMove, deltaStr)
        case .missedMate:
            detail = pickVariant(from: [
                String(format: "错失杀机！建议走 %@，可形成绝杀。", betterMove),
                String(format: "可惜！这里本有杀棋，走 %@ 即可终结。", betterMove),
                String(format: "杀机稍纵即逝——%@ 是通向绝杀的正确路径。", betterMove),
                String(format: "与杀棋擦肩而过。%@ 后对方无法防守。", betterMove),
            ])
        case .missedCheck:
            detail = String(format: l10n.t("coach.missedCheck.detail"), betterMove)
        case .missedCapture:
            detail = String(format: l10n.t("coach.missedCapture.detail"), betterMove)
        case .developPiece:
            detail = String(format: l10n.t("coach.develop.detail"), betterMove)
        case .defensiveMove:
            detail = String(format: l10n.t("coach.defensive.detail"), betterMove)
        case .centerControl:
            detail = String(format: l10n.t("coach.center.detail"), betterMove)
        case .generic:
            if delta >= 50 {
                detail = String(format: l10n.t("coach.generic.detail"), betterMove, deltaStr)
            } else {
                detail = l10n.t("coach.generic.good")
            }
        case .openingInitiative:
            detail = pickVariant(from: [
                "主动变招，争夺先手。此时不宜消极应付。",
                "变化走法！试图打破平衡，对手需要准确应对。",
                "主动求变是好棋意识，不愿按部就班。",
            ])
        case .openingSolid:
            detail = pickVariant(from: [
                "稳健布阵，按谱走子，双方均势。",
                "正着。布阵并然有序，不给对手机会。",
                "扎实走法，稳扎稳打。",
            ])
        case .openingPoorDev:
            detail = pickVariant(from: [
                String(format: "布阵不够紧凑，建议走 %@。损失 %dcp。", betterMove, deltaStr),
                String(format: "出子太慢，%@ 更好。", betterMove),
                String(format: "布阵失误，%@ 可以获得更好的局面。", betterMove),
            ])
        case .openingZhongPao:
            detail = pickVariant(from: [
                "中炮应对要准确，不能大意。",
                "面对中炮，防守要紧。",
            ])
        case .sacrificeAttack:
            detail = pickVariant(from: [
                "弃子攻杀！牺牲子力换取强大攻势。",
                "果敢弃子！看到攻杀路线，子力劣势换取速度优势。",
                "壮士断腕——弃子后攻势凌厉，对手面临严峻考验。",
            ])
        case .winMaterial:
            detail = pickVariant(from: [
                String(format: "交换得子！%@ 后子力占优。", betterMove),
                String(format: "战术组合赢子，%@ 是关键。", betterMove),
                "精妙交换，净赚子力。",
            ])
        case .controlPoint:
            detail = pickVariant(from: [
                String(format: "占据战略要道，%@ 控制关键点。", betterMove),
                "好棋！占据要道，为后续进攻做准备。",
            ])
        case .tacticCombo:
            detail = pickVariant(from: [
                String(format: "精妙战术配合！%@ 是最佳走法。", betterMove),
                "好棋！战术组合严密。",
                String(format: "这步棋含深意，%@ 后局面主动。", betterMove),
            ])
        case .mutualAttack:
            detail = pickVariant(from: [
                "双方各攻一侧，比拼速度！",
                "对攻局面，先手为王。",
            ])
        case .endgameWinning:
            detail = pickVariant(from: [
                "残局例胜定式。按此走法，可逐步转化为胜势。",
                "标准胜局路径——精确走子即可，不可急躁。",
                "进入胜势残局。只需按定式推进，胜只是时间问题。",
            ])
        case .endgameHolding:
            detail = pickVariant(from: [
                "劣势残局，求和为上。坚守阵线。",
                "守和技巧！不可急躁，稳住防线。",
            ])
        case .kingCoordination:
            detail = pickVariant(from: [
                "将帅主动配合，残局关键。",
                "老将出马，发挥战斗力。",
            ])
        case .tacticFork:
            detail = pickVariant(from: [
                String(format: "闪击！一子两用，%@ 同时威胁两个目标。", betterMove),
                "精妙闪击，对手难以两全。",
            ])
        case .tacticPin:
            detail = pickVariant(from: [
                String(format: "牵制！%@ 后对方棋子动弹不得。", betterMove),
                "成功牵制，对方子力瘫痪。",
            ])
        case .tacticDoubleCheck:
            detail = pickVariant(from: [
                "双将！必须应将，对方陷入被动。",
                "双将必应，这是最强的攻击手段。",
            ])
        case .tacticSkewer:
            detail = pickVariant(from: [
                String(format: "串打！%@ 贯穿两个棋子，必得其一。", betterMove),
                "串打妙手，攻其必救。",
            ])
        case .advantageEstablished:
            detail = pickVariant(from: [
                "优势确立！局面逐步倾向己方。",
                "步步紧逼，对手已显被动。",
            ])
        case .suddenChange:
            detail = pickVariant(from: [
                "局面突然紧张！风云突变。",
                "局势急转直下！",
            ])
        }

        return maybeAppendProverb(to: detail, phase: phase)
    }

    // MARK: - 局面判断辅助

    /// 是否是杀棋分数
    private func isMateScore(_ cp: Int) -> Bool {
        abs(cp) >= 90000
    }

    /// 是否是将军走法（简化判断：目标位置在九宫格附近）
    private func isCheckingMove(_ move: String, fen: String) -> Bool {
        // P2 fix: 精确推演走法后检查对方是否被将军
        guard let (from, to) = UCIMoveConverter.positions(from: move) else { return false }
        // TODO: Phase 1a.3 迁移到 SearchBoard
        let board = Board(fen: fen)
        guard let piece = board.piece(at: from) else { return false }

        let chessMove = Move(piece: piece, from: from, to: to, captured: board.piece(at: to))
        board.execute(chessMove)

        // 走完后检查对方是否被将军
        let opponent: Side = (piece.side == .red) ? .black : .red
        return MoveValidator.isInCheck(opponent, on: board)
    }

    /// 是否是安全吃子（走法推演：吃子后己方不被将军，且落点不受对方攻击）
    private func isSafeCapture(_ move: String, fen: String) -> Bool {
        guard let (from, to) = UCIMoveConverter.positions(from: move) else { return false }
        // TODO: Phase 1a.3 迁移到 SearchBoard — actor 内 @Observable Board 注册 Observation 全局表有竞争风险
        let board = Board(fen: fen)
        guard let piece = board.piece(at: from) else { return false }
        guard let captured = board.piece(at: to) else { return false }  // 必须有吃子目标

        let chessMove = Move(piece: piece, from: from, to: to, captured: captured)
        board.execute(chessMove)

        let moverSide: Side = piece.side
        let opponentSide: Side = (moverSide == .red) ? .black : .red

        // 条件 1：走完后己方不能被将军
        if MoveValidator.isInCheck(moverSide, on: board) { return false }

        // 条件 2：落点不受对方攻击（对方无法回吃）
        let opponentMoves = MoveValidator.allLegalMoves(for: opponentSide, on: board)
        let isContested = opponentMoves.contains { $0.to == to }
        return !isContested
    }

    /// 是否是展开子力走法（简化判断：起始行在底线附近）
    private func isDevelopmentMove(_ move: String, fen: String) -> Bool {
        // UCI 格式：colRankColRank（如 "h0e3"）
        // move[1] 是起始行（0-9），0 和 9 是底线
        guard move.count >= 2 else { return false }
        let rankChar = move[move.index(move.startIndex, offsetBy: 1)]
        return rankChar == "0" || rankChar == "9"
    }

    /// 是否是防守走法
    private func isDefensiveMove(_ move: String, fen: String, analysis: MoveAnalysis) -> Bool {
        // 如果之前被将军且最佳走法是应将
        // 简化：如果 bestEval 是负的（己方劣势），推荐走法大概率是防守
        return analysis.bestEval < -50
    }

    /// 是否是中线控制走法
    private func isCenterControlMove(_ move: String, fen: String) -> Bool {
        // P3 fix: 收窄范围 c-g → d-f（九宫格列 + 中线）
        // 中国象棋中线控制核心区域：d(4列)、e(5列/正中)、f(6列)
        guard move.count >= 3 else { return false }
        let toCol = move[move.index(move.startIndex, offsetBy: 2)]
        return toCol == "d" || toCol == "e" || toCol == "f"
    }

    // MARK: - v3.9.1: Hint 教练整合

    /// Hint 场景类型（正向描述推荐走法，不同于复盘的“错过”场景）
    enum HintScenario {
        case check          // 将军
        case capture        // 吃子
        case develop        // 展开子力
        case defend         // 防守
        case centerControl  // 控制中线
        case suggested      // 通用推荐
    }

    /// Hint 讲解结果
    struct HintExplanation {
        let scenario: HintScenario
        let title: String   // ≤20 字
    }

    /// 轻量级 hint 讲解：只需 FEN + bestMove，无需完整 MoveAnalysis
    /// 生成 1 句话正向描述，说明推荐走法为什么好
    func explainHint(fen: String, bestMove: String) -> HintExplanation {
        let scenario = classifyHintScenario(fen: fen, bestMove: bestMove)
        let title = hintTitleFor(scenario: scenario)
        return HintExplanation(scenario: scenario, title: title)
    }

    private func classifyHintScenario(fen: String, bestMove: String) -> HintScenario {
        // 将军走法优先级最高
        if isCheckingMove(bestMove, fen: fen) { return .check }
        // 安全吃子
        if isSafeCapture(bestMove, fen: fen) { return .capture }
        // 中线控制
        if isCenterControlMove(bestMove, fen: fen) { return .centerControl }
        // 展开子力
        if isDevelopmentMove(bestMove, fen: fen) { return .develop }
        // 防守（简化：FEN 中己方被将军时）
        // TODO: Phase 1a.3 迁移到 SearchBoard
        let board = Board(fen: fen)
        if MoveValidator.isInCheck(board.currentTurn, on: board) { return .defend }

        return .suggested
    }

    private func hintTitleFor(scenario: HintScenario) -> String {
        switch scenario {
        case .check:         return l10n.t("hint.check")
        case .capture:       return l10n.t("hint.capture")
        case .develop:       return l10n.t("hint.develop")
        case .defend:        return l10n.t("hint.defend")
        case .centerControl: return l10n.t("hint.centerControl")
        case .suggested:     return l10n.t("hint.suggested")
        }
    }
}

// MARK: - v3.6.0 Phase 3.3: 复盘卡片

/// 对局复盘统计
struct GameReviewCard {
    let totalMoves: Int
    let qualityDistribution: [MoveQuality: Int]
    let biggestBlunder: (moveIndex: Int, delta: Int)?
    let rating: Int          // 1-5 星
    let suggestion: String   // 提升建议
}

extension CoachExplainer {
    /// 生成复盘统计卡片
    func generateReviewCard(analyses: [MoveAnalysis?]) -> GameReviewCard {
        var dist: [MoveQuality: Int] = [:]
        var biggestBlunder: (moveIndex: Int, delta: Int)? = nil

        for (i, a) in analyses.enumerated() {
            guard let a = a else { continue }
            dist[a.quality, default: 0] += 1

            if a.evalDelta >= 100 {
                if biggestBlunder == nil || a.evalDelta > biggestBlunder!.delta {
                    biggestBlunder = (i, a.evalDelta)
                }
            }
        }

        let totalAnalyzed = analyses.compactMap { $0 }.count
        let goodCount = (dist[.brilliant] ?? 0) + (dist[.good] ?? 0)
        let doubtfulCount = dist[.doubtful] ?? 0
        let badCount = (dist[.blunder] ?? 0) + (dist[.losing] ?? 0)

        // 棋力评分（1-5星）
        let rating: Int
        if totalAnalyzed == 0 {
            rating = 3
        } else {
            let goodRatio = Double(goodCount) / Double(totalAnalyzed)
            let doubtfulRatio = Double(doubtfulCount) / Double(totalAnalyzed)
            let badRatio = Double(badCount) / Double(totalAnalyzed)
            let score = goodRatio * 5 - doubtfulRatio * 0.5 - badRatio * 2
            rating = max(1, min(5, Int(score.rounded()) + 3))
        }

        // 建议文案
        let suggestion: String
        if badCount > goodCount {
            suggestion = l10n.t("coach.review.morePractice")
        } else if doubtfulCount > goodCount {
            suggestion = l10n.t("coach.review.reduceDoubtful")
        } else if rating >= 4 {
            suggestion = l10n.t("coach.review.wellPlayed")
        } else {
            suggestion = l10n.t("coach.review.keepGoing")
        }

        return GameReviewCard(
            totalMoves: totalAnalyzed,
            qualityDistribution: dist,
            biggestBlunder: biggestBlunder,
            rating: rating,
            suggestion: suggestion
        )
    }
}
