import SwiftUI

struct StatsPanelView: View {
    @State private var statsVM = StatsViewModel()
    @State private var showResetAlert = false

    private let difficulties: [AIDifficulty] = [.novice, .beginner, .amateurLow, .amateurMid, .amateurHigh]

    private let l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n.t("stats.vsAI"))
                .font(.callout.weight(.bold))
                .foregroundColor(.white)

            // 人机统计
            VStack(alignment: .leading, spacing: 6) {
                Text(l10n.t("stats.vsAI"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.orange)

                ForEach(difficulties, id: \.self) { diff in
                    let s = statsVM.aiStats(for: diff)
                    HStack {
                        Text(diff.displayName)
                            .font(.footnote)
                            .foregroundColor(.white)
                            .frame(minWidth: 50, alignment: .leading)

                        Text(String(format: l10n.t("stats.recordFormat"), s.wins, s.losses, s.draws))
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(String(format: "%.0f%%", s.winRate * 100))
                            .font(.footnote.weight(.medium))
                            .foregroundColor(s.winRate >= 0.5 ? .green : .red)
                    }
                }
            }

            Divider().background(Color.gray.opacity(0.3))

            // 重置
            HStack {
                Spacer()
                Button(l10n.t("stats.reset")) {
                    showResetAlert = true
                }
                .font(.footnote)
                .foregroundColor(.red)
                .buttonStyle(.bordered)
                .tint(.red.opacity(0.3))
            }
        }
        .padding(12)
        .background(Color(red: 40/255, green: 22/255, blue: 14/255))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .alert(l10n.t("stats.reset"), isPresented: $showResetAlert) {
            Button(l10n.t("common.cancel"), role: .cancel) {}
            Button(l10n.t("common.clear"), role: .destructive) {
                statsVM.resetAll()
            }
        } message: {
            Text(l10n.t("stats.resetConfirm"))
        }
        .onAppear {
            statsVM.refresh()
        }
    }
}
