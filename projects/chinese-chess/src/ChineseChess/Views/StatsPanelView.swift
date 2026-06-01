import SwiftUI

struct StatsPanelView: View {
    @State private var statsVM = StatsViewModel()

    private let difficulties: [(AIDifficulty, String)] = [
        (.beginner, "新手"),
        (.easy, "初级"),
        (.medium, "中级"),
        (.hard, "高级"),
        (.master, "大师")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("对局统计")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            // 人机统计
            VStack(alignment: .leading, spacing: 6) {
                Text("人机对战")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.orange)

                ForEach(difficulties, id: \.0) { diff, name in
                    let s = statsVM.aiStats(for: diff)
                    HStack {
                        Text(name)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .frame(width: 40, alignment: .leading)

                        Text("\(s.wins)胜 \(s.losses)负 \(s.draws)和")
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

            // 人人对战统计
            VStack(alignment: .leading, spacing: 4) {
                Text("人人对战")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.orange)

                let pvp = statsVM.pvpStats
                HStack {
                    Text("总局数: \(pvp.totalGames)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("和棋: \(pvp.draws)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }

            Divider().background(Color.gray.opacity(0.3))

            // 重置
            HStack {
                Spacer()
                Button("重置统计") {
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
