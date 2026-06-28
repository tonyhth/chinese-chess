import SwiftUI

// MARK: - v3.0 gap fix: 段位特权展示

/// 段位特权信息视图
/// 展示各段位已解锁和即将上线的特权
struct RankPrivilegeView: View {
    let profile: PlayerProfile

    var body: some View {
        List {
            Section(L10n.shared.t("rank.section.current_rank")) {
                RankProgressView(profile: profile)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section(L10n.shared.t("rank.privilege.title")) {
                ForEach(Rank.allCases, id: \.self) { rank in
                    RankPrivilegeRow(
                        rank: rank,
                        isUnlocked: profile.rank >= rank,
                        isCurrent: profile.rank == rank
                    )
                }
            }
        }
        .navigationTitle(L10n.shared.t("rank.privilege.title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private struct RankPrivilegeRow: View {
    let rank: Rank
    let isUnlocked: Bool
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(rank.localizedTitle)
                    .font(.headline)
                    .foregroundColor(isUnlocked ? .primary : .secondary)

                if isCurrent {
                    Text(L10n.shared.t("rank.privilege.current"))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(4)
                }

                Spacer()

                Image(systemName: isUnlocked ? "checkmark.circle.fill" : "lock.fill")
                    .foregroundColor(isUnlocked ? .green : .secondary)
            }

            ForEach(privileges, id: \.self) { priv in
                HStack(spacing: 4) {
                    Image(systemName: isUnlocked ? "circle.fill" : "circle")
                        .font(.caption2)
                        .foregroundColor(isUnlocked ? .green : .secondary)
                    Text(priv)
                        .font(.caption)
                        .foregroundColor(isUnlocked ? .primary : .secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    /// 各段位特权列表
    private var privileges: [String] {
        let l = L10n.shared
        switch rank {
        case .student:
            return [l.t("rank.privilege.student.1"), l.t("rank.privilege.student.2")]
        case .scholar:
            return [l.t("rank.privilege.scholar.1"), l.t("rank.privilege.scholar.2")]
        case .juren:
            return [l.t("rank.privilege.juren.1"), l.t("rank.privilege.juren.2")]
        case .jinshi:
            return [l.t("rank.privilege.jinshi.1"), l.t("rank.privilege.jinshi.2")]
        case .hanlin:
            return [l.t("rank.privilege.hanlin.1"), l.t("rank.privilege.hanlin.2")]
        case .master:
            return [l.t("rank.privilege.master.1"), l.t("rank.privilege.master.2")]
        case .sage:
            return [l.t("rank.privilege.sage.1"), l.t("rank.privilege.sage.2"), l.t("rank.privilege.sage.3")]
        }
    }
}
