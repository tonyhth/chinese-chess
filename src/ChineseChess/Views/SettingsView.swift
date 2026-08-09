import SwiftUI

struct SettingsView: View {
    let viewModel: GameViewModel
    @State private var themeManager = ThemeManager.shared
    @State private var soundEngine = SoundEngine.shared
    @AppStorage("chinesechess.notationFormat") private var notationFormat: String = "chinese"
    private let l10n = L10n.shared

    var body: some View {
        Form {
                // 难度设置（v6.0: 10 级分组）
                Section {
                    Picker(l10n.t("difficulty.label"), selection: Binding(
                        get: { viewModel.difficulty },
                        set: { viewModel.setDifficulty($0) }
                    )) {
                        Group {
                            Text(l10n.t("difficulty.lvl1")).tag(AIDifficulty.novice)
                            Text(l10n.t("difficulty.lvl2")).tag(AIDifficulty.beginner)
                            Text(l10n.t("difficulty.lvl3")).tag(AIDifficulty.amateurLow)
                            Text(l10n.t("difficulty.lvl4")).tag(AIDifficulty.amateurMid)
                            Text(l10n.t("difficulty.lvl5")).tag(AIDifficulty.amateurHigh)
                        }
                        Group {
                            Text(l10n.t("difficulty.lvl6")).tag(AIDifficulty.amateurDan)
                            Text(l10n.t("difficulty.lvl7")).tag(AIDifficulty.proApprentice)
                            Text(l10n.t("difficulty.lvl8")).tag(AIDifficulty.proExpert)
                            Text(l10n.t("difficulty.lvl9")).tag(AIDifficulty.proMaster)
                            Text(l10n.t("difficulty.lvl10")).tag(AIDifficulty.grandmaster)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text(l10n.t("difficulty.label"))
                }

                // 棋力评估（v6.0 Phase 5）
                Section {
                    NavigationLink {
                        AssessmentView()
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .foregroundColor(.accentColor)
                            Text(l10n.t("settings.assessment"))
                            Spacer()
                            if let report = AssessmentStore.shared.lastReport {
                                Text("\(report.eloEstimate.estimate) ±\(report.eloEstimate.upperBound - report.eloEstimate.estimate)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(l10n.t("settings.notAssessed"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(l10n.t("settings.assessment"))
                } footer: {
                    Text(l10n.t("settings.assessmentDesc"))
                        .font(.caption2)
                }

                // 主题
                Section(l10n.t("settings.themeSection")) {
                    ForEach(BoardTheme.allCases, id: \.self) { theme in
                        themeRow(for: theme)
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

                // 引擎设置（iOS/macOS 统一，v5.5.9: iOS 不再 disabled）
                Section(l10n.t("settings.engineSection")) {
                    Toggle(l10n.t("engine.usePikafish"), isOn: Binding(
                        get: { EngineConfigStore.shared.useEmbeddedEngine },
                        set: { newValue in
                            EngineConfigStore.shared.useEmbeddedEngine = newValue
                            Task { await EngineRouter.shared.switchEngineIfNeeded() }
                        }
                    ))
                }

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

                // 教程重开（FINAL-008）
                Section(l10n.t("settings.tutorialSection")) {
                    Button {
                        TutorialViewModel.resetTutorial()
                    } label: {
                        HStack {
                            Image(systemName: "graduationcap")
                                .foregroundColor(.brown)
                            Text(l10n.t("settings.restartTutorial"))
                        }
                    }
                }

                // Developer mode (v5.5.9: 始终可见，方便开发验证)
                Section(l10n.t("settings.devMode")) {
                    Toggle(l10n.t("settings.devBypassRank"), isOn: Binding(
                        get: { DeveloperMode.isEnabled },
                        set: { DeveloperMode.isEnabled = $0 }
                    ))
                    Text(l10n.t("settings.devBypassRankDesc"))
                        .font(.caption)
                        .foregroundColor(.secondary)
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

    @ViewBuilder
    private func themeRow(for theme: BoardTheme) -> some View {
        let profile = PlayerProfileStore.shared.profile
        let unlocked = themeManager.isThemeUnlocked(theme, profile: profile)
        let colors = ThemeColors.forTheme(theme)
        HStack {
            // 色块预览
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: colors.boardBackground,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 20, height: 20)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary.opacity(0.3), lineWidth: 0.5))

            Text(theme.displayName)
                .foregroundColor(unlocked ? .primary : .secondary)
            Spacer()
            if !unlocked, let required = theme.requiredRank {
                Text(String(format: l10n.t("settings.themeRequiresRank"), l10n.t("rank.\(required.rawValue)")))
                    .font(.caption2)
                    .foregroundColor(.orange)
            } else if themeManager.currentTheme == theme {
                Image(systemName: "checkmark")
                    .foregroundColor(.brown)
            }
        }
        .contentShape(Rectangle())
        .opacity(unlocked ? 1.0 : 0.6)
        .onTapGesture {
            if unlocked {
                withAnimation { themeManager.currentTheme = theme }
            }
        }
    }
}
