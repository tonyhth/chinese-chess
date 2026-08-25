// AboutView.swift — 双平台共用关于页（v6.2：版本+版权+隐私+反馈）

import SwiftUI

/// 关于页：版本（Bundle 真实版本，依赖 Info.plist $(MARKETING_VERSION) 机制）/ 版权 / 隐私政策 / 反馈入口。
/// Settings 关于区 NavigationLink 进入，iOS/macOS 共用。
struct AboutView: View {
    private let l10n = L10n.shared
    /// 反馈邮箱（洪涛 08-25 决策，Luke 排单激活；空串=行隐藏，不放假链接）
    static let feedbackEmail = "tonyhth@163.com"

    /// Bundle 真实版本（CFBundleShortVersionString + build）
    static var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return v == b ? v : "\(v) (\(b))"
    }

    /// 版权：单一来源 NSHumanReadableCopyright（macOS/iOS 双 plist 各自维护，gitignored 物理两份）；缺失时空串隐藏该行（同 feedbackEmail 先例），不显示不可区分的假值
    static var copyright: String {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? ""
    }

    var body: some View {
        List {
            Section {
                row(icon: "tag", label: l10n.t("settings.versionLabel"), value: Self.appVersion)
                if !Self.copyright.isEmpty {
                    row(icon: "c.circle", label: l10n.t("settings.copyright"), value: Self.copyright)
                }
            }

            Section {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Label(l10n.t("settings.privacyPolicy"), systemImage: "hand.raised")
                        .foregroundColor(.primary)
                }
            }

            if !Self.feedbackEmail.isEmpty {
                Section {
                    Link(destination: URL(string: "mailto:\(Self.feedbackEmail)")!) {
                        Label(l10n.t("settings.feedback"), systemImage: "envelope")
                    }
                }
            }
        }
        .navigationTitle(l10n.t("settings.aboutSection"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func row(icon: String, label: String, value: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
