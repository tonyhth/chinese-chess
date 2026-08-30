import Foundation

// MARK: - v6.4 A-Phase2 附录 A1：评估量纲共享常量（宿主上提 Views → Model 层）

/// mate 分数判定阈值——评估域唯一事实源。
/// 消费方（绘制层 EvalChartScale / 六维 SixDimensionScorer / Elo Estimator /
/// 变招展示 lossCp）一律引用此处，禁止硬编码（防双口径漂移）。
/// 迁移自 Views/AnalysisView.swift（v6.3.2 首引入），Pikafish mate 分特征 |s| ≥ 90000。
enum EvalScaleConstants {
    static let mateThreshold = 90_000
}
