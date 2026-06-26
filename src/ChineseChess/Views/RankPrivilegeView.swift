import SwiftUI

// MARK: - v3.0 gap fix: 段位特权展示

/// 段位特权信息视图
/// 展示各段位已解锁和即将上线的特权
struct RankPrivilegeView: View {
    let profile: PlayerProfile

    var body: some View {
        List {
            Section("当前段位") {
                RankProgressView(profile: profile)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("段位特权") {
                ForEach(Rank.allCases, id: \.self) { rank in
                    RankPrivilegeRow(
                        rank: rank,
                        isUnlocked: profile.rank >= rank,
                        isCurrent: profile.rank == rank
                    )
                }
            }
        }
        .navigationTitle("段位特权")
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
                Text(rank.rawValue)
                    .font(.headline)
                    .foregroundColor(isUnlocked ? .primary : .secondary)

                if isCurrent {
                    Text("当前")
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
        switch rank {
        case .student:
            return ["基础对弈", "新手教程"]
        case .scholar:
            return ["翡翠绿主题", "成就系统"]
        case .juren:
            return ["帝王金主题", "中等难度 AI"]
        case .jinshi:
            return ["朱砂红主题", "残局挑战库"]
        case .hanlin:
            return ["AI 教练（即将上线）", "开局树浏览（即将上线）"]
        case .master:
            return ["引擎分析（即将上线）", "大师级 AI 对弈"]
        case .sage:
            return ["专属棋圣徽章", "棋谱导出（即将上线）", "自定义主题（即将上线）"]
        }
    }
}
