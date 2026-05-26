import SwiftUI

struct PetHouseWrapperView: View {
    @EnvironmentObject var app: AppCoordinator
    @State private var showingShop = false

    var body: some View {
        PetHouseContent(
            viewModel: PetHouseViewModel(petRepo: app.petRepo, progressRepo: app.progressRepo),
            showingShop: $showingShop
        )
        .sheet(isPresented: $showingShop) {
            ShopViewWrapper()
                .environmentObject(app)
        }
    }
}

struct PetHouseContent: View {
    @ObservedObject var viewModel: PetHouseViewModel
    @Binding var showingShop: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: VGSpacing.lg) {
                Spacer()

                PetDisplayView(petState: viewModel.petState)

                VStack(spacing: 8) {
                    Text("Lv.\(viewModel.petState.level)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(VGColors.textPrimary)

                    if let expForNext = viewModel.petState.expForNextLevel {
                        ProgressView(value: viewModel.petState.expProgress)
                            .tint(VGColors.primary)
                            .frame(width: 200)
                        Text("\(viewModel.petState.exp)/\(expForNext) EXP")
                            .font(.caption)
                            .foregroundColor(VGColors.textSecondary)
                    } else {
                        Text("MAX LEVEL!")
                            .font(.headline)
                            .foregroundColor(VGColors.secondary)
                    }
                }

                Text(moodMessage)
                    .font(.subheadline)
                    .foregroundColor(VGColors.textPrimary)
                    .padding(.horizontal, VGSpacing.lg)
                    .padding(.vertical, VGSpacing.sm)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)

                if let accessoryId = viewModel.petState.currentAccessory {
                    HStack(spacing: 4) {
                        Text(accessoryIcon(accessoryId))
                            .font(.caption)
                        Text(accessoryName(accessoryId))
                            .font(.caption)
                            .foregroundColor(VGColors.textSecondary)
                    }
                }

                Button {
                    showingShop = true
                } label: {
                    HStack {
                        Image(systemName: "bag.fill")
                        Text("装饰商店")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, VGSpacing.lg)
                    .padding(.vertical, VGSpacing.sm)
                    .background(VGColors.primary)
                    .cornerRadius(20)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(VGGradients.petHouse.ignoresSafeArea())
            .navigationTitle("蛋仔之家")
        }
        .onAppear { viewModel.load() }
    }

    private var moodMessage: String {
        switch viewModel.petState.mood {
        case .happy: return "今天学了不少呢，继续保持~"
        case .normal: return "还有些单词需要复习哦！"
        case .sad: return "好久没见了，快来学习吧~"
        case .excited: return "太棒了！蛋仔好开心！"
        }
    }

    private func accessoryIcon(_ id: String) -> String {
        if id.contains("hat") { return "🎩" }
        if id.contains("glasses") { return "👓" }
        if id.contains("scarf") { return "🧣" }
        if id.contains("bow") { return "🎀" }
        if id.contains("cape") { return "🦸" }
        return "✨"
    }

    private func accessoryName(_ id: String) -> String {
        ShopViewModel.catalog.first(where: { $0.id == id })?.name ?? id
    }
}
