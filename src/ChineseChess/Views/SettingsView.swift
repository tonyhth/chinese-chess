import SwiftUI

struct SettingsView: View {
    let viewModel: GameViewModel
    @State private var themeManager = ThemeManager.shared
    @State private var soundEngine = SoundEngine.shared
    @AppStorage("chinesechess.notationFormat") private var notationFormat: String = "chinese"
    private let l10n = L10n.shared

    var body: some View {
        Form {
                // 难度设置
                Section(l10n.t("difficulty.label")) {
                    Picker(l10n.t("difficulty.label"), selection: Binding(
                        get: { viewModel.difficulty },
                        set: { viewModel.setDifficulty($0) }
                    )) {
                        Text(l10n.t("difficulty.beginner")).tag(AIDifficulty.beginner)
                        Text(l10n.t("difficulty.easy")).tag(AIDifficulty.easy)
                        Text(l10n.t("difficulty.medium")).tag(AIDifficulty.medium)
                        Text(l10n.t("difficulty.hard")).tag(AIDifficulty.hard)
                        Text(l10n.t("difficulty.master")).tag(AIDifficulty.master)
                    }
                    .pickerStyle(.menu)
                }

                // 主题
                Section(l10n.t("settings.themeSection")) {
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
                Section(l10n.t("settings.sound")) {
                    Toggle(l10n.t("settings.soundToggle"), isOn: Binding(
                        get: { !soundEngine.isMuted },
                        set: { soundEngine.isMuted = !$0 }
                    ))
                }

                // 棋谱格式
                Section(l10n.t("settings.notationFormat")) {
                    Picker(l10n.t("settings.notationFormat"), selection: $notationFormat) {
                        Text(l10n.t("settings.notationChinese")).tag("chinese")
                        Text(l10n.t("settings.notationICCS")).tag("iccs")
                    }
                    .pickerStyle(.menu)
                }

                // 语言（即时切换，无需重启）
                Section(l10n.t("settings.languageSection")) {
                    Picker(l10n.t("settings.language"), selection: Binding(
                        get: { l10n.language as String? },
                        set: { newLanguage in
                            if let lang = newLanguage {
                                l10n.setLanguage(lang)
                            } else {
                                l10n.clearLanguage()
                            }
                        }
                    )) {
                        Text(l10n.t("settings.languageSystem")).tag(nil as String?)
                        Text("中文").tag("zh-Hans" as String?)
                        Text("English").tag("en" as String?)
                    }
                    .pickerStyle(.menu)
                }

                #if os(macOS)
                // 引擎设置（仅 macOS）
                Section(l10n.t("settings.engineSection")) {
                    NavigationLink {
                        EngineSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(.brown)
                            Text(l10n.t("settings.externalEngine"))
                        }
                    }
                }
                #else
                // P1-3: iOS 侧显示外部引擎仅支持 macOS 说明
                Section(l10n.t("settings.engineSection")) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text(l10n.t("engine.iosOnlyHint"))
                            .foregroundColor(.secondary)
                            .font(.callout)
                    }
                }
                #endif

                // 关于
                Section(l10n.t("settings.aboutSection")) {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.brown)
                            Text(l10n.t("settings.privacyPolicy"))
                        }
                    }
                }
            }
        .formStyle(.grouped)
        .navigationTitle(l10n.t("settings.title"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .frame(width: 320)
        #endif
    }
}
