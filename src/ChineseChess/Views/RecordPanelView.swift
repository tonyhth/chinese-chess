import SwiftUI

struct RecordPanelView: View {
    let gameMoves: [GameMove]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "record.panelTitle"))
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)

            if gameMoves.isEmpty {
                Text(String(localized: "record.empty"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
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
                .font(.footnote.monospaced())
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .trailing)

            // 棋谱
            Text(gm.notation)
                .font(.custom(FontRegistry.bestAvailableFontName, size: 13))
                .foregroundColor(gm.piece.side == .red ? .red : .white)

            // 标记
            if gm.isCheckmate {
                Text("#")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.yellow)
            } else if gm.isCheck {
                Text("+")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.yellow)
            }
        }
        .accessibilityLabel(Text(String(localized: "accessibility.stepN", defaultValue: "第\(gm.turnNumber)步 \(gm.notation)")))
    }
}
