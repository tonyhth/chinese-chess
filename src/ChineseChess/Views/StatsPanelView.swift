import SwiftUI

struct StatsPanelView: View {
    @State private var statsVM = StatsViewModel()

    private let difficulties: [AIDifficulty] = [.beginner, .easy, .medium, .hard, .master]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "stats.title"))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            // 人机统计
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "stats.ai"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.orange)

                ForEach(difficulties, id: \.self) { diff in
                    let s = statsVM.aiStats(for: diff)
                    HStack {
                        Text(diff.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .frame(width: 40, alignment: .leading)

                        Text(String(localized: "stats.format", defaultValue: "\(s.wins)胜 \(s.losses)负 \(s.draws)和"))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)

                        Spacer()

                        Text(String(format: "%.0f%%", s.winRate * 100))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(s.winRate >= 0.5 ? .green : .red)
                    }
                }
            }

            Divider().background(Color.gray.opacity(0.3))

            // 重置
            HStack {
                Spacer()
                Button(String(localized: "stats.reset")) {
                    statsVM.resetAll()
                }
                .font(.system(size: 12))
                .foregroundColor(.red)
                .buttonStyle(.bordered)
                .tint(.red.opacity(0.3))
            }
        }
        .padding(12)
        .background(Color(red: 40/255, green: 22/255, blue: 14/255))
        .cornerRadius(8)
        .onAppear {
            statsVM.refresh()
        }
    }
}
