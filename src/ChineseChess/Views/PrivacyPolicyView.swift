import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("隐私政策")
                    .font(.title.bold())

                Text("最后更新日期：2025年6月")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider()

                Group {
                    policyRow(icon: "hand.raised.fill", text: "本应用不收集任何个人数据")
                    policyRow(icon: "internaldrive.fill", text: "所有数据（对局历史、残局进度、统计数据、主题偏好）仅存储在您的设备上")
                    policyRow(icon: "network.slash", text: "我们使用 UserDefaults 进行本地数据存储，不使用任何网络请求或第三方分析工具")
                }
            }
            .padding()
        }
        .navigationTitle("隐私政策")
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
