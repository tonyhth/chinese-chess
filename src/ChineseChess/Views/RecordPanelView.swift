import SwiftUI

struct RecordPanelView: View {
    let gameMoves: [GameMove]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("棋谱记录")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)

            if gameMoves.isEmpty {
                Text("暂无走法")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(gameMoves) { gm in
                                moveRow(gm)
                                    .id(gm.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: gameMoves.count) { _, _ in
                        if let last = gameMoves.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(Color(red: 40/255, green: 22/255, blue: 14/255))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func moveRow(_ gm: GameMove) -> some View {
        HStack(spacing: 4) {
            // 回合号
            Text("\(gm.turnNumber).")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 24, alignment: .trailing)

            // 棋谱
            Text(gm.notation)
                .font(.custom(FontRegistry.bestAvailableFontName, size: 13))
                .foregroundColor(gm.piece.side == .red ? .red : .white)

            // 标记
            if gm.isCheckmate {
                Text("#")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.yellow)
            } else if gm.isCheck {
                Text("+")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.yellow)
            }
        }
    }
}
