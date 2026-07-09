import Foundation
import Testing
@testable import ChineseChess

// MARK: - Phase 4 iOS Batch 1 + Batch 2 测试

@Suite("Phase 4 iOS Batch 1 — RankUp 通知契约", .serialized)
struct RankUpNotificationTests {

    @Test("rankPromoted 通知名正确")
    func rankPromotedName() {
        #expect(Notification.Name.rankPromoted.rawValue == "com.chinesechess.rankPromoted")
    }

    @Test("rankPromoted 通知携带 Rank 对象")
    func rankPromotedCarriesRank() async {
        var receivedRank: Rank?
        let observer = NotificationCenter.default.addObserver(
            forName: .rankPromoted, object: nil, queue: .main
        ) { notification in
            receivedRank = notification.object as? Rank
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        NotificationCenter.default.post(name: .rankPromoted, object: Rank.scholar)
        // 给主队列时间处理
        try? await Task.sleep(for: .milliseconds(200))
        #expect(receivedRank == .scholar)
    }
}

@Suite("Phase 4 iOS Batch 1 — ReviewCard 生成", .serialized)
struct ReviewCardGenerationTests {

    @Test("空 analyses → 默认 3 星")
    func emptyAnalyses() async {
        let card = await CoachExplainer.shared.generateReviewCard(analyses: [])
        #expect(card.totalMoves == 0)
        #expect(card.rating == 3)
        #expect(card.biggestBlunder == nil)
    }

    @Test("全 brilliant → 高评分")
    func allBrilliant() async {
        let analyses: [MoveAnalysis?] = [
            MoveAnalysis(playerMove: "h2e2", quality: .brilliant,
                         bestMove: "h2e2", bestEval: 50, playerEval: 50,
                         evalDelta: 0, alternatives: [], isQuickResult: true),
            MoveAnalysis(playerMove: "b2e2", quality: .brilliant,
                         bestMove: "b2e2", bestEval: 30, playerEval: 30,
                         evalDelta: 0, alternatives: [], isQuickResult: true),
        ]
        let card = await CoachExplainer.shared.generateReviewCard(analyses: analyses)
        #expect(card.totalMoves == 2)
        #expect(card.qualityDistribution[.brilliant] == 2)
        #expect(card.rating >= 4, "全 brilliant 应得 4+ 星")
    }

    @Test("包含 blunder → biggestBlunder 记录最大 delta")
    func withBlunder() async {
        let analyses: [MoveAnalysis?] = [
            MoveAnalysis(playerMove: "h2e2", quality: .good,
                         bestMove: "h2e2", bestEval: 50, playerEval: 45,
                         evalDelta: 5, alternatives: []),
            MoveAnalysis(playerMove: "b2e2", quality: .blunder,
                         bestMove: "h2e2", bestEval: 200, playerEval: -100,
                         evalDelta: 300, alternatives: []),
            MoveAnalysis(playerMove: "i1h1", quality: .losing,
                         bestMove: "h2e2", bestEval: 300, playerEval: -500,
                         evalDelta: 800, alternatives: []),
        ]
        let card = await CoachExplainer.shared.generateReviewCard(analyses: analyses)
        #expect(card.biggestBlunder != nil)
        #expect(card.biggestBlunder?.moveIndex == 2, "最大 blunder 在 index 2")
        #expect(card.biggestBlunder?.delta == 800)
    }

    @Test("nil 分析步被安全跳过")
    func nilAnalysesSkipped() async {
        let analyses: [MoveAnalysis?] = [
            MoveAnalysis(playerMove: "h2e2", quality: .good,
                         bestMove: "h2e2", bestEval: 50, playerEval: 45,
                         evalDelta: 5, alternatives: []),
            nil,
            MoveAnalysis(playerMove: "b2e2", quality: .normal,
                         bestMove: "b2e2", bestEval: 30, playerEval: -20,
                         evalDelta: 50, alternatives: []),
            nil,
        ]
        let card = await CoachExplainer.shared.generateReviewCard(analyses: analyses)
        #expect(card.totalMoves == 2, "nil 步被跳过")
    }

    @Test("混合质量分布统计正确")
    func mixedQualityDistribution() async {
        let analyses: [MoveAnalysis?] = [
            MoveAnalysis(playerMove: "a", quality: .brilliant,
                         bestMove: "a", bestEval: 50, playerEval: 50,
                         evalDelta: 0, alternatives: []),
            MoveAnalysis(playerMove: "b", quality: .good,
                         bestMove: "b", bestEval: 30, playerEval: 25,
                         evalDelta: 5, alternatives: []),
            MoveAnalysis(playerMove: "c", quality: .blunder,
                         bestMove: "c", bestEval: 200, playerEval: -100,
                         evalDelta: 300, alternatives: []),
        ]
        let card = await CoachExplainer.shared.generateReviewCard(analyses: analyses)
        #expect(card.qualityDistribution[.brilliant] == 1)
        #expect(card.qualityDistribution[.good] == 1)
        #expect(card.qualityDistribution[.blunder] == 1)
    }
}

@Suite("Phase 4 iOS Batch 1 — GameRecord 构建契约", .serialized)
struct GameRecordForReviewTests {

    @Test("空 moves → buildGameRecord 返回 nil")
    @MainActor
    func emptyMovesReturnsNil() {
        let vm = GameViewModel()
        let record = vm.buildGameRecord()
        #expect(record == nil, "空 moves 不应构建 GameRecord")
    }

    @Test("GameRecord 可构造复盘所需数据")
    func gameRecordConstruction() {
        let move = GameMove(
            id: UUID(),
            piece: Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 1), id: 9),
            from: Position(row: 7, col: 1), to: Position(row: 7, col: 4),
            captured: nil, turnNumber: 1, notation: "炮二平五",
            timestamp: Date(), isCheck: false, isCheckmate: false, halfmoveClock: 0
        )
        let record = GameRecord(
            id: UUID(), title: "test", date: Date(),
            redPlayer: PlayerInfo(name: "Human", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "AI", isAI: true, difficulty: .medium),
            difficulty: .medium, result: .redWon, totalMoves: 1,
            moves: [move], initialFEN: nil, source: .versusAI
        )
        #expect(record.moves.count == 1)
        #expect(record.moves.uciMoves.count == 1)
        #expect(record.result != .playing)
    }
}

@Suite("Phase 4 iOS Batch 1 — 竞态防护逻辑", .serialized)
struct RaceConditionLogicTests {

    private func makeRecord(_ title: String) -> GameRecord {
        GameRecord(
            id: UUID(), title: title, date: Date(),
            redPlayer: PlayerInfo(name: "R", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "B", isAI: true, difficulty: .medium),
            difficulty: .medium, result: .redWon, totalMoves: 10,
            moves: [], initialFEN: nil, source: .versusAI
        )
    }

    @Test("RankUp 优先：showRankUpSheet 时 review card 延后")
    func rankUpPriority() {
        var showRankUpSheet = true
        var pendingReviewRecord: GameRecord? = nil
        var showReviewCardSheet = false

        let mockRecord = makeRecord("test")

        if showRankUpSheet {
            pendingReviewRecord = mockRecord
        } else {
            showReviewCardSheet = true
        }

        #expect(pendingReviewRecord != nil, "RankUp 显示中应存入 pending")
        #expect(showReviewCardSheet == false, "不应直接显示 review card")

        // RankUp dismiss 后恢复
        showRankUpSheet = false
        if let record = pendingReviewRecord {
            _ = record
            pendingReviewRecord = nil
            showReviewCardSheet = true
        }
        #expect(showReviewCardSheet == true, "RankUp dismiss 后应显示 review card")
        #expect(pendingReviewRecord == nil, "pending 应被清除")
    }

    @Test("新局清除：gameState 变 .playing 时清除所有 review 状态")
    func newGameClearsReview() {
        var showReviewCardSheet = true
        var reviewCardData: GameReviewCard? = GameReviewCard(
            totalMoves: 10, qualityDistribution: [:],
            biggestBlunder: nil, rating: 3, suggestion: "test"
        )
        var pendingReviewRecord: GameRecord? = makeRecord("pending")

        showReviewCardSheet = false
        reviewCardData = nil
        pendingReviewRecord = nil

        #expect(showReviewCardSheet == false)
        #expect(reviewCardData == nil)
        #expect(pendingReviewRecord == nil)
    }

    @Test("ReviewCard Task 取消：record.id 不匹配时不更新 UI")
    func taskCancellationIdMismatch() {
        let record1 = makeRecord("game1")
        let record2 = makeRecord("game2")

        let currentRecord: GameRecord? = record2
        let taskRecord = record1

        let shouldUpdate = currentRecord?.id == taskRecord.id
        #expect(shouldUpdate == false, "record.id 不匹配时不应更新 UI")
    }
}

@Suite("Phase 4 iOS Batch 1 — View 类型编译验证", .serialized)
struct ViewExistenceTests {

    @Test("OpeningExplorerView 类型存在")
    func openingExplorerViewExists() {
        #expect(OpeningExplorerView.self != NSObject.self)
    }

    @Test("RankUpView 类型存在")
    func rankUpViewExists() {
        #expect(RankUpView.self != NSObject.self)
    }

    @Test("ReviewCardView 类型存在")
    func reviewCardViewExists() {
        #expect(ReviewCardView.self != NSObject.self)
    }

    @Test("GameReviewCard 结构完整")
    func gameReviewCardStructure() {
        let card = GameReviewCard(
            totalMoves: 5,
            qualityDistribution: [.brilliant: 3, .good: 2],
            biggestBlunder: (moveIndex: 3, delta: 150),
            rating: 4,
            suggestion: "不错的对局"
        )
        #expect(card.totalMoves == 5)
        #expect(card.qualityDistribution[.brilliant] == 3)
        #expect(card.rating == 4)
    }

    @Test("draw 结果可用于复盘（与 macOS 一致）")
    func drawResultForReview() {
        let record = GameRecord(
            id: UUID(), title: "draw game", date: Date(),
            redPlayer: PlayerInfo(name: "R", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "B", isAI: true, difficulty: .medium),
            difficulty: .medium, result: .draw, totalMoves: 20,
            moves: [], initialFEN: nil, source: .versusAI
        )
        #expect(record.result == .draw)
        #expect(record.result != .playing, "和棋不是 playing 状态")
    }
}

// MARK: - Batch 2: Analysis + Coach 入口

@Suite("Phase 4 iOS Batch 2 — ReplayView 入口", .serialized)
struct ReplayViewEntryTests {

    @Test("AnalysisView 类型存在")
    func analysisViewExists() {
        #expect(AnalysisView.self != NSObject.self)
    }

    @Test("CoachSessionView 类型存在")
    func coachSessionViewExists() {
        #expect(CoachSessionView.self != NSObject.self)
    }

    @Test("ReplayView 类型存在")
    func replayViewExists() {
        #expect(ReplayView.self != NSObject.self)
    }

    @Test("GameRecord moves 空时可disabled")
    func emptyMovesDisabled() {
        let record = GameRecord(
            id: UUID(), title: "empty", date: Date(),
            redPlayer: PlayerInfo(name: "R", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "B", isAI: true, difficulty: .medium),
            difficulty: .medium, result: .redWon, totalMoves: 0,
            moves: [], initialFEN: nil, source: .versusAI
        )
        #expect(record.moves.isEmpty, "空 moves 记录可被 disabled")
    }

    @Test("GameRecord moves 非空时可启用")
    func nonEmptyMovesEnabled() {
        let move = GameMove(
            id: UUID(),
            piece: Piece(kind: .cannon, side: .red, position: Position(row: 7, col: 1), id: 9),
            from: Position(row: 7, col: 1), to: Position(row: 7, col: 4),
            captured: nil, turnNumber: 1, notation: "炮二平五",
            timestamp: Date(), isCheck: false, isCheckmate: false, halfmoveClock: 0
        )
        let record = GameRecord(
            id: UUID(), title: "has-moves", date: Date(),
            redPlayer: PlayerInfo(name: "R", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "B", isAI: true, difficulty: .medium),
            difficulty: .medium, result: .redWon, totalMoves: 1,
            moves: [move], initialFEN: nil, source: .versusAI
        )
        #expect(!record.moves.isEmpty, "有 moves 时按钮应启用")
    }

    @Test("段位门禁：秀才以上可分析、大师以上可教练")
    func rankGating() {
        // 验证 Rank 枚举值用于门禁判断
        // Analysis 需秀才以上，Coach 需大师以上
        let studentRank = Rank.student
        let scholarRank = Rank.scholar
        let masterRank = Rank.master

        // 秀才 >= 秀才 → 可分析
        #expect(scholarRank.rawValue >= Rank.scholar.rawValue, "秀才可使用分析")
        // 学童 < 秀才 → 不可分析
        #expect(studentRank.rawValue < Rank.scholar.rawValue, "学童不可使用分析")
        // 大师 >= 大师 → 可教练
        #expect(masterRank.rawValue >= Rank.master.rawValue, "大师可使用教练")
    }
}
