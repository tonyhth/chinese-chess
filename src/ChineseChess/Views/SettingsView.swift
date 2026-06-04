import SwiftUI

struct SettingsView: View {
    let viewModel: GameViewModel
    @State private var themeManager = ThemeManager.shared
    @State private var soundEngine = SoundEngine.shared
    @AppStorage("chinesechess.notationFormat") private var notationFormat: String = "chinese"

    var body: some View {
        Form {
            // 难度设置
            Section("AI 难度") {
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
            Section("音效") {
                Toggle("音效开关", isOn: Binding(
                    get: { !soundEngine.isMuted },
                    set: { soundEngine.isMuted = !$0 }
                ))
            }

            // 棋谱格式
            Section("棋谱格式") {
                Picker("格式", selection: $notationFormat) {
                    Text("中文传统").tag("chinese")
                    Text("ICCS 坐标").tag("iccs")
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(width: 320, height: 380)
        #endif
    }
}
