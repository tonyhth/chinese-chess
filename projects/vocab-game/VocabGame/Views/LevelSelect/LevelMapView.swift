import SwiftUI

struct LevelMapWrapperView: View {
    @EnvironmentObject var app: AppCoordinator

    var body: some View {
        LevelMapContent(viewModel: LevelSelectViewModel(progressRepo: app.progressRepo), coordinator: app)
    }
}

struct LevelMapContent: View {
    @ObservedObject var viewModel: LevelSelectViewModel
    let coordinator: AppCoordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VGSpacing.md) {
                    HStack {
                        Text("⭐ \(viewModel.totalStars)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal, VGSpacing.md)
                    .padding(.top, VGSpacing.md)

                    // S-shaped path layout: 5 rows of 5
                    ForEach(0..<5, id: \.self) { row in
                        HStack(spacing: VGSpacing.md) {
                            let indices = (0..<5).map { row * 5 + $0 }
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

                        // Path connector between rows
                        if row < 4 {
                            HStack {
                                Spacer()
                                if row % 2 == 0 {
                                    // Path curves right
                                    Path { path in
                                        path.move(to: CGPoint(x: 0, y: 0))
                                        path.addQuadCurve(
                                            to: CGPoint(x: 40, y: 20),
                                            control: CGPoint(x: 40, y: 0)
                                        )
                                    }
                                    .stroke(VGColors.primary.opacity(0.3), lineWidth: 2)
                                    .frame(width: 40, height: 20)
                                } else {
                                    // Path curves left
                                    Path { path in
                                        path.move(to: CGPoint(x: 40, y: 0))
                                        path.addQuadCurve(
                                            to: CGPoint(x: 0, y: 20),
                                            control: CGPoint(x: 0, y: 0)
                                        )
                                    }
                                    .stroke(VGColors.primary.opacity(0.3), lineWidth: 2)
                                    .frame(width: 40, height: 20)
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .padding(.bottom, VGSpacing.xl)
            }
            .background(VGGradients.levelMap.ignoresSafeArea())
            .navigationTitle("关卡选择")
        }
        .onAppear { viewModel.loadLevels() }
    }
}
