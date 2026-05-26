import SwiftUI

/// Wrapper that creates ShopViewModel with the correct repos from environment
struct ShopViewWrapper: View {
    @EnvironmentObject var app: AppCoordinator

    var body: some View {
        ShopContent(viewModel: ShopViewModel(
            progressRepo: app.progressRepo,
            petRepo: app.petRepo
        ))
    }
}

struct ShopContent: View {
    @ObservedObject var viewModel: ShopViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VGSpacing.md) {
                    // Coins display
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "coins")
                                .foregroundColor(VGColors.secondary)
                            Text("\(viewModel.coins)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(VGColors.secondary)
                        }
                        .padding(.horizontal, VGSpacing.md)
                        .padding(.vertical, VGSpacing.sm)
                        .background(VGColors.secondary.opacity(0.1))
                        .cornerRadius(20)
                    }
                    .padding(.horizontal, VGSpacing.md)

                    VStack(alignment: .leading, spacing: VGSpacing.sm) {
                        Text("蛋仔装饰")
                            .font(.headline)
                            .foregroundColor(VGColors.textPrimary)
                            .padding(.horizontal, VGSpacing.md)

                        ForEach(viewModel.items) { item in
                            ShopItemRow(
                                item: item,
                                isOwned: viewModel.isOwned(item),
                                isEquipped: viewModel.isEquipped(item),
                                canAfford: viewModel.canAfford(item),
                                onPurchase: { _ = viewModel.purchase(item) },
                                onEquip: { viewModel.equip(item) },
                                onUnequip: { viewModel.unequip() }
                            )
                        }
                    }
                }
                .padding(.top, VGSpacing.md)
            }
            .background(VGColors.background.ignoresSafeArea())
            .navigationTitle("商店")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear { viewModel.load() }
    }
}

struct ShopItemRow: View {
    let item: ShopItem
    let isOwned: Bool
    let isEquipped: Bool
    let canAfford: Bool
    let onPurchase: () -> Void
    let onEquip: () -> Void
    let onUnequip: () -> Void

    var body: some View {
        HStack(spacing: VGSpacing.md) {
            ZStack {
                Circle()
                    .fill(VGColors.primary.opacity(0.15))
                    .frame(width: 50, height: 50)
                Text(itemIcon)
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(VGColors.textPrimary)
                Text(item.description)
                    .font(.caption)
                    .foregroundColor(VGColors.textSecondary)
            }

            Spacer()

            if isEquipped {
                Button("卸下") { onUnequip() }
                    .font(.caption)
                    .foregroundColor(VGColors.error)
                    .buttonStyle(.bordered)
            } else if isOwned {
                Button("装备") { onEquip() }
                    .font(.caption)
                    .foregroundColor(VGColors.success)
                    .buttonStyle(.bordered)
            } else {
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        Image(systemName: "coins")
                            .font(.caption2)
                            .foregroundColor(VGColors.secondary)
                        Text("\(item.price)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(canAfford ? VGColors.textPrimary : VGColors.error)
                    }
                    Button("购买") { onPurchase() }
                        .font(.caption2)
                        .foregroundColor(canAfford ? VGColors.primary : Color.gray)
                        .disabled(!canAfford)
                }
            }
        }
        .padding(VGSpacing.md)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
        .padding(.horizontal, VGSpacing.md)
    }

    private var itemIcon: String {
        if item.id.contains("hat") { return "🎩" }
        if item.id.contains("glasses") { return "👓" }
        if item.id.contains("scarf") { return "🧣" }
        if item.id.contains("bow") { return "🎀" }
        if item.id.contains("cape") { return "🦸" }
        return "✨"
    }
}
