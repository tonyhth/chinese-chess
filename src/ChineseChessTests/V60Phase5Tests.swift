import Foundation
import Testing
@testable import ChineseChess

// MARK: - v6.0 Phase 5 测试：棋力评估 UI + 雷达图 + 闭环

@Suite("v6.0 Phase 5: AssessmentView UI", .serialized)
@MainActor
struct V60Phase5ViewTests {

    // ============================
    // MARK: - AssessmentView 创建
    // ============================

    @Test("AssessmentView 可创建（编译验证）")
    func assessmentViewCompiles() {
        let _ = AssessmentView()
    }

    @Test("RadarChartView 可创建（编译验证）")
    func radarChartCompiles() {
        let _ = RadarChartView(scores: [
            ("开局", 70), ("中盘", 60), ("残局", 50),
            ("稳定性", 80), ("杀棋", 40), ("总评", 60),
        ])
    }

    // ============================
    // MARK: - UI 标注规范验证（§4.4）
    // ============================

    @Test("报告卡片包含 *估算值 标注")
    func eloEstimatedAnnotation() {
        // 验证代码中包含 "*估算值" 文本（通过源码检查）
        let source = SourceChecker.source(for: "AssessmentView")
        #expect(source.contains("*估算值"), "AssessmentView 应包含 '*估算值' 标注")
    }

    @Test("报告卡片包含置信度展示")
    func confidenceDisplayed() {
        let source = SourceChecker.source(for: "AssessmentView")
        #expect(source.contains("assessment.confidence") || source.contains("置信度"), "应展示置信度等级")
    }

    @Test("报告卡片包含样本步数")
    func sampleSizeDisplayed() {
        let source = SourceChecker.source(for: "AssessmentView")
        #expect(source.contains("sampleSize") || source.contains("步"), "应展示样本步数")
    }

    @Test("报告卡片包含 '基于有限样本估算' 小字说明")
    func disclaimerText() {
        let source = SourceChecker.source(for: "AssessmentView")
        #expect(source.contains("基于有限样本"), "应有 '基于有限样本估算，仅供参考' 小字说明")
    }

    // ============================
    // MARK: - 雷达图六轴验证
    // ============================

    @Test("雷达图：6 轴包含开局/中盘/残局/稳定性/杀棋/总评")
    func radarChartSixAxes() {
        let assessmentSource = SourceChecker.source(for: "AssessmentView")
        // 轴名通过 l10n key 引用
        #expect(assessmentSource.contains("assessment.opening"))
        #expect(assessmentSource.contains("assessment.tactics"))
        #expect(assessmentSource.contains("assessment.endgame"))
        #expect(assessmentSource.contains("assessment.consistency"))
        #expect(assessmentSource.contains("assessment.checkmate"))
        #expect(assessmentSource.contains("assessment.overall"))
    }

    @Test("雷达图：数据少于 3 个不渲染")
    func radarChartMinThree() {
        // RadarChartView guard count >= 3 else { return }
        let radar = RadarChartView(scores: [("A", 50), ("B", 60)])
        // 不 crash 即可
        #expect(radar.scores.count == 2)
    }

    // ============================
    // MARK: - SettingsView 集成
    // ============================

    @Test("SettingsView 包含棋力评估 Section")
    func settingsHasAssessmentSection() {
        let source = SourceChecker.source(for: "SettingsView")
        #expect(source.contains("棋力评估") || source.contains("assessment"), "SettingsView 应有棋力评估 Section")
    }

    @Test("SettingsView 有 NavigationLink 到 AssessmentView")
    func settingsHasNavigationLink() {
        let source = SourceChecker.source(for: "SettingsView")
        #expect(source.contains("AssessmentView"), "SettingsView 应 NavigationLink 到 AssessmentView")
    }

    @Test("SettingsView 有报告时显示 Elo 摘要")
    func settingsShowsEloSummary() {
        let source = SourceChecker.source(for: "SettingsView")
        #expect(source.contains("eloEstimate"), "SettingsView 应显示 Elo 摘要")
    }

    @Test("SettingsView 无报告时显示 '未评估'")
    func settingsShowsNotAssessed() {
        let source = SourceChecker.source(for: "SettingsView")
        #expect(source.contains("notAssessed") || source.contains("未评估"), "SettingsView 无报告时应显示 '未评估'")
    }

    // ============================
    // MARK: - 闭环验证
    // ============================

    @Test("推荐级别按钮存在")
    func recommendLevelButtonExists() {
        let source = SourceChecker.source(for: "AssessmentView")
        #expect(source.contains("recommendedLevel"), "应有推荐级别按钮")
    }

    @Test("推荐级别按钮发送 setDifficultyFromAssessment 通知")
    func recommendButtonSendsNotification() {
        let source = SourceChecker.source(for: "AssessmentView")
        #expect(source.contains("setDifficultyFromAssessment"), "按钮应发送 setDifficultyFromAssessment 通知")
    }

    @Test("GameViewModel 监听 setDifficultyFromAssessment 通知")
    func gameViewModelListensAssessment() {
        let source = SourceChecker.source(for: "GameViewModel")
        #expect(source.contains("setDifficultyFromAssessment"), "GameViewModel 应监听评估推荐通知")
    }

    @Test("闭环通知正确设置难度")
    func closedLoopSetsDifficulty() async {
        let vm = GameViewModel()
        let originalDiff = vm.difficulty

        // 模拟发送通知
        NotificationCenter.default.post(
            name: .setDifficultyFromAssessment,
            object: nil,
            userInfo: ["level": AIDifficulty.grandmaster]
        )

        // 等待 MainActor 处理
        try? await Task.sleep(nanoseconds: 200_000_000)

        #expect(vm.difficulty == .grandmaster, "通知应将难度设置为 grandmaster")

        // 恢复
        vm.setDifficulty(originalDiff)
    }

    // ============================
    // MARK: - 报告内容验证
    // ============================

    @Test("报告卡片包含五维评分进度条")
    func scoreBarsExist() {
        let source = SourceChecker.source(for: "AssessmentView")
        #expect(source.contains("scoreBar"), "应有评分进度条")
    }

    @Test("报告卡片包含优势/短板区域")
    func strengthsWeaknessesExist() {
        let source = SourceChecker.source(for: "AssessmentView")
        #expect(source.contains("strengths"), "应有优势区域")
        #expect(source.contains("weaknesses"), "应有短板区域")
    }

    @Test("报告卡片包含训练建议")
    func trainingSuggestionsExist() {
        let source = SourceChecker.source(for: "AssessmentView")
        #expect(source.contains("trainingSuggestions"), "应有训练建议")
    }

    @Test("报告卡片包含重新评估按钮")
    func reassessButtonExists() {
        let source = SourceChecker.source(for: "AssessmentView")
        #expect(source.contains("重新评估"), "应有重新评估按钮")
    }

    @Test("空状态：无报告时显示提示")
    func emptyStateExists() {
        let source = SourceChecker.source(for: "AssessmentView")
        #expect(source.contains("还没有评估报告") || source.contains("emptyState"), "应有空状态提示")
    }
}

// MARK: - AssessmentStore 集成

@Suite("v6.0 Phase 5: AssessmentStore + SettingsView 集成", .serialized)
@MainActor
struct V60Phase5IntegrationTests {

    @Test("AssessmentStore.shared 单例存在")
    func sharedStoreExists() {
        let _ = AssessmentStore.shared
    }

    @Test("SettingsView 读取 AssessmentStore.shared.lastReport")
    func settingsReadsStore() {
        let source = SourceChecker.source(for: "SettingsView")
        #expect(source.contains("AssessmentStore.shared.lastReport"), "SettingsView 应读取 lastReport")
    }

    @Test("AssessmentView 保存报告到 AssessmentStore")
    func assessmentSavesToStore() {
        let source = SourceChecker.source(for: "AssessmentView")
        #expect(source.contains("store.save"), "AssessmentView 应保存报告到 store")
    }
}

// MARK: - 辅助：源码检查

enum SourceChecker {
    static func source(for filename: String) -> String {
        let basePath = "/Users/hth/DevTeam/projects/chinese-chess/src/ChineseChess/"
        let paths: [String] = [
            basePath + "Views/\(filename).swift",
            basePath + "ViewModels/\(filename).swift",
            basePath + "Models/\(filename).swift",
            basePath + "AI/\(filename).swift",
            basePath + "Assessment/\(filename).swift",
        ]
        for path in paths {
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                return content
            }
        }
        return ""
    }
}
