import SwiftUI

struct SettingsView: View {
    let viewModel: GameViewModel
    @State private var themeManager = ThemeManager.shared
    @State private var soundEngine = SoundEngine.shared
    @AppStorage("chinesechess.notationFormat") private var notationFormat: String = "chinese"

    var body: some View {
        ScrollView {
            Form {
                // 难度设置
                Section(String(localized: "ai.difficulty")) {
                    Picker(String(localized: "ai.difficulty"), selection: Binding(
                        get: { viewModel.difficulty },
                        set: { viewModel.setDifficulty($0) }
                    )) {
                        Text(String(localized: "difficulty.beginner")).tag(AIDifficulty.beginner)
                        Text(String(localized: "difficulty.easy")).tag(AIDifficulty.easy)
                        Text(String(localized: "difficulty.medium")).tag(AIDifficulty.medium)
                        Text(String(localized: "difficulty.hard")).tag(AIDifficulty.hard)
                        Text(String(localized: "difficulty.master")).tag(AIDifficulty.master)
                    }
                    .pickerStyle(.segmented)
                }

                // 主题
                Section(String(localized: "board.theme")) {
                    ForEach(BoardTheme.allCases, id: \.self) { theme in
                        HStack {
                            Image(systemName: theme.icon)
                                .foregroundColor(.brown)
                                .frame(width: 24)
                            Text(theme.displayName)
                            Spacer()
                            if themeManager.currentTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.brown)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation { themeManager.currentTheme = theme }
                        }
                    }
                }

                // 音效
                Section(String(localized: "sound")) {
                    Toggle(String(localized: "sound.toggle"), isOn: Binding(
                        get: { !soundEngine.isMuted },
                        set: { soundEngine.isMuted = !$0 }
                    ))
                }

                // 棋谱格式
                Section(String(localized: "notation.format")) {
                    Picker(String(localized: "notation.format"), selection: $notationFormat) {
                        Text(String(localized: "chinese.notation")).tag("chinese")
                        Text(String(localized: "iccs.notation")).tag("iccs")
                    }
                    .pickerStyle(.segmented)
                }

                // 关于
                Section(String(localized: "about")) {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.brown)
                            Text(String(localized: "privacy.policy"))
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "settings"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(width: 320)
        #endif
    }
}
