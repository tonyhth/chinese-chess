import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(String(localized: "settings.privacyPolicy"))
                    .font(.title.bold())

                Text(String(localized: "privacy.lastUpdated"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider()

                Group {
                    policyRow(icon: "hand.raised.fill", text: String(localized: "privacy.noDataCollection"))
                    policyRow(icon: "internaldrive.fill", text: String(localized: "privacy.localOnly"))
                    policyRow(icon: "network.slash", text: String(localized: "privacy.noNetwork"))
                }
            }
            .padding()
        }
        .navigationTitle(String(localized: "settings.privacyPolicy"))
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
