import Foundation
import Testing
@testable import ChineseChess

// MARK: - v6.4 C4b 芯批验证（T-0918：P9 真芯接入 + calibrationVersion 钩子接线）
//
// 架构口径（680016c 件1 定案）：P9 真芯接入走 VM 直连——壳持 AnalysisViewModel
// （extension conformance 即 provider），不经独立 adapter（时序解耦裁决，adapter 退位）。
// 本文件覆盖面按定案架构校准：
// 件1 P9 真芯——VM 即 provider 的注入契约（extension conformance / k 域 v1.1 透传 /
//   load 口径含 playerColorOverride；降级=vm 自然空查询，无 stub 兜底对象）；
// 件2 钩子接线——AssessmentStore.previousReport 同校准版本过滤（跨版本趋势隔离）。

@Suite("C4b 芯批：P9 真芯接入（VM 直连 provider 契约）", .serialized)
@MainActor
struct C4bReplayCoreInjectionTests {

    /// 引擎无关的最小棋谱（空着法）：引擎不可用时 analyzeAll 静默退场，
    /// analyses 保持空——provider 语义仍可验证（降级链=自然空查询）。
    private func makeRecord() -> GameRecord {
        GameRecord(
            title: "C4b 芯批测试",
            redPlayer: PlayerInfo(name: "红", isAI: false, difficulty: nil),
            blackPlayer: PlayerInfo(name: "黑", isAI: true, difficulty: nil),
            result: .redWon,
            totalMoves: 0,
            moves: [])
    }

    @Test("VM 即 provider：AnalysisViewModel 经 extension 满足注入契约")
    func vmIsProviderByExtension() {
        let vm = AnalysisViewModel()
        let provider: AnalysisPresentationProvider = vm
        #expect(provider is AnalysisViewModel,
                "壳直持 VM 即持 provider（extension conformance，680016c 件1 口径）")
    }

    @Test("壳接线口径：load(moves/fen/gameMoves/playerColorOverride/recordId)+analyzeAll 不炸")
    func shellWiringWithPlayerColorOverride() async {
        let vm = AnalysisViewModel()
        let rec = makeRecord()
        // ReplayWindowView .task 同款口径（:164-172）：空棋谱铺空数组，
        // analyzeAll guard !moves.isEmpty 直接退场——验证参数链无类型/顺序错位
        vm.load(moves: rec.moves.uciMoves,
                initialFEN: rec.initialFEN ?? FENParser.standardInitial,
                gameMoves: rec.moves,
                playerColorOverride: .red,      // 人执红（p9PlayerColor 推断值之一）
                recordId: rec.id)
        await vm.analyzeAll()
        #expect(vm.moves.isEmpty, "空棋谱 load 后 moves 为空")
        #expect(vm.persistenceRecordId == rec.id, "recordId 已透传（sidecar 持久化通道）")
        #expect(!vm.isAnalyzing, "analyzeAll 空批立即收口，isAnalyzing=false")
    }

    @Test("k 域 v1.1 经 provider 透传：k=0/k>N 返回 []（e0e3b06 规格不变形）")
    func kDomainThroughProvider() {
        let vm = AnalysisViewModel()
        // 测试注入面（DEBUG）：铺设 1 着带变招的分析
        let v = Variation(uci: "b0c2", sanZh: "马八进七", cpAfter: 35, rank: 1)
        let a = MoveAnalysis(playerMove: "h2e2", quality: .doubtful, bestMove: "b0c2",
                             bestEval: 200, playerEval: 80, evalDelta: 120,
                             alternatives: [], isQuickResult: false, variations: [v])
        vm.loadForTest(moves: ["h2e2"], analyses: [a])

        let provider: AnalysisPresentationProvider = vm
        #expect(provider.variations(atPosition: 0) == [], "k=0（首着前）→ []")
        #expect(provider.variations(atPosition: 1).count == 1, "k=1 → 第 1 着变招真数据")
        #expect(provider.variations(atPosition: 99) == [], "k>N（终局后）→ [] 不炸")
        // 三要素经 provider：lossCp = evalDelta（定级同源）
        let r = provider.moveReview(atMove: 0)
        #expect(r?.lossCp == 120, "lossCp 与定级同源（=evalDelta）")
    }

    @Test("降级链=自然空查询：引擎不可用段 vm 查询返回空/nil（无 stub 兜底对象）")
    func degradePathIsNaturalEmptyQuery() {
        let vm = AnalysisViewModel()
        // 引擎不可用（analyzeAll 前置检查同款字段置位）——680016c 裁决：无 stub 兜底，
        // 壳走 pendingPanel（芯未就绪段显式降级形态）
        vm.analysisUnavailableMessage = "engine unavailable"
        let provider: AnalysisPresentationProvider = vm
        #expect(provider.variations(atPosition: 1) == [],
                "未分析段（analyses 空）→ []，壳 pendingPanel 兜底")
        #expect(provider.moveReview(atMove: 0) == nil, "moveReview 未分析 → nil")
    }
}

@Suite("C4b 芯批：calibrationVersion 钩子接线（previousReport 同版本过滤）", .serialized)
struct C4bCalibrationHookTests {

    private func makeDefaults() -> UserDefaults {
        let suiteName = "test.c4b.calib.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    private func makeReport(calibrationVersion: Int?, games: [UUID] = []) -> StrengthReport {
        StrengthReport(
            eloEstimate: EloEstimate(estimate: 1500, lowerBound: 1400, upperBound: 1600, sampleSize: 80, confidence: .high),
            recommendedLevel: .amateurMid,
            calibrationVersion: calibrationVersion,
            dimensions: SixDimensionScores(
                opening: .init(score: 70, label: "良好", detail: "", metrics: [:]),
                tactics: .init(score: 65, label: "一般", detail: "", metrics: [:]),
                endgame: .init(score: 55, label: "一般", detail: "", metrics: [:]),
                consistency: .init(score: 80, label: "良好", detail: "", metrics: [:]),
                checkmate: .init(score: 40, label: "待提升", detail: "", metrics: [:])
            ),
            moveStats: MoveStatistics(totalMoves: 80, qualityDistribution: [.brilliant: 10, .good: 30, .normal: 30, .blunder: 10], avgDelta: 45.0),
            sourceGames: games)
    }

    @Test("同版本序列：previousReport 取同 calibrationVersion 的前一份")
    func sameVersionSeries() {
        let store = AssessmentStore(defaults: makeDefaults())
        let g1 = [UUID()], g2 = [UUID()], g3 = [UUID()]
        // 三份同版本（v1）报告：save 顺序 = 历史 旧→新
        store.save(makeReport(calibrationVersion: 1, games: g1))
        store.save(makeReport(calibrationVersion: 1, games: g2))
        store.save(makeReport(calibrationVersion: 1, games: g3))

        let prev = store.previousReport
        #expect(prev != nil, "同版本两份以上 → 有前一份")
        #expect(prev?.sourceGames == g2, "前一份 = 倒数第二份（g2），非 g1")
        #expect(prev?.calibrationVersion == 1, "前一份与当前同版本")
    }

    @Test("跨版本隔离：旧版本报告不参与趋势（8dd48a7 锚点口径）")
    func crossVersionIsolation() {
        let store = AssessmentStore(defaults: makeDefaults())
        let legacyGame = [UUID()]
        // v1（legacy nil）旧档 → 新 v1（=currentCalibrationVersion）新档
        store.save(makeReport(calibrationVersion: nil, games: legacyGame))
        store.save(makeReport(calibrationVersion: StrengthReport.currentCalibrationVersion, games: [UUID()]))

        let prev = store.previousReport
        #expect(prev == nil,
                "当前报告为 v\(StrengthReport.currentCalibrationVersion)，唯一历史是 legacy(nil)——跨版本不可比，previousReport 应为 nil（趋势不显示）")
    }

    @Test("混合序列：跳过旧版本取最近同版本前一份")
    func mixedSeriesSkipsOldVersions() {
        let store = AssessmentStore(defaults: makeDefaults())
        let v1a = [UUID()], v2a = [UUID()], v2b = [UUID()]
        let cur = StrengthReport.currentCalibrationVersion
        // 时间序：v1 旧档 → v2 → v2（当前=最后一份 v2）
        store.save(makeReport(calibrationVersion: cur == 1 ? 2 : 1, games: v1a))  // 异版本
        store.save(makeReport(calibrationVersion: cur, games: v2a))
        store.save(makeReport(calibrationVersion: cur, games: v2b))

        let prev = store.previousReport
        #expect(prev?.sourceGames == v2a,
                "previousReport 应跳过异版本旧档，取最近同版本前一份（v2a）")
    }

    @Test("isCurrentCalibration 判定面（A3 钩子，C4b 消费侧供给）")
    func isCurrentCalibrationFacet() {
        let store = AssessmentStore(defaults: makeDefaults())
        let cur = StrengthReport.currentCalibrationVersion
        #expect(store.isCurrentCalibration(makeReport(calibrationVersion: cur)),
                "同版本 → true")
        #expect(!store.isCurrentCalibration(makeReport(calibrationVersion: nil)),
                "legacy(nil) → false（恒）")
        #expect(!store.isCurrentCalibration(makeReport(calibrationVersion: cur + 1)),
                "未来版本（异常态）→ false")
    }
}
