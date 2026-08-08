import SwiftUI

// MARK: - Phase B3 Step 3: 开局选择视图

/// 开局教练 — 开局选择视图
///
/// macOS: 左侧分类列表 + 右侧开局线路列表
/// iOS: 折叠式列表
struct OpeningCoachSelectView: View {
    @State private var selectedCategory: OpeningCategory? = OpeningCategories.categories.first { !$0.subcategories.isEmpty }
    @State private var selectedSubcategory: OpeningSubcategory?
    @State private var playerSide: Side = .red
    @State private var difficulty: AIDifficulty = .medium
    @State private var showNoCoachToast: Bool = false
    /// 导航到教练对弈视图
    @State private var navigateToGame: Bool = false

    private let practiceStore = OpeningPracticeStore.shared
    private let l10n = L10n.shared

    var body: some View {
        #if os(iOS)
        iOSLayout
        #else
        macOSLayout
        #endif
    }

    // MARK: - macOS Layout
    #if os(macOS)
    private var macOSLayout: some View {
        HSplitView {
            // 左侧分类列表
            List(OpeningCategories.categories, selection: $selectedCategory) { category in
                categoryRow(category)
                    .tag(category)
            }
            .frame(minWidth: 160, idealWidth: 200)
            .listStyle(.sidebar)

            // 右侧线路列表 + 设置
            VStack(spacing: 0) {
                if let category = selectedCategory {
                    subcategoryList(category: category)
                } else {
                    Text(l10n.t("coach.select.title"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundColor(.secondary)
                }

                Divider()

                // 底部设置区
                settingsBar
                    .padding()
            }
        }
        .navigationTitle(l10n.t("coach.select.title"))
        .toast(isPresented: $showNoCoachToast, text: l10n.t("coach.select.noCoach.toast"))
        .navigationDestination(isPresented: $navigateToGame) {
            CoachGameView(
                subcategory: selectedSubcategory ?? OpeningSubcategory(id: "_", name: "", firstMoves: [], gameCount: 0),
                playerSide: playerSide,
                difficulty: difficulty,
                onBack: { navigateToGame = false }
            )
        }
    }
    #endif

    // MARK: - iOS Layout

    private var iOSLayout: some View {
        List {
            ForEach(OpeningCategories.categories) { category in
                Section {
                    if category.subcategories.isEmpty {
                        HStack {
                            Text(category.name)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(l10n.t("coach.select.noCoach"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(category.subcategories) { sub in
                            subcategoryRow(sub)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedSubcategory = sub
                                }
                        }
                    }
                } header: {
                    Text(category.name)
                }
            }

            Section {
                settingsBar
            }
        }
        .navigationTitle(l10n.t("coach.select.title"))
        .toast(isPresented: $showNoCoachToast, text: l10n.t("coach.select.noCoach.toast"))
        .navigationDestination(isPresented: $navigateToGame) {
            CoachGameView(
                subcategory: selectedSubcategory ?? OpeningSubcategory(id: "_", name: "", firstMoves: [], gameCount: 0),
                playerSide: playerSide,
                difficulty: difficulty,
                onBack: { navigateToGame = false }
            )
        }
    }

    // MARK: - 分类行

    @ViewBuilder
    private func categoryRow(_ category: OpeningCategory) -> some View {
        HStack {
            Text(category.name)
            if category.subcategories.isEmpty {
                Spacer()
                Text(l10n.t("coach.select.noCoach"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let record = practiceTotalRecord(for: category), record.totalSessions > 0 {
                Spacer()
                Text("✅\(Int(record.bestAccuracy * 100))%")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }

    // MARK: - 线路列表

    @ViewBuilder
    private func subcategoryList(category: OpeningCategory) -> some View {
        if category.subcategories.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text(l10n.t("coach.select.noCoach"))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(category.subcategories, selection: $selectedSubcategory) { sub in
                subcategoryRow(sub)
                    .tag(sub)
            }
            .listStyle(.inset)
        }
    }

    // MARK: - 线路行

    @ViewBuilder
    private func subcategoryRow(_ sub: OpeningSubcategory) -> some View {
        HStack {
            Text(sub.name)
            Spacer()
            if let record = practiceStore.record(for: sub.id) {
                Text("✅\(Int(record.bestAccuracy * 100))%")
                    .font(.caption)
                    .foregroundColor(.green)
                Text("\(record.totalSessions)次")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("🆕")
                    .font(.caption)
            }
        }
    }

    // MARK: - 设置栏

    private var settingsBar: some View {
        HStack(spacing: 16) {
            // 执红/执黑切换
            Picker(selection: $playerSide) {
                Text(l10n.t("coach.select.playerSide")).tag(Side.red)
                Text(l10n.t("coach.select.playerSideBlack")).tag(Side.black)
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .frame(width: 160)

            // 难度选择
            Picker(l10n.t("coach.select.difficulty"), selection: $difficulty) {
                ForEach(AIDifficulty.allCases, id: \.self) { diff in
                    Text(diff.displayName).tag(diff)
                }
            }

            Spacer()

            // 开始练习按钮
            Button {
                if selectedSubcategory != nil {
                    navigateToGame = true
                } else {
                    showNoCoachToast = true
                }
            } label: {
                Label(l10n.t("coach.select.start"), systemImage: "play.fill")
                    .frame(minWidth: 100)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedSubcategory == nil)
        }
    }

    // MARK: - 辅助

    /// 获取整个分类下的练习汇总
    private func practiceTotalRecord(for category: OpeningCategory) -> OpeningPracticeRecord? {
        var bestRecord: OpeningPracticeRecord?
        for sub in category.subcategories {
            if let rec = practiceStore.record(for: sub.id) {
                if bestRecord == nil {
                    bestRecord = OpeningPracticeRecord(openingId: category.id)
                }
                let currentBest = bestRecord?.bestAccuracy ?? 0
                bestRecord?.totalSessions += rec.totalSessions
                bestRecord?.bestAccuracy = max(currentBest, rec.bestAccuracy)
            }
        }
        return bestRecord
    }
}

// MARK: - Toast 修饰器

extension View {
    func toast(isPresented: Binding<Bool>, text: String) -> some View {
        self.overlay(alignment: .bottom) {
            if isPresented.wrappedValue {
                Text(text)
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            isPresented.wrappedValue = false
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isPresented.wrappedValue)
    }
}
