import SwiftUI

struct LevelMapWrapperView: View {
    @StateObject private var viewModel: LevelSelectViewModel
    @EnvironmentObject var app: AppCoordinator

    init(progressRepo: ProgressRepository) {
        _viewModel = StateObject(wrappedValue: LevelSelectViewModel(progressRepo: progressRepo))
    }

    var body: some View {
        LevelMapContent(viewModel: viewModel, coordinator: app)
    }
}

struct LevelMapContent: View {
    @ObservedObject var viewModel: LevelSelectViewModel
    let coordinator: AppCoordinator

    /// Background gradient shifts color based on progress
    private var progressGradient: LinearGradient {
        let completionRate = Double(viewModel.completedCount) / Double(max(viewModel.levels.count, 1))
        if completionRate < 0.3 {
            return VGGradients.levelMap
        } else if completionRate < 0.7 {
            return LinearGradient(
                colors: [Color(hex: "E8F5E9"), Color(hex: "C8E6C9")],
                startPoint: .top, endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: "FFF8E1"), Color(hex: "FFECB3")],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VGSpacing.md) {
                    // Header
                    HStack {
                        Text("⭐ \(viewModel.totalStars)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Text("\(viewModel.completedCount)/\(viewModel.levels.count) 关")
                            .font(.subheadline)
                            .foregroundColor(VGColors.textSecondary)
                    }
                    .padding(.horizontal, VGSpacing.md)
                    .padding(.top, VGSpacing.md)

                    // S-shaped path layout with dotted connectors
                    let cols = 5
                    let rows = (viewModel.levels.count + cols - 1) / cols
                    ForEach(0..<rows, id: \.self) { row in
                        VStack(spacing: 0) {
                            // Level row
                            HStack(spacing: VGSpacing.sm) {
                                let rowStart = row * cols
                                let rowEnd = min(rowStart + cols, viewModel.levels.count)
                                let indices = Array(rowStart..<rowEnd)
                                let isReversed = row % 2 == 1
                                let orderedIndices = isReversed ? indices.reversed() : indices

                                ForEach(Array(orderedIndices), id: \.self) { idx in
                                    if idx < viewModel.levels.count {
                                        let item = viewModel.levels[idx]
                                        LevelNodeView(
                                            definition: item.definition,
                                            progress: item.progress,
                                            isUnlocked: item.isUnlocked
                                        ) {
                                            if item.isUnlocked {
                                                coordinator.startGame(levelId: item.definition.id)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, VGSpacing.md)

                            // Dotted star path between rows
                            if row < rows - 1 {
                                dottedConnector(isReversedRow: row % 2 == 0)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding(.bottom, VGSpacing.xl)
            }
            .background(progressGradient.ignoresSafeArea())
            .navigationTitle("关卡选择")
        }
        .onAppear { viewModel.loadLevels() }
    }

    /// Dotted path with star decoration between rows
    private func dottedConnector(isReversedRow: Bool) -> some View {
        HStack {
            if isReversedRow {
                Spacer()
            }
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    Group {
                        if i == 2 {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(VGColors.secondary.opacity(0.5))
                        } else {
                            Circle()
                                .fill(VGColors.primary.opacity(0.3))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, VGSpacing.md)
    }
}
