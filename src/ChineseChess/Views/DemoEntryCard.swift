import SwiftUI

/// 残局演示入口卡片（放在 ChapterSelectView 章节列表顶部）
struct DemoEntryCard: View {
    let demoCount: Int
    let categoryCount: Int

    private let l10n = L10n.shared

    var body: some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.t("demo.entryTitle"))
                    .font(.headline)
                Text(l10n.t("demo.entrySubtitle"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                if demoCount > 0 {
                    Text(String(format: l10n.t("demo.entryInfo"), demoCount, categoryCount))
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            if demoCount > 0 {
                Image(systemName: "chevron.right.circle")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            } else {
                Text(l10n.t("demo.comingSoon"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.controlBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
