import SwiftUI

struct ThemePickerView: View {
    @State private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 16) {
            ForEach(BoardTheme.allCases, id: \.self) { theme in
                themeButton(for: theme)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func themeButton(for theme: BoardTheme) -> some View {
        let isSelected = themeManager.currentTheme == theme
        let colors = ThemeColors.forTheme(theme)

        Button(action: {
            themeManager.currentTheme = theme
        }) {
            VStack(spacing: 6) {
                // 预览色块
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: colors.boardBackground,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 40)

                    // 小棋子预览
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: colors.pieceFill,
                                center: .center,
                                startRadius: 0,
                                endRadius: 8
                            )
                        )
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(colors.pieceBorder, lineWidth: 0.5)
                                .frame(width: 14, height: 14)
                        )
                }

                Text(theme.displayName)
                    .font(.footnote)
                    .foregroundColor(isSelected ? .yellow : .gray)
            }
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2)
        )
        .padding(4)
    }
}
