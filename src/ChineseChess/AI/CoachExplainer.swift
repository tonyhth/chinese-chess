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

    // 开局阶段场景（5 种，T-1104-1 补全：+openingTrap）
    case openingInitiative  // 抢先手
    case openingSolid       // 稳健布阵
    case openingTrap        // 陷阱走法（T-1104-1 新增）
    case openingPoorDev     // 布阵失误
    case openingZhongPao    // 中炮应对

    // 中局阶段场景（10 种，T-1104-1 补全：+5）
    case sacrificeAttack    // 弃子攻杀
    case winMaterial        // 交换得子
    case controlPoint       // 控制要点
    case tacticCombo        // 战术组合
    case mutualAttack       // 对攻互缠
    case recoverMaterial    // 失子挽回（T-1104-1 新增）
    case attackKing         // 攻王（T-1104-1 新增）
    case defensiveCounter   // 防守反击（T-1104-1 新增）
    case simplifyExchange   // 兑子简化（T-1104-1 新增）
    case middleBlunder      // 中盘失误（T-1104-1 新增）

    // 残局阶段场景（5 种，T-1104-1 补全：+2）
    case endgameWinning     // 例胜定式
    case endgameHolding     // 求和技巧
    case kingCoordination   // 王棋配合
    case endgameTechnique   // 残局技巧（T-1104-1 新增）
    case endgameBlunder     // 残局失误（T-1104-1 新增）

    // 跨阶段战术场景（4 种）
    case tacticFork         // 闪击
    case tacticPin          // 牵制
    case tacticDoubleCheck  // 双将
    case tacticSkewer       // 串打

    // 局面转折场景（2 种）


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
            phase: phase,
            moveNumber: moveNumber
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
            return classifyEndgame(delta: delta, bestMove: bestMove, moveNumber: moveNumber, analysis: analysis, fenBefore: fenBefore)
        case .middle, .all:
            return classifyMiddle(delta: delta, bestMove: bestMove, analysis: analysis, fenBefore: fenBefore, moveNumber: moveNumber)
        }
    }

    // MARK: 开局场景判断

    private func classifyOpening(delta: Int, bestMove: String, moveNumber: Int, fenBefore: String) -> CoachScenario {
        if delta > 100 { return .openingPoorDev }
        if delta <= 30 && isDevelopmentMove(bestMove, fen: fenBefore) { return .openingInitiative }
        if delta < 10 { return .openingSolid }
        // T-1104-1 新增：陷阱走法（spec §1.1：步数 ≤15 + 引诱性走法即弃子位附近）——
        // delta ≤ 100（引擎未判失误 = 诱饵有后续补偿）且落点被对方低值子攻击（诱饵语义）
        if moveNumber <= 15 && isBaitMove(bestMove, fen: fenBefore) { return .openingTrap }
        return .generic
    }

    // MARK: 中局场景判断

    private func classifyMiddle(delta: Int, bestMove: String, analysis: MoveAnalysis, fenBefore: String, moveNumber: Int) -> CoachScenario {
        // 大失误（delta ≥ 300：旧 8 场景兼容路径不变）
        if delta >= 300 {
            if isMateScore(analysis.bestEval) && !isMateScore(analysis.playerEval) {
                return .missedMate
            }
            return .blunder
        }

        // T-1104-1 新增：中盘失误（spec §1.2：步数 15-35 + delta >200；
        // delta ≥ 300 仍归旧 blunder 保向后兼容）
        if delta >= 200 && (15...35).contains(moveNumber) { return .middleBlunder }

        // T-1104-1 接线（spec §1.2）：winMaterial/recoverMaterial 为八月遗留死 case
        //（枚举/变体在库但 classify 从未返回）——delta > 100 + 安全吃子时按回追子力分流；
        // delta 50-100 的吃子仍归 missedCapture（复盘语义：错失的吃子机会）
        if delta > 100 && isSafeCapture(bestMove, fen: fenBefore) {
            if isBigPieceRecapture(bestMove, fen: fenBefore) { return .recoverMaterial }
            return .winMaterial
        }

        // 中等落差——向后兼容锚点带（missedCapture missedCheck defensiveMove 回归断言保护）
        if delta >= 50 {
            if isCheckingMove(bestMove, fen: fenBefore) { return .missedCheck }
            if isSafeCapture(bestMove, fen: fenBefore) { return .missedCapture }
            if isDefensiveMove(bestMove, fen: fenBefore, analysis: analysis) { return .defensiveMove }
            return .generic
        }

        // 低 delta——好棋场景
        if delta <= 10 {
            // T-1104-1 精化：双将（两个攻击子）优先于泛将军——v1.1 将 attackKing 从
            // 泛将军名义下拆出（旧实现 isCheckingMove → tacticDoubleCheck 名实不符，Phase3Tests 同步勘误）
            if isDoubleCheckMove(bestMove, fen: fenBefore) { return .tacticDoubleCheck }
            if isCheckingMove(bestMove, fen: fenBefore) { return .attackKing }
            // T-1104-1 新增：兑子简化（spec §1.2：delta < 30 + 兑子走法）
            if isTradeMove(bestMove, fen: fenBefore) { return .simplifyExchange }
            if isCenterControlMove(bestMove, fen: fenBefore) { return .controlPoint }
            return .tacticCombo
        }

        // delta 10-50 带
        // T-1104-1 新增：攻王（spec §1.2：bestMove 使对方被将军，无 delta 约束）
        if isCheckingMove(bestMove, fen: fenBefore) { return .attackKing }
        // T-1104-1 新增：防守反击（spec §1.2：bestEval < 0 己方劣势 + bestMove 反击型即吃子/将军）
        if analysis.bestEval < 0 && isSafeCapture(bestMove, fen: fenBefore) { return .defensiveCounter }
        if isDevelopmentMove(bestMove, fen: fenBefore) { return .developPiece }
        if isCenterControlMove(bestMove, fen: fenBefore) { return .centerControl }

        return .generic
    }

    // MARK: 残局场景判断（T-1101-5 裁定 v1.1 精化：按 spec §1.3 条件分流）

    private func classifyEndgame(delta: Int, bestMove: String, moveNumber: Int, analysis: MoveAnalysis, fenBefore: String) -> CoachScenario {
        // 残局失误（spec §1.3：delta > 150；v1.1 从旧 .blunder 改为 endgame 特有场景——
        // 旧 .blunder 兼容路径仅限 middle 相位，endgame 相位不波及旧 8 场景判定）
        if delta > 150 { return .endgameBlunder }
        // 例胜定式（spec：bestEval > 500 有必胜路径）
        if analysis.bestEval > 500 { return .endgameWinning }
        // 求和技巧（spec：bestEval < -200 弱势方守和）
        if analysis.bestEval < -200 { return .endgameHolding }
        // 王棋配合（spec：bestMove 是将/帅走法）
        if isGeneralMove(bestMove, fen: fenBefore) { return .kingCoordination }
        // 残局技巧（spec：delta ≤ 10 精确算度）
        if delta <= 10 { return .endgameTechnique }
        // 残余 fallback（spec 风险表：误分类 fallback 到 .generic 不影响功能）
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
    /// 上次棋谚出现的 moveNumber（防连续步都出棋谚）
    private var lastProverbMove: Int = -1

    private func maybeAppendProverb(to text: String, phase: GamePhase, moveNumber: Int = 0) -> String {
        guard Int.random(in: 0..<100) < 15 else { return text }
        // 连续性 guard：距上次棋谚不足 3 步则跳过
        guard moveNumber - lastProverbMove >= 3 || lastProverbMove < 0 else { return text }
        guard let proverb = ProverbLibrary.randomProverb(for: phase) else { return text }
        lastProverbMove = moveNumber
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
        case .openingTrap: return "开局陷阱"
        case .sacrificeAttack: return "弃子攻杀"
        case .winMaterial: return "交换得子"
        case .controlPoint: return "控制要点"
        case .tacticCombo: return "精妙组合"
        case .mutualAttack: return "对攻互缠"
        case .recoverMaterial: return "失子挽回"
        case .attackKing: return "攻王"
        case .defensiveCounter: return "防守反击"
        case .simplifyExchange: return "兑子简化"
        case .middleBlunder: return "中盘失误"
        case .endgameWinning: return "例胜定式"
        case .endgameHolding: return "求和技巧"
        case .kingCoordination: return "王棋配合"
        case .endgameTechnique: return "残局技巧"
        case .endgameBlunder: return "残局失误"
        case .tacticFork: return "闪击"
        case .tacticPin: return "牵制"
        case .tacticDoubleCheck: return "双将"
        case .tacticSkewer: return "串打"


        }
    }

    private func detailFor(
        scenario: CoachScenario,
        delta: Int,
        betterMove: String,
        analysis: MoveAnalysis,
        phase: GamePhase,
        moveNumber: Int
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
        case .openingTrap:
            detail = pickVariant(from: [
                "陷阱走法！看似平常，实则暗藏杀机。",
                "设伏待敌——这步棋引诱对方进入不利局面。",
                "小心！这步棋在设置陷阱。",
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
        case .recoverMaterial:
            detail = pickVariant(from: [
                String(format: "失子挽回！%@ 追回失子。", betterMove),
                "稳住——失子之后冷静补救，局面可控。",
                String(format: "回追 %@，把损失降到最小。", betterMove),
            ])
        case .attackKing:
            detail = pickVariant(from: [
                "攻王！直指九宫，对方压力骤增。",
                String(format: "%@ 直击要害，攻击目标明确。", betterMove),
                "攻击目标对准主将，杀势渐成。",
            ])
        case .defensiveCounter:
            detail = pickVariant(from: [
                "防守中寻找反击机会！",
                "劣势不慌——防守反击，一击制胜。",
                String(format: "先守后攻，%@ 蕴含反击之意。", betterMove),
            ])
        case .simplifyExchange:
            detail = pickVariant(from: [
                "兑子简化局面，优势更易把握。",
                "化繁为简——兑子之后形势明朗。",
                String(format: "%@ 兑子简化，进入自己熟悉的局面。", betterMove),
            ])
        case .middleBlunder:
            detail = pickVariant(from: [
                String(format: "中盘严重失误！建议走 %@，损失 %dcp。", betterMove, deltaStr),
                String(format: "这步损失惨重，%@ 才是正着。", betterMove),
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
        case .endgameTechnique:
            detail = pickVariant(from: [
                "残局精确算度，细节决定成败。",
                "残局功力尽显——每一步都要精确。",
                "进入残局技术阶段，走法毫厘必争。",
            ])
        case .endgameBlunder:
            detail = pickVariant(from: [
                String(format: "残局关键失误！%@ 才能守住。", betterMove),
                String(format: "残局一着不慎，建议 %@。", betterMove),
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
        }


        return maybeAppendProverb(to: detail, phase: phase, moveNumber: moveNumber)
    }

    // MARK: - 局面判断辅助

    /// 是否是杀棋分数
    private func isMateScore(_ cp: Int) -> Bool {
        abs(cp) >= EvalScaleConstants.mateThreshold  // v6.4 A-Phase2：引用唯一事实源（Ruby P2 清偿）
    }

    /// 是否是将军走法（简化判断：目标位置在九宫格附近）
    private func isCheckingMove(_ move: String, fen: String) -> Bool {
        // P2 fix: 精确推演走法后检查对方是否被将军
        guard let (from, to) = UCIMoveConverter.positions(from: move) else { return false }
        // TODO: Phase 1a.3 迁移到 LegacySearchBoard
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
        // TODO: Phase 1a.3 迁移到 LegacySearchBoard — actor 内 @Observable Board 注册 Observation 全局表有竞争风险
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

    // MARK: T-1102-1 新增场景启发式（spec §1.1-1.3）

    /// 是否是双将走法（T-1102-1 精化：泛将军拆出 attackKing 后，双将需独立检测）——
    /// 走后对方被将军且攻击将军的我方棋子 ≥ 2 个（knoxn 免疫棋子不在 legal 集内，近似成立）
    private func isDoubleCheckMove(_ move: String, fen: String) -> Bool {
        guard let (from, to) = UCIMoveConverter.positions(from: move) else { return false }
        let board = Board(fen: fen)
        guard let piece = board.piece(at: from) else { return false }
        let opponent: Side = (piece.side == .red) ? .black : .red
        let chessMove = Move(piece: piece, from: from, to: to, captured: board.piece(at: to))
        board.execute(chessMove)
        guard MoveValidator.isInCheck(opponent, on: board),
              let gp = board.generalPosition(of: opponent) else { return false }
        let ourMoves = MoveValidator.allLegalMoves(for: piece.side, on: board)
        let distinctAttackers = Set(ourMoves.filter { $0.to == gp }.map { $0.piece.id })
        return distinctAttackers.count >= 2
    }

    /// 是否是诱饵走法（T-1104-1 开局陷阱）：落点被对方攻击且攻击子价值低于走子价值
    /// （低值换高值诱饵语义），且评估未判失误（诱饵有后续补偿——由调用方 delta 约束）
    private func isBaitMove(_ move: String, fen: String) -> Bool {
        guard let (from, to) = UCIMoveConverter.positions(from: move) else { return false }
        let board = Board(fen: fen)
        guard let piece = board.piece(at: from) else { return false }
        let opponent: Side = (piece.side == .red) ? .black : .red
        let chessMove = Move(piece: piece, from: from, to: to, captured: board.piece(at: to))
        board.execute(chessMove)
        let opponentMoves = MoveValidator.allLegalMoves(for: opponent, on: board)
        let attackers = opponentMoves.filter { $0.to == to && $0.captured != nil }
        guard let cheapestAttacker = attackers.compactMap({ $0.piece.baseValue }).min() else { return false }
        return piece.baseValue > cheapestAttacker
    }

    /// 是否是兑子走法（T-1104-1 兑子简化）：吃子后对方可立即回吃（形成交换）且
    /// 被吃子价值 ≥ 走子价值（等价或更优交换）
    private func isTradeMove(_ move: String, fen: String) -> Bool {
        guard let (from, to) = UCIMoveConverter.positions(from: move) else { return false }
        let board = Board(fen: fen)
        guard let piece = board.piece(at: from), let captured = board.piece(at: to) else { return false }
        guard captured.baseValue >= piece.baseValue else { return false }
        let chessMove = Move(piece: piece, from: from, to: to, captured: captured)
        board.execute(chessMove)
        let opponent: Side = (piece.side == .red) ? .black : .red
        let opponentMoves = MoveValidator.allLegalMoves(for: opponent, on: board)
        return opponentMoves.contains { $0.to == to && $0.captured != nil }
    }

    /// 是否是将/帅走法（T-1104-1 王棋配合）：起始位置棋子为将/帅
    private func isGeneralMove(_ move: String, fen: String) -> Bool {
        guard let (from, _) = UCIMoveConverter.positions(from: move) else { return false }
        let board = Board(fen: fen)
        return board.piece(at: from)?.kind == .general
    }

    /// 是否是大子回追（T-1104-1 失子挽回）：吃回车/炮/马级子力
    private func isBigPieceRecapture(_ move: String, fen: String) -> Bool {
        guard let (_, to) = UCIMoveConverter.positions(from: move) else { return false }
        let board = Board(fen: fen)
        guard let captured = board.piece(at: to) else { return false }
        return captured.baseValue >= 400  // 马/炮/车级
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
        // TODO: Phase 1a.3 迁移到 LegacySearchBoard
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
