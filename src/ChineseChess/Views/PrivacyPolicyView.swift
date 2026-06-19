import SwiftUI

struct PrivacyPolicyView: View {
    private let l10n = L10n.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(l10n.t("settings.privacyPolicy"))
                    .font(.title.bold())

                Text(l10n.t("privacy.lastUpdated"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider()

                Group {
                    policyRow(icon: "hand.raised.fill", text: l10n.t("privacy.noDataCollection"))
                    policyRow(icon: "internaldrive.fill", text: l10n.t("privacy.localOnly"))
                    policyRow(icon: "network.slash", text: l10n.t("privacy.noNetwork"))
                }
            }
            .padding()
        }
        .navigationTitle(l10n.t("settings.privacyPolicy"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func policyRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.brown)
                .frame(width: 24)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.body)
    }
}
