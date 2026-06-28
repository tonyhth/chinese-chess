import SwiftUI

// MARK: - Q2: 段位升级奖励展示

/// 段位升级弹窗：展示新段位 + 解锁功能 + 主题奖励
struct RankUpView: View {
    let newRank: Rank
    let onDismiss: () -> Void

    private let l10n = L10n.shared

    /// 该段位解锁的功能列表
    private var unlockedFeatures: [UnlockedFeature] {
        UnlockedFeature.allCases.filter { $0.requiredRank == newRank }
    }

    /// 该段位解锁的主题
    private var unlockedThemes: [BoardTheme] {
        BoardTheme.allCases.filter { $0.requiredRank == newRank }
    }

    var body: some View {
        VStack(spacing: 20) {
            // 段位图标 + 标题
            VStack(spacing: 8) {
                Image(systemName: newRank.icon)
                    .font(.system(size: 48))
                    .foregroundColor(.yellow)

                Text(l10n.t("rankup.title"))
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)

                Text(newRank.localizedTitle)
                    .font(.title3)
                    .foregroundColor(.yellow)
            }

            // 解锁功能
            if !unlockedFeatures.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.t("rankup.features"))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)

                    ForEach(unlockedFeatures, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: feature.iconName)
                                .foregroundColor(.green)
                                .frame(width: 20)
                            Text(feature.localizedName)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
            }

            // 解锁主题
            if !unlockedThemes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.t("rankup.themes"))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)

                    ForEach(unlockedThemes, id: \.self) { theme in
                        HStack(spacing: 8) {
                            Image(systemName: theme.icon)
                                .foregroundColor(theme.previewColor)
                                .frame(width: 16)
                            Text(theme.displayName)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
            }

            // 确认按钮
            Button {
                onDismiss()
            } label: {
                Text(l10n.t("rankup.continue"))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .foregroundColor(.black)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 40/255, green: 22/255, blue: 16/255))
        )
    }
}
