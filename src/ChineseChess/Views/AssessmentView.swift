import SwiftUI

// MARK: - v6.0 Phase 5: 棋力评估 UI

/// 棋力评估主视图
struct AssessmentView: View {
    @State private var session = AssessmentSession()
    @State private var store = AssessmentStore.shared
    @State private var showHistoryPicker = false
    @State private var selectedRecords: [GameRecord] = []
    @Environment(\.dismiss) private var dismiss

    private let l10n = L10n.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 最近报告或评估入口
                    if let report = currentReport {
                        reportCard(report)
                    } else {
                        emptyState
                    }

                    // 评估方式选择
                    if session.state == .idle || session.state == .selectingMode {
                        assessmentModeButtons
                    }

                    // 分析进度
                    if case .analyzing(let progress) = session.state {
                        progressView(progress)
                    }

                    // 失败消息
                    if case .failed(let msg) = session.state {
                        Text(msg)
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle(l10n.t("assessment.title"))
        }
    }

    // MARK: - 当前报告

    private var currentReport: StrengthReport? {
        if case .completed(let report) = session.state {
            return report
        }
        return store.lastReport
    }

    // MARK: - 报告卡片

    @ViewBuilder
    private func reportCard(_ report: StrengthReport) -> some View {
        VStack(spacing: 16) {
            // Elo 数字 + 标注
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(report.eloEstimate.estimate)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("±\(report.eloEstimate.upperBound - report.eloEstimate.estimate)")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text("*估算值")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(l10n.t("assessment.confidence") + "：\(report.eloEstimate.confidence.label)")
                        .font(.subheadline.weight(.medium))
                    Text("\(report.eloEstimate.sampleSize) 步")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 小字说明
            Text("*基于有限样本估算，仅供参考")
                .font(.caption2)
                .foregroundColor(.secondary)

            Divider()

            // 推荐级别
            HStack {
                Text(l10n.t("assessment.recommendedLevel"))
                    .font(.body.weight(.medium))
                Spacer()
                Button(action: {
                    let level = report.recommendedLevel
                    NotificationCenter.default.post(
                        name: .setDifficultyFromAssessment,
                        object: nil,
                        userInfo: ["level": level]
                    )
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Text(report.recommendedLevel.displayName)
                            .font(.body.weight(.semibold))
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
            }

            // 分析样本
            HStack {
                Text(l10n.t("assessment.sampleSize"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(report.moveStats.totalMoves) 步（\(report.sourceGames.count) 局）")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 六维雷达图
            RadarChartView(scores: [
                (l10n.t("assessment.opening"), Double(report.dimensions.opening.score)),
                (l10n.t("assessment.tactics"), Double(report.dimensions.tactics.score)),
                (l10n.t("assessment.endgame"), Double(report.dimensions.endgame.score)),
                (l10n.t("assessment.consistency"), Double(report.dimensions.consistency.score)),
                (l10n.t("assessment.checkmate"), Double(report.dimensions.checkmate.score)),
                (l10n.t("assessment.overall"), Double(report.dimensions.overall)),
            ])
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            // 评分进度条
            VStack(spacing: 6) {
                scoreBar(l10n.t("assessment.opening"), report.dimensions.opening.score, report.dimensions.opening.label)
                scoreBar("中盘战术", report.dimensions.tactics.score, report.dimensions.tactics.label)
                scoreBar(l10n.t("assessment.endgame"), report.dimensions.endgame.score, report.dimensions.endgame.label)
                scoreBar(l10n.t("assessment.consistency"), report.dimensions.consistency.score, report.dimensions.consistency.label)
                scoreBar("杀棋敏感", report.dimensions.checkmate.score, report.dimensions.checkmate.label)
            }

            // 优势/短板
            if !report.strengths.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.t("assessment.strengths"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.green)
                    ForEach(report.strengths, id: \.self) { s in
                        Text("✓ \(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !report.weaknesses.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.t("assessment.weaknesses"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.orange)
                    ForEach(report.weaknesses, id: \.self) { w in
                        Text("△ \(w)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 训练建议
            if !report.trainingSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(l10n.t("assessment.trainingSuggestions"))
                        .font(.subheadline.weight(.semibold))
                    ForEach(report.trainingSuggestions) { s in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.title)
                                .font(.caption.weight(.medium))
                            Text(s.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 重新评估按钮
            Button(l10n.t("assessment.reassess")) {
                session.reset()
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - 评分进度条

    @ViewBuilder
    private func scoreBar(_ label: String, _ score: Int, _ qualityLabel: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 50, alignment: .leading)
            ProgressView(value: Double(score), total: 100)
                .tint(scoreColor(score))
            Text("\(score)")
                .font(.caption.weight(.medium))
                .frame(width: 30, alignment: .trailing)
            Text(qualityLabel)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 85...:        return .green
        case 70..<85:      return .blue
        case 50..<70:      return .orange
        default:           return .red
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(l10n.t("assessment.emptyTitle"))
                .font(.headline)
            Text(l10n.t("assessment.emptyDesc"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    // MARK: - 评估方式按钮

    private var assessmentModeButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                startHistoryAnalysis()
            }) {
                Label(l10n.t("assessment.analyzeHistory"), systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)

            Text(l10n.t("assessment.analyzeHistoryDesc"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 进度

    private func progressView(_ progress: AssessmentProgress) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            Text(progress.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }

    // MARK: - 历史分析

    private func startHistoryAnalysis() {
        let records = GameRecordStore.shared.loadSummaries()
            .filter { $0.source == .versusAI && $0.difficulty != nil }
            .prefix(5)
            .compactMap { GameRecordStore.shared.loadRecord(id: $0.id) }

        guard !records.isEmpty else {
            session.state = .failed(l10n.t("assessment.noRecords"))
            return
        }

        session.reset()
        Task {
            await session.analyzeHistory(records: records)
            let report = session.generateReport()
            store.save(report)
        }
    }
}

// MARK: - 通知名称扩展

extension Notification.Name {
    static let setDifficultyFromAssessment = Notification.Name("setDifficultyFromAssessment")
}
