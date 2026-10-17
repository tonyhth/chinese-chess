import Testing
import Foundation
@testable import ChineseChess

/// T-1017-OC-01 统计机制聚合导出——聚合器纯函数单测
/// 规格锚：T-1016-OC-01 memo §4/§6 + Luke 双域统计口径
/// （校准域 <20 剔除主判据单列异常 / 产品域全计含超短局 / 0 步局完整性告警不计入 / 阈值可调）
@Suite
struct T1017OC01GameRecordStatsTests {

    // MARK: - 造数 helpers

    private func makeMoves(count: Int, interval: TimeInterval = 30, reversed: Bool = false) -> [GameMove] {
        let start: Date = Date(timeIntervalSince1970: 1_700_000_000)
        var moves: [GameMove] = []
        moves.reserveCapacity(count)
        for i in 0..<count {
            let side: Side = (i % 2 == 0) ? .red : .black
            let fromPos: Position = Position(row: 6, col: i % 9)
            let toPos: Position = Position(row: 5, col: i % 9)
            let piece: Piece = Piece(kind: .soldier, side: side, position: fromPos, id: i)
            let ts: Date = start.addingTimeInterval(interval * Double(i))
            let move = GameMove(
                id: UUID(),
                piece: piece,
                from: fromPos,
                to: toPos,
                captured: Piece?.none,
                turnNumber: i / 2 + 1,
                notation: "",
                timestamp: ts,
                isCheck: false,
                isCheckmate: false,
                halfmoveClock: 0
            )
            moves.append(move)
        }
        if reversed { moves.reverse() } // 时间戳倒序（完整性告警面用）
        return moves
    }

    private func makeRecord(
        id: UUID = UUID(),
        source: RecordSource = .versusAI,
        redIsAI: Bool = false,
        blackIsAI: Bool = true,
        difficulty: AIDifficulty? = .novice,
        result: GameState = .redWon,
        moveCount: Int = 40,
        totalMovesOverride: Int? = nil,
        moveInterval: TimeInterval = 30,
        reversedMoves: Bool = false
    ) -> GameRecord {
        GameRecord(
            id: id,
            title: "T1017-\(id.uuidString.prefix(4))",
            redPlayer: PlayerInfo(name: redIsAI ? "AI红" : "玩家", isAI: redIsAI, difficulty: redIsAI ? difficulty : nil),
            blackPlayer: PlayerInfo(name: blackIsAI ? "AI黑" : "玩家", isAI: blackIsAI, difficulty: blackIsAI ? difficulty : nil),
            difficulty: difficulty,
            result: result,
            totalMoves: totalMovesOverride ?? moveCount,
            moves: makeMoves(count: moveCount, interval: moveInterval, reversed: reversedMoves),
            source: source
        )
    }

    private func makeProvider(_ records: [GameRecord]) -> (UUID) -> GameRecord? {
        let byId = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        return { byId[$0] }
    }

    // MARK: 纯函数

    @Test func p50OddEvenEmptySingle() {
        #expect(GameRecordStatsAggregator.percentile50([]) == nil)
        #expect(GameRecordStatsAggregator.percentile50([5]) == 5)
        #expect(GameRecordStatsAggregator.percentile50([3, 1, 2]) == 2)
        #expect(GameRecordStatsAggregator.percentile50([4, 1, 3, 2]) == 2.5)
    }

    @Test func moveStatsProductDomainCountsAllIncludingUltraShort() {
        // 裁定②：产品域全部计入含超短局——p50 分母含 10/15 步局，超短仅观测面
        let stats = GameRecordStatsAggregator.moveStats(moveCounts: [10, 25, 15, 40, 60], ultraShortThreshold: 20)
        #expect(stats.sampleCount == 5)
        #expect(stats.p50 == 25)
        #expect(stats.min == 10)
        #expect(stats.max == 60)
        #expect(stats.mean == 30)
        #expect(stats.ultraShortCount == 2)
        #expect(stats.ultraShortThreshold == 20)
    }

    @Test func playerCompositionFourQuadrants() {
        #expect(GameRecordStatsAggregator.playerComposition(redIsAI: false, blackIsAI: true) == .humanRed)
        #expect(GameRecordStatsAggregator.playerComposition(redIsAI: true, blackIsAI: false) == .humanBlack)
        #expect(GameRecordStatsAggregator.playerComposition(redIsAI: false, blackIsAI: false) == .bothHuman)
        #expect(GameRecordStatsAggregator.playerComposition(redIsAI: true, blackIsAI: true) == .bothAI)
    }

    @Test func humanOutcomeMirrorBySide() {
        // 不能假设人执红（GameViewModel:1071 isHumanRed 实证）：执方语义按人类侧镜像归账
        #expect(GameRecordStatsAggregator.humanOutcome(result: .redWon, humanIsRed: true) == .win)
        #expect(GameRecordStatsAggregator.humanOutcome(result: .redWon, humanIsRed: false) == .loss)
        #expect(GameRecordStatsAggregator.humanOutcome(result: .blackWon, humanIsRed: false) == .win)
        #expect(GameRecordStatsAggregator.humanOutcome(result: .blackWon, humanIsRed: true) == .loss)
        #expect(GameRecordStatsAggregator.humanOutcome(result: .draw, humanIsRed: true) == .draw)
        #expect(GameRecordStatsAggregator.humanOutcome(result: .playing, humanIsRed: true) == nil)
    }

    // MARK: 双域拆分与校准域异常单列

    @Test func dualDomainSplitAndCalibrationUltraShortAnomalies() {
        let humanGame = makeRecord(difficulty: .beginner, result: .blackWon, moveCount: 45) // 产品域（人执黑）
        let aiShort = makeRecord(redIsAI: true, blackIsAI: true, moveCount: 15)             // 校准域超短局
        let aiNormal = makeRecord(redIsAI: true, blackIsAI: true, moveCount: 45)            // 校准域主判据
        let records = [humanGame, aiShort, aiNormal]
        let summaries = records.map { RecordSummary(from: $0) }

        let report = GameRecordStatsAggregator.aggregate(
            summaries: summaries, recordProvider: makeProvider(records))

        // 域拆分：人机 → 产品域；双双 AI → 校准域
        #expect(report.product.countedGameCount == 1)
        #expect(report.product.moveStats.p50 == 45)
        #expect(report.calibration.gameCount == 2)
        // 裁定①：主判据只含 ≥20 步局；超短单列异常
        #expect(report.calibration.primarySample.sampleCount == 1)
        #expect(report.calibration.primarySample.p50 == 45)
        #expect(report.calibration.ultraShortAnomalies.count == 1)
        #expect(report.calibration.ultraShortAnomalies.games.first?.totalMoves == 15)
        #expect(report.loadFailures.isEmpty)
    }

    // MARK: 0 步局完整性告警（裁定③）

    @Test func zeroMoveProductGameIntegrityAlertAndExclusion() {
        let zero = makeRecord(moveCount: 0, totalMovesOverride: 0)
        let normal = makeRecord(difficulty: .amateurMid, moveCount: 30)
        let records = [zero, normal]
        let summaries = records.map { RecordSummary(from: $0) }

        let report = GameRecordStatsAggregator.aggregate(
            summaries: summaries, recordProvider: makeProvider(records))

        #expect(report.product.excludedZeroMoveCount == 1)
        #expect(report.product.countedGameCount == 1)
        #expect(report.product.moveStats.sampleCount == 1)
        #expect(report.product.integrityAlerts.contains {
            $0.reason == GameRecordStatsAlertReason.zeroMoves && $0.recordId == zero.id
        })
    }

    @Test func zeroMoveCalibrationGameIntegrityAlertAndExclusion() {
        let zeroAI = makeRecord(redIsAI: true, blackIsAI: true, moveCount: 0, totalMovesOverride: 0)
        let normalAI = makeRecord(redIsAI: true, blackIsAI: true, moveCount: 25)
        let records = [zeroAI, normalAI]
        let summaries = records.map { RecordSummary(from: $0) }

        let report = GameRecordStatsAggregator.aggregate(
            summaries: summaries, recordProvider: makeProvider(records))

        #expect(report.calibration.excludedZeroMoveCount == 1)
        #expect(report.calibration.gameCount == 2)
        #expect(report.calibration.primarySample.sampleCount == 1)
        #expect(report.calibration.ultraShortAnomalies.count == 0) // 0 步 ≠ 超短局：走完整性队列
        #expect(report.calibration.integrityAlerts.contains { $0.reason == GameRecordStatsAlertReason.zeroMoves })
    }

    // MARK: 人类视角归账（零 schema，loadRecord 读 isAI）

    @Test func humanPerspectiveAccountingBlackSideHuman() {
        let humanBlackWin = makeRecord(redIsAI: true, blackIsAI: false, result: .blackWon, moveCount: 25)
        let humanRedLoss = makeRecord(redIsAI: false, blackIsAI: true, result: .blackWon, moveCount: 25)
        let bothHuman = makeRecord(redIsAI: false, blackIsAI: false, result: .redWon, moveCount: 25)
        let records = [humanBlackWin, humanRedLoss, bothHuman]
        let summaries = records.map { RecordSummary(from: $0) }

        let report = GameRecordStatsAggregator.aggregate(
            summaries: summaries, recordProvider: makeProvider(records))

        let account = report.product.humanPerspective
        #expect(report.product.countedGameCount == 3)
        #expect(account.accountedGameCount == 2) // 双人类局不入单视角胜率分母
        #expect(account.humanBlackCount == 1)
        #expect(account.humanRedCount == 1)
        #expect(account.win == 1)
        #expect(account.loss == 1)
        #expect(account.draw == 0)
        #expect(account.winRate != nil)
        #expect(abs(account.winRate! - 0.5) < 1e-9)
        #expect(account.excludedBothHumanCount == 1)
        #expect(account.excludedUnfinishedCount == 0)
    }

    @Test func unfinishedResultAlertedAndExcludedFromWinRate() {
        let playing = makeRecord(result: .playing, moveCount: 18)
        let finished = makeRecord(result: .redWon, moveCount: 22)
        let records = [playing, finished]
        let summaries = records.map { RecordSummary(from: $0) }

        let report = GameRecordStatsAggregator.aggregate(
            summaries: summaries, recordProvider: makeProvider(records))

        #expect(report.product.humanPerspective.accountedGameCount == 1)
        #expect(report.product.humanPerspective.excludedUnfinishedCount == 1)
        #expect(report.product.integrityAlerts.contains { $0.reason == GameRecordStatsAlertReason.unfinishedResult })
        // 步数统计不受胜率分母剔除影响
        #expect(report.product.moveStats.sampleCount == 2)
    }

    // MARK: 时长推导（versusAI 域；imported 域排除）

    @Test func durationDerivationVersusAIDomainOnly() {
        let game30 = makeRecord(moveCount: 30, moveInterval: 30)                 // (30-1)*30 = 870s
        let imported = makeRecord(source: .imported, moveCount: 20, moveInterval: 60)
        let records = [game30, imported]
        let summaries = records.map { RecordSummary(from: $0) }

        let report = GameRecordStatsAggregator.aggregate(
            summaries: summaries, recordProvider: makeProvider(records))

        // imported 域过滤出产品域（时间戳不可信），时长仅 versusAI 域
        #expect(report.product.countedGameCount == 1)
        #expect(report.product.duration.sampleCount == 1)
        #expect(abs(report.product.duration.p50Seconds! - 870) < 1e-6)
        #expect(report.otherSources.countsBySource.count == 1)
        #expect(report.otherSources.countsBySource.first?.source == RecordSource.imported.rawValue)
        #expect(report.otherSources.countsBySource.first?.count == 1)
    }

    @Test func timestampOrderInvalidAlertedAndDurationExcluded() {
        let bad = makeRecord(moveCount: 10, reversedMoves: true)
        let good = makeRecord(moveCount: 10, moveInterval: 10) // (10-1)*10 = 90s
        let records = [bad, good]
        let summaries = records.map { RecordSummary(from: $0) }

        let report = GameRecordStatsAggregator.aggregate(
            summaries: summaries, recordProvider: makeProvider(records))

        #expect(report.product.durationInvalidCount == 1)
        #expect(report.product.duration.sampleCount == 1)
        #expect(abs(report.product.duration.p50Seconds! - 90) < 1e-6)
        #expect(report.product.integrityAlerts.contains { $0.reason == GameRecordStatsAlertReason.timestampOrderInvalid })
        // 步数统计不受时长剔除影响（裁定③只灭 0 步局）
        #expect(report.product.moveStats.sampleCount == 2)
    }

    // MARK: 档位切片与新手双报

    @Test func difficultySlicesAndNoviceDualReport() {
        let noviceWin = makeRecord(difficulty: .novice, result: .redWon, moveCount: 20)    // 人执红胜
        let noviceLoss = makeRecord(difficulty: .novice, result: .blackWon, moveCount: 12) // 人执红负
        let midDraw = makeRecord(difficulty: .amateurMid, result: .draw, moveCount: 50)
        let nilDiff = makeRecord(difficulty: nil, result: .draw, moveCount: 33)
        let records = [noviceWin, noviceLoss, midDraw, nilDiff]
        let summaries = records.map { RecordSummary(from: $0) }

        let report = GameRecordStatsAggregator.aggregate(
            summaries: summaries, recordProvider: makeProvider(records))

        // 档位切片：lvl1 ×2 / lvl4 ×1 / unspecified ×1（升序，unspecified 殿后）
        #expect(report.product.difficultySlices.count == 3)
        #expect(report.product.difficultySlices.map(\.tierKey) == [
            AIDifficulty.novice.rawValue, AIDifficulty.amateurMid.rawValue,
            GameRecordStatsAggregator.unspecifiedTierKey,
        ])
        let lvl1 = report.product.difficultySlices.first { $0.tierKey == AIDifficulty.novice.rawValue }
        #expect(lvl1?.gameCount == 2)
        #expect(lvl1?.moveStats.p50 == 16) // [20, 12] → 16
        #expect(lvl1?.humanPerspective.win == 1)
        #expect(lvl1?.humanPerspective.loss == 1)

        // 新手双报：口径 a（.novice 切片）并存口径 b（≤M 场）
        #expect(report.product.novice.byDifficultyNovice?.tierKey == AIDifficulty.novice.rawValue)
        #expect(report.product.novice.byLocalGameCountAtMostM.localProductGameCount == 4)
        // M 候产品面未定 → 不计算并显式标注
        #expect(report.product.novice.byLocalGameCountAtMostM.noviceMaxLocalGames == nil)
        #expect(report.product.novice.byLocalGameCountAtMostM.isNovicePhase == nil)

        // M=4 → 4 局 ≤4 新手期；M=3 → 超过
        let reportM4 = GameRecordStatsAggregator.aggregate(
            summaries: summaries, recordProvider: makeProvider(records),
            config: GameRecordStatsConfig(noviceMaxLocalGames: 4))
        #expect(reportM4.product.novice.byLocalGameCountAtMostM.isNovicePhase == true)
        let reportM3 = GameRecordStatsAggregator.aggregate(
            summaries: summaries, recordProvider: makeProvider(records),
            config: GameRecordStatsConfig(noviceMaxLocalGames: 3))
        #expect(reportM3.product.novice.byLocalGameCountAtMostM.isNovicePhase == false)
    }

    // MARK: Q4 触发线对照（信息面）

    @Test func q4TriggerCheckInformational() {
        let records = [
            makeRecord(difficulty: .novice, result: .redWon, moveCount: 10),
            makeRecord(difficulty: .novice, result: .blackWon, moveCount: 12),
        ]
        let summaries = records.map { RecordSummary(from: $0) }

        let report = GameRecordStatsAggregator.aggregate(
            summaries: summaries, recordProvider: makeProvider(records))

        // P50 = 11 < 40 → 触发；新手胜率 = 0.5 < 0.8 → 触发（信息面对照，零动作）
        #expect(report.product.q4TriggerCheck.moveP50 == 11)
        #expect(report.product.q4TriggerCheck.moveP50Triggered == true)
        #expect(report.product.q4TriggerCheck.noviceWinRate == 0.5)
        #expect(report.product.q4TriggerCheck.noviceWinRateTriggered == true)
    }

    // MARK: store 集成（只读消费）+ 孤儿摘要 + 导出 round-trip

    @Test func storeIntegrationLoadFailureAndExportRoundTrip() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("t1017-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let store = GameRecordStore(baseURL: tmpDir)

        let kept = makeRecord(difficulty: .beginner, result: .redWon, moveCount: 22)
        let ghost = makeRecord(difficulty: .novice, result: .draw, moveCount: 8)
        store.addRecord(kept)
        store.addRecord(ghost)
        // 制造孤儿摘要：删 {uuid}.json 后重载 index → loadRecord 不可读
        try? FileManager.default.removeItem(at: tmpDir.appendingPathComponent("\(ghost.id.uuidString).json"))
        store.reloadSummaries()

        let fixedDate = Date(timeIntervalSince1970: 1_700_000_123) // 整秒，iso8601 round-trip 精确
        let report = GameRecordStatsAggregator.aggregate(store: store, generatedAt: fixedDate)
        #expect(report.totalSummaryCount == 2)
        #expect(report.loadFailures.count == 1)
        #expect(report.loadFailures.first?.reason == GameRecordStatsAlertReason.recordFileMissing)
        #expect(report.product.countedGameCount == 1)
        #expect(report.product.moveStats.p50 == 22)
        #expect(report.schemaVersion == 1)
        #expect(report.config.ultraShortMoveThreshold == 20)

        // 导出 + JSON 回读 round-trip
        let exportDir = tmpDir.appendingPathComponent("export", isDirectory: true)
        let url = try GameRecordStatsAggregator.exportJSON(report: report, directory: exportDir)
        #expect(url.lastPathComponent.hasPrefix("game-stats-export-"))
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GameRecordStatsReport.self, from: data)
        #expect(decoded == report)
    }

    // MARK: 导出样例（合成数据，供收割为交付样例文件）

    @Test func exportSampleArtifact() throws {
        var records: [GameRecord] = []
        records.append(makeRecord(difficulty: .novice, result: .redWon, moveCount: 12))                 // 新手速胜（超短观测）
        records.append(makeRecord(difficulty: .novice, result: .blackWon, moveCount: 31))               // 新手负
        records.append(makeRecord(difficulty: .novice, result: .draw, moveCount: 45))                   // 新手和
        records.append(makeRecord(difficulty: .beginner, result: .blackWon, moveCount: 52))             // 人执黑负
        records.append(makeRecord(difficulty: .amateurMid, result: .redWon, moveCount: 78))             // lvl4 胜
        records.append(makeRecord(redIsAI: true, blackIsAI: true, moveCount: 15))                       // 校准域超短
        records.append(makeRecord(redIsAI: true, blackIsAI: true, moveCount: 118))                      // 校准域主判据
        records.append(makeRecord(moveCount: 0, totalMovesOverride: 0))                                 // 0 步局完整性
        records.append(makeRecord(source: .imported, difficulty: nil, moveCount: 60))                   // imported 域
        let summaries = records.map { RecordSummary(from: $0) }

        let fixedDate = Date(timeIntervalSince1970: 1_700_000_123)
        let report = GameRecordStatsAggregator.aggregate(
            summaries: summaries, recordProvider: makeProvider(records),
            generatedAt: fixedDate)

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("t1017-oc01-sample", isDirectory: true)
        let url = try GameRecordStatsAggregator.exportJSON(report: report, directory: dir)
        print("T1017OC01_EXPORT_SAMPLE_PATH=\(url.path)")
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(report.product.countedGameCount == 5)  // 9 局：5 产品域计入（0 步局剔除）+2 校准域+1 imported+1 零步剔除
        #expect(report.calibration.gameCount == 2)
    }
}
