import SwiftUI

struct ThemePickerView: View {
    @State private var themeManager = ThemeManager.shared

    var body: some View {
        let profile = PlayerProfileStore.shared.profile
        let available = Set(themeManager.availableThemes(profile: profile))

        HStack(spacing: 16) {
            ForEach(BoardTheme.allCases, id: \.self) { theme in
                themeButton(for: theme, unlocked: available.contains(theme))
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func themeButton(for theme: BoardTheme, unlocked: Bool) -> some View {
        let isSelected = themeManager.currentTheme == theme
        let colors = ThemeColors.forTheme(theme)

        Button(action: {
            guard unlocked else { return }
            let profile = PlayerProfileStore.shared.profile
            themeManager.switchTheme(theme, profile: profile)
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

                    if unlocked {
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
                    } else {
                        // 锁定图标
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Text(theme.displayName)
                    .font(.footnote)
                    .foregroundColor(unlocked ? (isSelected ? .yellow : .gray) : .gray.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected && unlocked ? Color.yellow : Color.clear, lineWidth: 2)
        )
        .padding(4)
        .opacity(unlocked ? 1.0 : 0.5)
    }
}
