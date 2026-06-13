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
                Section(String(localized: "difficulty.label")) {
                    Picker(String(localized: "difficulty.label"), selection: Binding(
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
                Section("棋盘主题") {
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
                Section(String(localized: "settings.sound")) {
                    Toggle(String(localized: "settings.soundToggle"), isOn: Binding(
                        get: { !soundEngine.isMuted },
                        set: { soundEngine.isMuted = !$0 }
                    ))
                }

                // 棋谱格式
                Section(String(localized: "settings.notationFormat")) {
                    Picker(String(localized: "settings.notationFormat"), selection: $notationFormat) {
                        Text(String(localized: "settings.notationChinese")).tag("chinese")
                        Text(String(localized: "settings.notationICCS")).tag("iccs")
                    }
                    .pickerStyle(.segmented)
                }

                // 关于
                Section("关于") {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.brown)
                            Text("隐私政策")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "settings.title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(width: 320)
        #endif
    }
}
