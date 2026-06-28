import Foundation

// MARK: - v3.6.0 Q3: 成就检查器

/// 对弈结果信息（传给成就检查器）
struct GameResultInfo {
    let isWin: Bool
    let difficulty: AIDifficulty
    let moveCount: Int               // 总走法数（双方）
    let playerMoveCount: Int         // 玩家方走法数
    let elapsedSeconds: TimeInterval // 对局耗时
    let usedHint: Bool               // 是否用过提示
    let checkmatePattern: CheckmatePattern?  // 杀法类型（如有）
    let maxMaterialDeficit: Int      // 最大兵力劣势（负数=劣势）
}

/// 杀法类型识别（简化版）
enum CheckmatePattern {
    case horseCannon    // 马后炮
    case doubleRook     // 双车错
    case other          // 其他
}

/// 子力差追踪器（在 GameViewModel 中使用）
struct MaterialTracker {
    private(set) var maxDeficit: Int = 0  // 最大劣势（负数）
    private let pieceValues: [PieceKind: Int] = [
        .general: 100, .chariot: 9, .horse: 4, .cannon: 5,
        .advisor: 2, .elephant: 2, .soldier: 1
    ]

    /// 每步走完后调用
    mutating func update(board: Board, playerSide: Side) {
        let redValue = board.pieces.filter { $0.side == .red }
            .reduce(0) { $0 + (pieceValues[$1.kind] ?? 0) }
        let blackValue = board.pieces.filter { $0.side == .black }
            .reduce(0) { $0 + (pieceValues[$1.kind] ?? 0) }
        let diff = playerSide == .red ? redValue - blackValue : blackValue - redValue
        if diff < maxDeficit {
            maxDeficit = diff
        }
    }
}

// MARK: - AchievementChecker

/// 成就检查器
///
/// Q3 改造：替代旧 checkAndUnlock 中的硬编码逻辑，
/// 在对弈/残局结束后调用，补全 18 个死代码成就的触发。
enum AchievementChecker {

    /// 对弈结束后调用
    static func checkAfterGame(result: GameResultInfo, profile: PlayerProfile) -> [String] {
        guard result.isWin else { return [] }

        var unlocked: [String] = []
        let beaten = Set(profile.unlockedAchievements)

        // beat_medium / beat_hard / beat_master
        switch result.difficulty {
        case .medium:
            if !beaten.contains("beat_medium") { unlocked.append("beat_medium") }
        case .hard:
            if !beaten.contains("beat_hard") { unlocked.append("beat_hard") }
        case .master:
            if !beaten.contains("beat_master") { unlocked.append("beat_master") }
        default: break
        }

        // no_hint_win
        if !result.usedHint && result.difficulty.order >= AIDifficulty.medium.order
            && !beaten.contains("no_hint_win") {
            unlocked.append("no_hint_win")
        }

        // kill_ten_steps（10 步内将杀 AI，中等以上难度）
        if result.playerMoveCount <= 10 && result.difficulty.order >= AIDifficulty.medium.order
            && !beaten.contains("kill_ten_steps") {
            unlocked.append("kill_ten_steps")
        }

        // blitz_5min（5 分钟内赢一局）
        if result.elapsedSeconds <= 300 && !beaten.contains("blitz_5min") {
            unlocked.append("blitz_5min")
        }

        // comeback_king（兵力劣势 500+ 时翻盘获胜，MaterialTracker 值 -5 即 500cp）
        if result.maxMaterialDeficit <= -5 && !beaten.contains("comeback_king") {
            unlocked.append("comeback_king")
        }

        // kill_mate_horse_cannon / kill_mate_double_rook
        if let pattern = result.checkmatePattern {
            switch pattern {
            case .horseCannon:
                if !beaten.contains("kill_mate_horse_cannon") { unlocked.append("kill_mate_horse_cannon") }
            case .doubleRook:
                if !beaten.contains("kill_mate_double_rook") { unlocked.append("kill_mate_double_rook") }
            case .other: break
            }
        }

        // first_blood（重定义：开局 5 步内将杀）
        if result.playerMoveCount <= 5 && !beaten.contains("first_blood") {
            unlocked.append("first_blood")
        }

        // 连胜成就
        let currentStreak = profile.currentWinStreak + 1  // 本次胜利后 +1
        if currentStreak >= 5 && !beaten.contains("win_streak_5") { unlocked.append("win_streak_5") }
        if currentStreak >= 10 && !beaten.contains("win_streak_10") { unlocked.append("win_streak_10") }

        // all_difficulties（排除 beginner，需赢 4 种）
        var beatenDiff = profile.beatenDifficulties
        beatenDiff.insert(result.difficulty.id)
        let requiredDifficulties = AIDifficulty.allCases.filter { $0 != .beginner }
        let beatenRequired = requiredDifficulties.filter { beatenDiff.contains($0.id) }
        if beatenRequired.count >= requiredDifficulties.count && !beaten.contains("all_difficulties") {
            unlocked.append("all_difficulties")
        }

        // perfect_game_v2（全程走法评级 ≥ good，需 Phase 2 PositionAnalyzer）
        // 前期不可触发，待 Phase 2 数据接入后补充

        return unlocked
    }

    /// 残局通关后调用
    static func checkAfterPuzzle(
        puzzleType: String,
        chapterId: String?,
        allPuzzleCount: Int,
        completedCount: Int,
        profile: PlayerProfile
    ) -> [String] {
        var unlocked: [String] = []
        let beaten = Set(profile.unlockedAchievements)

        // first_draw_puzzle
        if puzzleType == "draw" && !beaten.contains("first_draw_puzzle") {
            unlocked.append("first_draw_puzzle")
        }

        // chapter1_clear
        if chapterId == "ch1" && !beaten.contains("chapter1_clear") {
            unlocked.append("chapter1_clear")
        }

        // endgame_master（50 局残局通关）
        if completedCount >= 50 && !beaten.contains("endgame_master") {
            unlocked.append("endgame_master")
        }

        // all_puzzles（全通关）
        if completedCount >= allPuzzleCount && allPuzzleCount > 0 && !beaten.contains("all_puzzles") {
            unlocked.append("all_puzzles")
        }

        return unlocked
    }

    /// 检测杀法类型（简化版，只看棋子类型组合）
    ///
    /// - Parameter lastMoves: 最后几步走法（含 piece 信息）
    /// - Parameter playerSide: 玩家方
    /// - Returns: 杀法类型（可能误判，标注 simplified）
    static func detectCheckmatePattern(lastMoves: [GameMove], playerSide: Side) -> CheckmatePattern? {
        let playerPieces = lastMoves.filter { $0.piece.side == playerSide }

        let hasHorse = playerPieces.contains { $0.piece.kind == .horse }
        let hasCannon = playerPieces.contains { $0.piece.kind == .cannon }
        let rookCount = playerPieces.filter { $0.piece.kind == .chariot }.count

        if hasHorse && hasCannon { return .horseCannon }
        if rookCount >= 2 { return .doubleRook }
        return .other
    }
}

// MARK: - AIDifficulty order 扩展

extension AIDifficulty {
    /// 难度排序值（用于比较）
    var order: Int {
        switch self {
        case .beginner: return 0
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        case .master: return 4
        }
    }

    /// 难度 ID（用于存储）
    var id: String { rawValue }
}
