import SwiftUI

// MARK: - 章节选择视图（第一级）

/// 章节卡片列表，展示 7 个残局章节的进度和解锁状态。
/// 点击已解锁章节 → 进入章节内残局列表。
/// 点击锁定章节 → 显示解锁条件。
struct ChapterSelectView: View {
    @StateObject private var store = ChapterStore.shared

    @State private var lockedChapterInfo: PuzzleChapter?

    private var demoPuzzleCount: Int {
        PuzzleStore.shared.demoPuzzles.count
    }
    private var demoCategoryCount: Int {
        PuzzleStore.shared.demoCategories.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 总进度概览
            TotalProgressHeader()

            // 演示入口卡片（ScrollView 外，始终可见）
            if demoPuzzleCount > 0 {
                NavigationLink(value: NavigationRoute.puzzleDemo) {
                    DemoEntryCard(demoCount: demoPuzzleCount, categoryCount: demoCategoryCount)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            } else {
                DemoEntryCard(demoCount: 0, categoryCount: 0)
                    .padding(.horizontal)
            }

            // 章节卡片列表
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(store.chapters) { chapter in
                        if chapter.isUnlocked {
                            NavigationLink(value: NavigationRoute.chapter(chapter)) {
                                ChapterCard(chapter: chapter)
                            }
                            .buttonStyle(.plain)
                        } else {
                            ChapterCard(
                                chapter: chapter,
                                onTap: {
                                    lockedChapterInfo = chapter
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(L10n.shared.t("chapter.select.title"))
        .onAppear {
            #if DEBUG
            let ps = PuzzleStore.shared
            print("[ChapterSelect] chapters=\(store.chapters.count), puzzles=\(ps.puzzles.count), demoPuzzles=\(ps.demoPuzzles.count)")
            #endif
        }
        .navigationDestination(for: NavigationRoute.self) { route in
            switch route {
            case .chapter(let chapter):
                PuzzleSelectView(chapter: chapter)
            case .puzzleDemo:
                PuzzleDemoView()
            case .masterGame:
                MasterGameBrowserView()
            case .openingExplorer:
                OpeningExplorerView()
            }
        }
        .alert(
            L10n.shared.t("chapter.locked.title"),
            isPresented: Binding(
                get: { lockedChapterInfo != nil },
                set: { if !$0 { lockedChapterInfo = nil } }
            )
        ) {
            Button(L10n.shared.t("common.ok"), role: .cancel) { lockedChapterInfo = nil }
        } message: {
            if let info = lockedChapterInfo {
                Text(info.unlockDescription)
            }
        }
    }
}

// MARK: - 总进度

private struct TotalProgressHeader: View {
    var store: ChapterStore { .shared }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.shared.t("chapter.totalProgress"))
                    .font(.headline)
                Text("\(store.totalCompleted) / \(store.totalPuzzles)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
            }
            Spacer()
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: store.totalPuzzles > 0
                          ? CGFloat(store.totalCompleted) / CGFloat(store.totalPuzzles)
                          : 0)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 60, height: 60)
                Text("\(Int((store.totalPuzzles > 0 ? Double(store.totalCompleted) / Double(store.totalPuzzles) : 0) * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - 章节卡片

private struct ChapterCard: View {
    let chapter: PuzzleChapter
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onTap = onTap {
                Button(action: onTap) {
                    cardContent
                }
                .buttonStyle(.plain)
                .disabled(chapter.config.displayNumber > 1 && !chapter.isUnlocked)
            } else {
                cardContent
            }
        }
    }

    private var cardContent: some View {
        HStack(spacing: 16) {
                // 章节编号
                ZStack {
                    Circle()
                        .fill(chapter.isUnlocked ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Text("\(chapter.config.displayNumber)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(chapter.isUnlocked ? .accentColor : .secondary)
                }

                // 章节信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.shared.t(chapter.titleKey))
                        .font(.headline)
                        .foregroundColor(chapter.isUnlocked ? .primary : .secondary)

                    if !chapter.unlockDescription.isEmpty && !chapter.isUnlocked {
                        Text(chapter.unlockDescription)
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text(L10n.shared.t(chapter.subtitleKey))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 进度条
                    HStack(spacing: 8) {
                        ProgressView(value: chapter.progress)
                            .progressViewStyle(.linear)
                        Text("\(chapter.completedCount)/\(chapter.totalCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }

                    if chapter.isComplete {
                        Text(L10n.shared.t("chapter.completed"))
                            .font(.caption2)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    }
                }

                Spacer()

                // 锁/解锁图标
                Image(systemName: chapter.isUnlocked
                      ? (chapter.isComplete ? "checkmark.circle.fill" : "chevron.right.circle")
                      : "lock.fill")
                    .font(.title3)
                    .foregroundColor(chapter.isUnlocked
                                    ? (chapter.isComplete ? .green : .accentColor)
                                    : .secondary)
            }
            .padding()
            .background(Color.controlBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(chapter.isUnlocked ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}
