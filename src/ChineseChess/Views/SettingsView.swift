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
                    Picker("难度", selection: Binding(
                        get: { viewModel.difficulty },
                        set: { viewModel.setDifficulty($0) }
                    )) {
                        Text("新手").tag(AIDifficulty.beginner)
                        Text("初级").tag(AIDifficulty.easy)
                        Text("中级").tag(AIDifficulty.medium)
                        Text("高级").tag(AIDifficulty.hard)
                        Text("大师").tag(AIDifficulty.master)
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
                    Picker("格式", selection: $notationFormat) {
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
