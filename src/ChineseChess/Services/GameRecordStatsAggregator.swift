import Foundation

// MARK: - T-1017-OC-01 统计机制聚合导出（v3.0 实施批首单）
//
// 规格锚：docs/plans/T-1016-OC-01-q4-review-data-inventory.md §4/§6 + 台账 T-1017-OC-01 行三裁定。
// 统计口径（Luke 裁定，双域规则）：
//   ① 校准域（机对机）超短局 < 阈值从主判据剔除、单列异常计数
//   ② 产品域（真人对局）全部计入含超短局（新手被速杀即触发信号本身）
//   ③ 0 步类物理不可能局触发完整性告警、进 harness 调试队列不计入统计
//   ④ 超短局阈值 <20 为可调参数随首批数据校准
// 零 schema 变更：人类视角归账走 loadRecord 读 PlayerInfo.isAI（versusAI 域；
//   不能假设人执红，GameViewModel:1071 isHumanRed 实证）；
//   时长推导走 moves[] 首尾 timestamp（仅 versusAI 域；imported 域时间戳不可信不采用）。
// 真相源：GameRecordStore 记录域（memo G4：StatsManager 双桶不作触发依据，本聚合器零依赖）。
// 红线：GameRecordStore 只读消费（loadSummaries/loadRecord，零修改）；
//   引擎本体/EngineRouter/枚举零触碰；lvl6 锁表/定稿基线零触碰。

// MARK: - 统计口径配置

/// 可调参数集中面（Luke 裁定：阈值随首批数据校准；M 候产品面）
struct GameRecordStatsConfig: Codable, Equatable {
    /// 校准域超短局阈值：totalMoves < 阈值 → 从主判据剔除、单列异常。缺省 20，随首批数据校准
    var ultraShortMoveThreshold: Int = 20
    /// 新手口径 b：本地（产品域）对局数 ≤M 场。M 候产品面未定 → nil（该切片不计算，导出面显式标注）
    var noviceMaxLocalGames: Int? = nil
    /// Q4 复审触发线初值（v2.2 v1.2 §五.6）：人均对局步数 P50 < 40
    var q4MoveP50TriggerLine: Double = 40
    /// Q4 复审触发线初值：新手胜率 < 80%
    var q4NoviceWinRateTriggerLine: Double = 0.80
}

// MARK: - 完整性告警（harness 调试队列载体）

enum GameRecordStatsAlertReason {
    static let zeroMoves = "zeroMoves"                          // 0 步局：物理不可能，不计入统计（裁定③）
    static let recordFileMissing = "recordFileMissing"          // index 有账、{uuid}.json 不可读（域不可定，挂总面）
    static let moveCountMismatch = "moveCountMismatch"          // totalMoves ≠ moves.count（观测面，仍计入统计）
    static let timestampOrderInvalid = "timestampOrderInvalid"  // 首尾 timestamp 倒序：该局时长剔除
    static let unfinishedResult = "unfinishedResult"            // result=playing 未终局：不计入胜率分母
}

struct GameRecordStatsIntegrityAlert: Codable, Equatable {
    let recordId: UUID
    let reason: String
    let detail: String?
}

// MARK: - 步数统计

struct GameRecordStatsMoveStats: Codable, Equatable {
    let sampleCount: Int
    /// 步数 P50（中位数；偶数样本取中间两值均值）
    let p50: Double?
    let min: Int?
    let max: Int?
    let mean: Double?
    /// 超短局观测计数：产品域=观测面（主判据仍全计，供阈值校准）；校准域=单列异常数
    let ultraShortCount: Int
    let ultraShortThreshold: Int
}

// MARK: - 人类视角归账（versusAI 域，零 schema——loadRecord 读 isAI）

enum GameRecordStatsPlayerComposition: String, Codable {
    case humanRed     // 恰红方人类
    case humanBlack   // 恰黑方人类
    case bothHuman    // 双人类（本地双人；胜率单视角不适用，单列计数）
    case bothAI       // 双 AI → 校准域
}

enum GameRecordStatsHumanOutcome: String, Codable {
    case win, loss, draw
}

struct GameRecordStatsHumanAccount: Codable, Equatable {
    /// 恰一方为人类且已终局的局数（胜率分母）
    let accountedGameCount: Int
    let humanRedCount: Int
    let humanBlackCount: Int
    let win: Int
    let loss: Int
    let draw: Int
    let winRate: Double?
    let excludedBothHumanCount: Int
    let excludedUnfinishedCount: Int
}

// MARK: - 档位切片

struct GameRecordStatsTierSlice: Codable, Equatable {
    /// AIDifficulty.rawValue（lvl1-lvl10）；记录无难度 → unspecified
    let tierKey: String
    let gameCount: Int
    let moveStats: GameRecordStatsMoveStats
    let humanPerspective: GameRecordStatsHumanAccount
}

// MARK: - 时长推导（versusAI 域）

struct GameRecordStatsDurationStats: Codable, Equatable {
    let sampleCount: Int
    let p50Seconds: Double?
    let meanSeconds: Double?
    let minSeconds: Double?
    let maxSeconds: Double?
}

// MARK: - 新手双报

struct GameRecordStatsLocalGameCountReport: Codable, Equatable {
    /// 产品域计入统计的本地总局数
    let localProductGameCount: Int
    let noviceMaxLocalGames: Int?
    /// localProductGameCount ≤ M；M 未定 → nil
    let isNovicePhase: Bool?
    let note: String
}

struct GameRecordStatsNoviceReport: Codable, Equatable {
    /// 口径 a：difficulty == .novice（lvl1）切片；无新手局 → nil
    let byDifficultyNovice: GameRecordStatsTierSlice?
    /// 口径 b：本地对局数 ≤M 场（M 候产品面）
    let byLocalGameCountAtMostM: GameRecordStatsLocalGameCountReport
}

// MARK: - Q4 触发线对照（信息面）

struct GameRecordStatsQ4TriggerCheck: Codable, Equatable {
    let moveP50: Double?
    let moveP50TriggerLine: Double
    let moveP50Triggered: Bool?
    let noviceWinRate: Double?
    let noviceWinRateTriggerLine: Double
    let noviceWinRateTriggered: Bool?
    let note: String
}

// MARK: - 域级报告

struct GameRecordStatsProductReport: Codable, Equatable {
    let domain: String
    /// versusAI 摘要总数（含被完整性剔除者）
    let summaryCount: Int
    let countedGameCount: Int
    let excludedZeroMoveCount: Int
    /// 产品域全计入（含超短局）——主判据（裁定②）
    let moveStats: GameRecordStatsMoveStats
    let humanPerspective: GameRecordStatsHumanAccount
    let difficultySlices: [GameRecordStatsTierSlice]
    let novice: GameRecordStatsNoviceReport
    let duration: GameRecordStatsDurationStats
    let durationInvalidCount: Int
    let q4TriggerCheck: GameRecordStatsQ4TriggerCheck
    let integrityAlerts: [GameRecordStatsIntegrityAlert]
}

struct GameRecordStatsAnomalyGame: Codable, Equatable {
    let recordId: UUID
    let totalMoves: Int
}

struct GameRecordStatsUltraShortAnomalies: Codable, Equatable {
    let threshold: Int
    let count: Int
    let games: [GameRecordStatsAnomalyGame]
}

struct GameRecordStatsCalibrationReport: Codable, Equatable {
    let domain: String
    let gameCount: Int
    let excludedZeroMoveCount: Int
    /// 主判据样本：totalMoves ≥ 阈值（裁定①）
    let primarySample: GameRecordStatsMoveStats
    /// 超短局单列（0 < totalMoves < 阈值）
    let ultraShortAnomalies: GameRecordStatsUltraShortAnomalies
    let integrityAlerts: [GameRecordStatsIntegrityAlert]
}

struct GameRecordStatsSourceCount: Codable, Equatable {
    let source: String
    let count: Int
    let reason: String
}

struct GameRecordStatsOtherSourcesReport: Codable, Equatable {
    let countsBySource: [GameRecordStatsSourceCount]
    let note: String
}

// MARK: - 总报告

struct GameRecordStatsReport: Codable, Equatable {
    let schemaVersion: Int
    let task: String
    let generatedAt: Date
    let config: GameRecordStatsConfig
    let totalSummaryCount: Int
    /// index 有账但记录文件缺失（域不可定，挂总面）
    let loadFailures: [GameRecordStatsIntegrityAlert]
    let product: GameRecordStatsProductReport
    let calibration: GameRecordStatsCalibrationReport
    let otherSources: GameRecordStatsOtherSourcesReport
}

// MARK: - 聚合器（纯函数 + 编排）

enum GameRecordStatsAggregator {

    static let unspecifiedTierKey = "unspecified"
    static let schemaVersion = 1

    // MARK: 纯函数

    /// P50（中位数）：空样本 nil；偶数样本取中间两值均值
    static func percentile50(_ values: [Double]) -> Double? {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return nil }
        let mid = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
    }

    static func moveStats(moveCounts: [Int], ultraShortThreshold: Int) -> GameRecordStatsMoveStats {
        GameRecordStatsMoveStats(
            sampleCount: moveCounts.count,
            p50: percentile50(moveCounts.map(Double.init)),
            min: moveCounts.min(),
            max: moveCounts.max(),
            mean: moveCounts.isEmpty ? nil : Double(moveCounts.reduce(0, +)) / Double(moveCounts.count),
            ultraShortCount: moveCounts.filter { $0 < ultraShortThreshold }.count,
            ultraShortThreshold: ultraShortThreshold
        )
    }

    static func playerComposition(redIsAI: Bool, blackIsAI: Bool) -> GameRecordStatsPlayerComposition {
        switch (redIsAI, blackIsAI) {
        case (false, true): return .humanRed
        case (true, false): return .humanBlack
        case (false, false): return .bothHuman
        case (true, true): return .bothAI
        }
    }

    /// 人类视角胜负归账；result=playing 未终局 → nil（不计入胜率）
    static func humanOutcome(result: GameState, humanIsRed: Bool) -> GameRecordStatsHumanOutcome? {
        switch result {
        case .draw: return .draw
        case .redWon: return humanIsRed ? .win : .loss
        case .blackWon: return humanIsRed ? .loss : .win
        case .playing: return nil
        }
    }

    static func humanAccount(records: [GameRecord]) -> GameRecordStatsHumanAccount {
        var humanRed = 0, humanBlack = 0, win = 0, loss = 0, draw = 0
        var bothHuman = 0, unfinished = 0, accounted = 0
        for record in records {
            let composition = playerComposition(redIsAI: record.redPlayer.isAI, blackIsAI: record.blackPlayer.isAI)
            switch composition {
            case .bothAI:
                continue // 域分类已分走，防御
            case .bothHuman:
                bothHuman += 1
            case .humanRed, .humanBlack:
                let humanIsRed = (composition == .humanRed)
                guard let outcome = humanOutcome(result: record.result, humanIsRed: humanIsRed) else {
                    unfinished += 1
                    continue
                }
                accounted += 1
                if humanIsRed { humanRed += 1 } else { humanBlack += 1 }
                switch outcome {
                case .win: win += 1
                case .loss: loss += 1
                case .draw: draw += 1
                }
            }
        }
        return GameRecordStatsHumanAccount(
            accountedGameCount: accounted,
            humanRedCount: humanRed,
            humanBlackCount: humanBlack,
            win: win, loss: loss, draw: draw,
            winRate: accounted > 0 ? Double(win) / Double(accounted) : nil,
            excludedBothHumanCount: bothHuman,
            excludedUnfinishedCount: unfinished
        )
    }

    /// 时长推导：moves 首尾 timestamp（versusAI 域专用，imported 域不调用——时间戳不可信）。
    /// 返回 nil = 时间戳次序非法（last < first，告警面处理）
    static func deriveDurationSeconds(_ record: GameRecord) -> Double? {
        guard let first = record.moves.first?.timestamp, let last = record.moves.last?.timestamp else { return nil }
        guard last >= first else { return nil }
        return last.timeIntervalSince(first)
    }

    static func durationStats(seconds: [Double]) -> GameRecordStatsDurationStats {
        GameRecordStatsDurationStats(
            sampleCount: seconds.count,
            p50Seconds: percentile50(seconds),
            meanSeconds: seconds.isEmpty ? nil : seconds.reduce(0, +) / Double(seconds.count),
            minSeconds: seconds.min(),
            maxSeconds: seconds.max()
        )
    }

    /// 档位切片（tierKey = AIDifficulty.rawValue lvl1-lvl10；无难度 → unspecified；按档位号升序）
    static func tierSlices(records: [GameRecord], ultraShortThreshold: Int) -> [GameRecordStatsTierSlice] {
        let grouped = Dictionary(grouping: records) { (record: GameRecord) -> String in
            record.difficulty?.rawValue ?? unspecifiedTierKey
        }
        return grouped
            .map { tierKey, records in
                GameRecordStatsTierSlice(
                    tierKey: tierKey,
                    gameCount: records.count,
                    moveStats: moveStats(moveCounts: records.map(\.totalMoves), ultraShortThreshold: ultraShortThreshold),
                    humanPerspective: humanAccount(records: records)
                )
            }
            .sorted { tierOrder($0.tierKey) < tierOrder($1.tierKey) }
    }

    private static func tierOrder(_ tierKey: String) -> Int {
        guard tierKey.hasPrefix("lvl"), let n = Int(tierKey.dropFirst(3)) else { return Int.max }
        return n
    }

    // MARK: 编排（GameRecordStore 只读消费）

    /// 生产入口：store.loadSummaries() 摘要级域过滤 + loadRecord 深读归账/时长
    static func aggregate(
        store: GameRecordStore,
        config: GameRecordStatsConfig = GameRecordStatsConfig(),
        generatedAt: Date = Date(),
        task: String = "T-1017-OC-01"
    ) -> GameRecordStatsReport {
        aggregate(
            summaries: store.loadSummaries(),
            recordProvider: { store.loadRecord(id: $0) },
            config: config,
            generatedAt: generatedAt,
            task: task
        )
    }

    /// 可注入入口（单测用）：recordProvider 闭包替代 store 直依
    static func aggregate(
        summaries: [RecordSummary],
        recordProvider: (UUID) -> GameRecord?,
        config: GameRecordStatsConfig = GameRecordStatsConfig(),
        generatedAt: Date = Date(),
        task: String = "T-1017-OC-01"
    ) -> GameRecordStatsReport {
        let threshold = max(1, config.ultraShortMoveThreshold)

        // ① 摘要级域过滤（memo §2：产品域过滤 = source == .versusAI）
        let versusAISummaries = summaries.filter { $0.source == .versusAI }
        var otherCounts: [String: Int] = [:]
        for summary in summaries where summary.source != .versusAI {
            otherCounts[summary.source.rawValue, default: 0] += 1
        }

        // ② 深读分类：双方 isAI → 校准域；否则产品域（含双人类）
        var loadFailures: [GameRecordStatsIntegrityAlert] = []
        var productRecords: [GameRecord] = []
        var calibrationRecords: [GameRecord] = []
        for summary in versusAISummaries {
            guard let record = recordProvider(summary.id) else {
                loadFailures.append(GameRecordStatsIntegrityAlert(
                    recordId: summary.id,
                    reason: GameRecordStatsAlertReason.recordFileMissing,
                    detail: "index.json 摘要在档但 {uuid}.json 不可读，域不可定，未计入任何统计"
                ))
                continue
            }
            if record.redPlayer.isAI && record.blackPlayer.isAI {
                calibrationRecords.append(record)
            } else {
                productRecords.append(record)
            }
        }

        return GameRecordStatsReport(
            schemaVersion: schemaVersion,
            task: task,
            generatedAt: generatedAt,
            config: config,
            totalSummaryCount: summaries.count,
            loadFailures: loadFailures,
            product: productReport(records: productRecords, summaryCount: versusAISummaries.count, threshold: threshold, config: config),
            calibration: calibrationReport(records: calibrationRecords, threshold: threshold),
            otherSources: otherSourcesReport(counts: otherCounts)
        )
    }

    // MARK: 产品域（裁定②：全部计入含超短局）

    private static func productReport(
        records: [GameRecord],
        summaryCount: Int,
        threshold: Int,
        config: GameRecordStatsConfig
    ) -> GameRecordStatsProductReport {
        var alerts: [GameRecordStatsIntegrityAlert] = []
        var zeroMoveCount = 0
        var counted: [GameRecord] = []
        for record in records {
            if record.totalMoves == 0 || record.moves.isEmpty {
                zeroMoveCount += 1
                alerts.append(GameRecordStatsIntegrityAlert(
                    recordId: record.id,
                    reason: GameRecordStatsAlertReason.zeroMoves,
                    detail: "产品域 0 步局物理不可能（裁定③）：完整性告警，不计入统计"
                ))
                continue
            }
            if record.totalMoves != record.moves.count {
                alerts.append(GameRecordStatsIntegrityAlert(
                    recordId: record.id,
                    reason: GameRecordStatsAlertReason.moveCountMismatch,
                    detail: "totalMoves=\(record.totalMoves) ≠ moves.count=\(record.moves.count)（观测面，仍计入统计）"
                ))
            }
            if record.result == .playing {
                alerts.append(GameRecordStatsIntegrityAlert(
                    recordId: record.id,
                    reason: GameRecordStatsAlertReason.unfinishedResult,
                    detail: "result=playing 未终局即存档：不计入人类视角胜率分母"
                ))
            }
            counted.append(record)
        }

        // 时长推导（versusAI 域可信；imported 域已在域过滤时排除）
        var durationSamples: [Double] = []
        var durationInvalidCount = 0
        for record in counted {
            if let seconds = deriveDurationSeconds(record) {
                durationSamples.append(seconds)
            } else {
                durationInvalidCount += 1
                alerts.append(GameRecordStatsIntegrityAlert(
                    recordId: record.id,
                    reason: GameRecordStatsAlertReason.timestampOrderInvalid,
                    detail: "moves 首尾 timestamp 倒序：该局时长剔除，步数/胜负不受影响"
                ))
            }
        }

        let moveStats = moveStats(moveCounts: counted.map(\.totalMoves), ultraShortThreshold: threshold)
        let slices = tierSlices(records: counted, ultraShortThreshold: threshold)
        let noviceSlice = slices.first { $0.tierKey == AIDifficulty.novice.rawValue }
        let localCount = counted.count
        let isNovicePhase = config.noviceMaxLocalGames.map { localCount <= $0 }
        let noviceNote: String = config.noviceMaxLocalGames == nil
            ? "M 候产品面未定，口径 b 未计算（noviceMaxLocalGames=nil）"
            : "口径 b：本地产品域对局总数 ≤M 即新手期设备"
        let q4 = GameRecordStatsQ4TriggerCheck(
            moveP50: moveStats.p50,
            moveP50TriggerLine: config.q4MoveP50TriggerLine,
            moveP50Triggered: moveStats.p50.map { $0 < config.q4MoveP50TriggerLine },
            noviceWinRate: noviceSlice?.humanPerspective.winRate,
            noviceWinRateTriggerLine: config.q4NoviceWinRateTriggerLine,
            noviceWinRateTriggered: noviceSlice?.humanPerspective.winRate.map { $0 < config.q4NoviceWinRateTriggerLine },
            note: "信息面对照（触发线初值 v2.2 v1.2 §五.6，可调）；本导出零动作，判定与复审决策归产品面"
        )

        return GameRecordStatsProductReport(
            domain: "productVersusAI（真人对局）",
            summaryCount: summaryCount,
            countedGameCount: counted.count,
            excludedZeroMoveCount: zeroMoveCount,
            moveStats: moveStats,
            humanPerspective: humanAccount(records: counted),
            difficultySlices: slices,
            novice: GameRecordStatsNoviceReport(
                byDifficultyNovice: noviceSlice,
                byLocalGameCountAtMostM: GameRecordStatsLocalGameCountReport(
                    localProductGameCount: localCount,
                    noviceMaxLocalGames: config.noviceMaxLocalGames,
                    isNovicePhase: isNovicePhase,
                    note: noviceNote
                )
            ),
            duration: durationStats(seconds: durationSamples),
            durationInvalidCount: durationInvalidCount,
            q4TriggerCheck: q4,
            integrityAlerts: alerts
        )
    }

    // MARK: 校准域（裁定①：超短局剔除主判据、单列异常）

    private static func calibrationReport(records: [GameRecord], threshold: Int) -> GameRecordStatsCalibrationReport {
        var alerts: [GameRecordStatsIntegrityAlert] = []
        var zeroMoveCount = 0
        var primary: [Int] = []
        var anomalies: [GameRecordStatsAnomalyGame] = []
        for record in records {
            if record.totalMoves == 0 || record.moves.isEmpty {
                zeroMoveCount += 1
                alerts.append(GameRecordStatsIntegrityAlert(
                    recordId: record.id,
                    reason: GameRecordStatsAlertReason.zeroMoves,
                    detail: "校准域 0 步局物理不可能（裁定③）：完整性告警，不计入统计"
                ))
                continue
            }
            if record.totalMoves < threshold {
                anomalies.append(GameRecordStatsAnomalyGame(recordId: record.id, totalMoves: record.totalMoves))
            } else {
                primary.append(record.totalMoves)
            }
        }
        return GameRecordStatsCalibrationReport(
            domain: "calibrationMachineVsMachine（机对机）",
            gameCount: records.count,
            excludedZeroMoveCount: zeroMoveCount,
            primarySample: moveStats(moveCounts: primary, ultraShortThreshold: threshold),
            ultraShortAnomalies: GameRecordStatsUltraShortAnomalies(
                threshold: threshold,
                count: anomalies.count,
                games: anomalies
            ),
            integrityAlerts: alerts
        )
    }

    // MARK: 非 versusAI 源（本批不计入，仅计数披露，零静默丢弃）

    private static func otherSourcesReport(counts: [String: Int]) -> GameRecordStatsOtherSourcesReport {
        let reasons: [String: String] = [
            RecordSource.imported.rawValue: "时间戳不可信（PGN 导入非对弈真实产生），且非本批统计域（memo G1）",
            RecordSource.puzzle.rawValue: "残局练习非完整对局",
            RecordSource.freePlay.rawValue: "非 versusAI 源（memo §2 产品域过滤口径）",
        ]
        let list = counts
            .map { GameRecordStatsSourceCount(source: $0.key, count: $0.value, reason: reasons[$0.key] ?? "非 versusAI 源") }
            .sorted { $0.source < $1.source }
        return GameRecordStatsOtherSourcesReport(
            countsBySource: list,
            note: "产品域过滤 = source == .versusAI（T-1016-OC-01 memo §2 裁定口径）；本节仅计数披露，零静默丢弃"
        )
    }

    // MARK: 导出（文件级，无 UI）

    static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// 聚合结果 JSON 写指定目录；返回文件 URL（game-stats-export-<yyyyMMdd-HHmmss>.json，原子写）
    @discardableResult
    static func exportJSON(report: GameRecordStatsReport, directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)
        let url = directory.appendingPathComponent("game-stats-export-\(fileStamp(from: report.generatedAt)).json")
        try data.write(to: url, options: [.atomic])
        return url
    }

    static func fileStamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
