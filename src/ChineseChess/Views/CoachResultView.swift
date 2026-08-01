import SwiftUI

// MARK: - Phase B3 Step 3: 教练结果视图

/// 开局练习结果卡片
///
/// 展示：
/// - 7 级分类统计
/// - 最需改进
/// - 重新练习/继续对弈/返回
struct CoachResultView: View {
    let session: OpeningCoachSession
    let subcategory: OpeningSubcategory

    var onRepractice: (() -> Void)?
    var onContinueGame: (() -> Void)?
    var onBack: (() -> Void)?

    private let l10n = L10n.shared

    /// 7 级分类统计
    private var qualityDistribution: [(OpeningMoveQuality, Int, Double)] {
        let total = session.moves.count
        guard total > 0 else { return [] }
        return OpeningMoveQuality.allCases.compactMap { quality in
            let count = session.moves.filter { $0.quality == quality }.count
            guard count > 0 else { return nil }
            return (quality, count, Double(count) / Double(total))
        }
    }

    /// 最需改进的步骤
    private var worstMove: CoachedMove? {
        session.moves
            .filter { $0.quality != .book && $0.quality != .brilliant && $0.quality != .good }
            .max(by: { ($0.evalDelta ?? 0) < ($1.evalDelta ?? 0) })
    }

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("🏁 " + l10n.t("coach.result.title"))
                .font(.title2.weight(.bold))

            // 开局名称
            Text(subcategory.name)
                .font(.headline)
                .foregroundColor(.secondary)

            // 汇总
            HStack(spacing: 24) {
                statItem(label: l10n.t("coach.result.totalMoves"), value: "\(session.moves.count)")
                statItem(label: l10n.t("coach.result.accuracy"), value: "\(Int(session.accuracy * 100))%")
            }

            Divider()

            // 7 级分类统计
            VStack(alignment: .leading, spacing: 6) {
                ForEach(qualityDistribution, id: \.0) { quality, count, ratio in
                    qualityRow(quality: quality, count: count, ratio: ratio)
                }
            }

            // 最需改进
            if let worst = worstMove,
               let index = session.moves.firstIndex(where: { $0.move == worst.move }) {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.t("coach.result.worstMove", index + 1))
                            .font(.caption.weight(.semibold))
                        if let bookMove = worst.bookMove {
                            Text(l10n.t("coach.result.recommendFormat", worst.move, bookMove))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            // 操作按钮
            HStack(spacing: 12) {
                Button {
                    onRepractice?()
                } label: {
                    Label(l10n.t("coach.result.repractice"), systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                Button {
                    onContinueGame?()
                } label: {
                    Label(l10n.t("coach.result.continue"), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.green)

                Button {
                    onBack?()
                } label: {
                    Label(l10n.t("coach.result.back"), systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
        .padding(24)
        .frame(minWidth: 360, maxWidth: 480)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 40/255, green: 30/255, blue: 20/255))
        )
        .foregroundColor(.white)
    }

    // MARK: - 统计项

    @ViewBuilder
    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 质量行

    @ViewBuilder
    private func qualityRow(quality: OpeningMoveQuality, count: Int, ratio: Double) -> some View {
        HStack(spacing: 8) {
            Text(quality.emoji)
                .frame(width: 20)

            Text(quality.label)
                .font(.caption)
                .frame(width: 40, alignment: .leading)

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(qualityColor(quality))
                        .frame(width: geo.size.width * ratio)
                }
            }
            .frame(height: 8)

            Text("\(Int(ratio * 100))%")
                .font(.caption2.weight(.semibold))
                .frame(width: 36, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(quality.label): \(count) moves, \(Int(ratio * 100)) percent")
    }

    // MARK: - 辅助

    private func qualityColor(_ quality: OpeningMoveQuality) -> Color {
        switch quality {
        case .book:      return .green
        case .brilliant: return .green
        case .good:      return .blue
        case .normal:    return .gray
        case .doubtful:  return .yellow
        case .blunder:   return .orange
        case .losing:    return .red
        }
    }
}

// MARK: - OpeningMoveQuality emoji 扩展

extension OpeningMoveQuality {
    var emoji: String {
        switch self {
        case .book:      return "✅"
        case .brilliant: return "⭐"
        case .good:      return "👍"
        case .normal:    return "⚪"
        case .doubtful:  return "⚠️"
        case .blunder:   return "❌"
        case .losing:    return "💀"
        }
    }
}
