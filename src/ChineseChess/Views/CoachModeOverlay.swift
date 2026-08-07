import SwiftUI

// MARK: - v3.6.0 Phase 3.2: 教练覆盖层 UI

/// 教练提示卡片（覆盖在棋盘上方）
struct CoachModeOverlay: View {
    let explanation: CoachExplanation
    let onDismiss: () -> Void
    let onShowDetail: () -> Void

    private let l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack(spacing: 6) {
                Image(systemName: scenarioIcon)
                    .foregroundColor(scenarioColor)

                Text(explanation.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

            // 详情（简短）
            Text(explanation.detail)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)

            // 按钮行
            HStack(spacing: 12) {
                Button {
                    onShowDetail()
                } label: {
                    Label(l10n.t("coach.button.detail"), systemImage: "info.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(scenarioColor)

                Button {
                    onDismiss()
                } label: {
                    Text(l10n.t("coach.button.gotIt"))
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(scenarioColor.opacity(0.5), lineWidth: 1)
                )
        )
    }

    // MARK: - 样式

    private var scenarioIcon: String {
        switch explanation.scenario {
        case .blunder:         return "exclamationmark.triangle.fill"
        case .missedMate:      return "bolt.fill"
        case .missedCheck:     return "plus.circle.fill"
        case .missedCapture:   return "hand.point.right.fill"
        case .developPiece:    return "arrow.up.forward"
        case .defensiveMove:   return "shield.fill"
        case .centerControl:   return "scope"
        case .generic:         return "lightbulb.fill"
        // 开局
        case .openingInitiative: return "bolt.circle.fill"
        case .openingSolid:      return "checkmark.seal.fill"
        case .openingPoorDev:    return "exclamationmark.triangle"
        case .openingZhongPao:   return "flame"
        // 中局
        case .sacrificeAttack: return "flame.fill"
        case .winMaterial:     return "hand.thumbsup.fill"
        case .controlPoint:    return "target"
        case .tacticCombo:     return "star.circle.fill"
        case .mutualAttack:    return "arrow.left.and.right"
        // 残局
        case .endgameWinning:   return "trophy.fill"
        case .endgameHolding:   return "shield.lefthalf.filled"
        case .kingCoordination: return "crown"
        // 战术
        case .tacticFork:        return "arrow.triangle.branch"
        case .tacticPin:         return "pin.fill"
        case .tacticDoubleCheck: return "bolt.fill"
        case .tacticSkewer:      return "line.diagonal"
        // 转折
        case .advantageEstablished: return "chart.line.uptrend.xyaxis"
        case .suddenChange:         return "tornado"
        }
    }

    private var scenarioColor: Color {
        switch explanation.scenario {
        case .blunder:         return .red
        case .missedMate:      return .purple
        case .missedCheck:     return .blue
        case .missedCapture:   return .orange
        case .developPiece:    return .green
        case .defensiveMove:   return .teal
        case .centerControl:   return .indigo
        case .generic:         return .yellow
        // 开局
        case .openingInitiative: return .blue
        case .openingSolid:      return .green
        case .openingPoorDev:    return .orange
        case .openingZhongPao:   return .purple
        // 中局
        case .sacrificeAttack: return .purple
        case .winMaterial:     return .green
        case .controlPoint:    return .indigo
        case .tacticCombo:     return .blue
        case .mutualAttack:    return .orange
        // 残局
        case .endgameWinning:   return .green
        case .endgameHolding:   return .teal
        case .kingCoordination: return .brown
        // 战术
        case .tacticFork:        return .purple
        case .tacticPin:         return .indigo
        case .tacticDoubleCheck: return .red
        case .tacticSkewer:      return .purple
        // 转折
        case .advantageEstablished: return .blue
        case .suddenChange:         return .orange
        }
    }
}

// MARK: - Phase 3.3: 复盘卡片 UI

/// 对局结束后的复盘统计卡片
struct ReviewCardView: View {
    let card: GameReviewCard
    var onViewDetail: (() -> Void)? = nil
    let onClose: () -> Void

    private let l10n = L10n.shared

    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Text(l10n.t("coach.review.title"))
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

            // 星级评分
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= card.rating ? "star.fill" : "star")
                        .foregroundColor(star <= card.rating ? .yellow : .gray.opacity(0.3))
                        .font(.title3)
                }
            }

            // 质量分布
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.t("coach.review.stats"))
                    .font(.caption.weight(.medium))
                    .foregroundColor(.gray)

                ForEach(MoveQuality.allCases.sorted(by: { $0.rawValue > $1.rawValue }), id: \.self) { quality in
                    let count = card.qualityDistribution[quality] ?? 0
                    if count > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: quality.symbolName)
                                .foregroundColor(qualityColor(quality))
                                .frame(width: 16)
                            Text(L10n.shared.t(quality.l10nKey))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Text("\(count)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }

            // 最大失误
            if let blunder = card.biggestBlunder {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text(String(format: l10n.t("coach.review.biggestBlunder"), blunder.moveIndex + 1, blunder.delta))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // 建议
            Text(card.suggestion)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)

            // 查看详情按钮（仅当提供了回调时显示）
            if let onViewDetail = onViewDetail {
                Button {
                    onClose()
                    onViewDetail()
                } label: {
                    Label(l10n.t("coach.review.viewDetail"), systemImage: "graduationcap.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 40/255, green: 22/255, blue: 16/255))
        )
    }

    private func qualityColor(_ quality: MoveQuality) -> Color {
        switch quality {
        case .brilliant: return .green
        case .good:      return .blue
        case .normal:    return .gray
        case .doubtful:  return .yellow
        case .blunder:   return .orange
        case .losing:    return .red
        }
    }
}
