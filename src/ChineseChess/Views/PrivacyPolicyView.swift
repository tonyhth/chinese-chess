import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(String(localized: "privacy.policy"))
                    .font(.title.bold())

                Text(String(localized: "privacy.last.updated"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider()

                Group {
                    policyRow(icon: "hand.raised.fill", text: String(localized: "privacy.no.collection"))
                    policyRow(icon: "internaldrive.fill", text: String(localized: "privacy.only.local"))
                    policyRow(icon: "network.slash", text: String(localized: "privacy.no.network"))
                }
            }
            .padding()
        }
        .navigationTitle(String(localized: "privacy.policy"))
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
