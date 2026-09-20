import SwiftUI

/// 来源标识徽章：图标 + 颜色 + 文字
/// 支持 RecordSource 四种来源的统一展示
struct SourceBadgeView: View {
    let source: RecordSource
    var showIcon: Bool = true
    var showLabel: Bool = true

    private let l10n = L10n.shared

    var body: some View {
        HStack(spacing: 4) {
            if showIcon {
                icon
            }
            if showLabel {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(color.opacity(0.8))
            }
        }
    }

    // MARK: - 映射

    private var icon: some View {
        Image(systemName: iconName)
            .foregroundColor(color)
    }

    private var iconName: String {
        switch source {
        // C4b 件4：原 "sword.fill" 非 SF Symbol（运行时 console 噪声 "No symbol named
        // 'sword.fill' found"，Image 静默降级空图标）——改 "person.fill.wave.2.fill"
        //（人对 AI 对抗语义：人形+挥手致意 AI 对手）
        case .versusAI:  return "person.fill.wave.2.fill"
        case .puzzle:    return "puzzlepiece.fill"
        case .imported:  return "arrow.down.doc.fill"
        case .freePlay:  return "person.2.fill"
        }
    }

    private var color: Color {
        switch source {
        case .versusAI:  return .orange
        case .puzzle:    return .purple
        case .imported:  return .blue
        case .freePlay:  return .green
        }
    }

    private var label: String {
        switch source {
        case .versusAI:  return l10n.t("source.versusAI")
        case .puzzle:    return l10n.t("source.puzzle")
        case .imported:  return l10n.t("source.imported")
        case .freePlay:  return l10n.t("source.freePlay")
        }
    }
}
