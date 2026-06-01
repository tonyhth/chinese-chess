import SwiftUI

struct ProfileWrapperView: View {
    @StateObject private var viewModel: ProfileViewModel
    @EnvironmentObject var app: AppCoordinator

    init(progressRepo: ProgressRepository) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(progressRepo: progressRepo))
    }

    var body: some View {
        ProfileContent(viewModel: viewModel, coordinator: app)
            .onAppear { viewModel.load() }
    }
}

struct ProfileContent: View {
    @ObservedObject var viewModel: ProfileViewModel
    let coordinator: AppCoordinator
    @State private var showingMistakeBook = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VGSpacing.lg) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VGSpacing.md) {
                        StatCard(title: "总星数", value: "\(viewModel.totalStars)", icon: "star.fill", color: VGColors.secondary)
                        StatCard(title: "已学单词", value: "\(viewModel.totalWordsLearned)", icon: "book.fill", color: VGColors.success)
                        StatCard(title: "已掌握", value: "\(viewModel.totalWordsMastered)", icon: "checkmark.circle.fill", color: VGColors.primary)
                        StatCard(title: "连续天数", value: "\(viewModel.currentStreak)", icon: "flame.fill", color: Color.orange)
                    }
                    .padding(.horizontal, VGSpacing.md)

                    Button {
                        showingMistakeBook = true
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(VGColors.error)
                            Text("错词本").foregroundColor(VGColors.textPrimary)
                            Spacer()
                            if viewModel.mistakeCount > 0 {
                                Text("\(viewModel.mistakeCount)")
                                    .font(.caption).fontWeight(.bold).foregroundColor(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 2)
                                    .background(VGColors.error).cornerRadius(10)
                            }
                            Image(systemName: "chevron.right").foregroundColor(VGColors.textSecondary)
                        }
                        .padding(VGSpacing.md)
                        .cardStyle()
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, VGSpacing.md)

                    // Sound settings
                    VStack(spacing: VGSpacing.sm) {
                        HStack {
                            Text("音效")
                                .font(.subheadline)
                                .foregroundColor(VGColors.textPrimary)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { AudioService.shared.isEnabled },
                                set: { AudioService.shared.isEnabled = $0 }
                            ))
                            .labelsHidden()
                        }
                        .padding(VGSpacing.md)
                        .cardStyle()

                        HStack {
                            Text("背景音乐")
                                .font(.subheadline)
                                .foregroundColor(VGColors.textPrimary)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { AudioService.shared.isBGMEnabled },
                                set: { AudioService.shared.isBGMEnabled = $0; if $0 { AudioService.shared.startBGM() } else { AudioService.shared.stopBGM() } }
                            ))
                            .labelsHidden()
                        }
                        .padding(VGSpacing.md)
                        .cardStyle()
                    }
                    .padding(.horizontal, VGSpacing.md)

                    HStack {
                        Text("最佳连续: \(viewModel.bestStreak) 天")
                            .font(.subheadline).foregroundColor(VGColors.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, VGSpacing.md)
                }
                .padding(.top, VGSpacing.md)
            }
            .background(VGColors.background.ignoresSafeArea())
            .navigationTitle("我的")
            .sheet(isPresented: $showingMistakeBook) {
                MistakeBookSheet(wordRepo: coordinator.wordRepo, progressRepo: coordinator.progressRepo)
            }
        }
        .onAppear { viewModel.load() }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value).font(.title).fontWeight(.bold).foregroundColor(VGColors.textPrimary)
            Text(title).font(.caption).foregroundColor(VGColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .cardStyle()
    }
}

struct MistakeBookSheet: View {
    let wordRepo: WordRepository
    let progressRepo: ProgressRepository
    @Environment(\.dismiss) var dismiss
    @State private var mistakes: [(word: Word, progress: WordProgress)] = []

    var body: some View {
        NavigationStack {
            Group {
                if mistakes.isEmpty {
                    VStack(spacing: VGSpacing.md) {
                        Image(systemName: "checkmark.circle").font(.system(size: 50)).foregroundColor(VGColors.success)
                        Text("没有错词！太棒了！").font(.headline)
                    }
                } else {
                    List(mistakes, id: \.word.id) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.word.text).font(.headline)
                            Text(item.word.meaning).font(.subheadline).foregroundColor(.secondary)
                            HStack {
                                Text("错\(item.progress.wrongCount)次").font(.caption).foregroundColor(.red)
                                Text("连对\(item.progress.consecutiveCorrect)次").font(.caption).foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("错词本")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear {
            let m = progressRepo.mistakeWords()
            mistakes = m.compactMap { wp in
                guard let w = wordRepo.allWords.first(where: { $0.id == wp.wordId }) else { return nil }
                return (word: w, progress: wp)
            }
        }
    }
}
