import SwiftUI

/// Wrapper that creates ShopViewModel with the correct repos from environment
struct ShopViewWrapper: View {
    @EnvironmentObject var app: AppCoordinator
    @StateObject private var viewModel: ShopViewModel

    init(app: AppCoordinator) {
        _viewModel = StateObject(wrappedValue: ShopViewModel(
            progressRepo: app.progressRepo,
            petRepo: app.petRepo,
            achievementRepo: app.achievementRepo
        ))
    }

    var body: some View {
        ShopContent(viewModel: viewModel)
    }
}

struct ShopContent: View {
    @ObservedObject var viewModel: ShopViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedCategory: ShopCategory = .hat

    // v1.16: live preview state
    @State private var previewAccessory: String? = nil
    @State private var previewScene: String? = nil
    @State private var previewEffect: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                .padding(.top, VGSpacing.sm)

                // v1.16: Live pet preview
                ShopPetPreview(
                    viewModel: viewModel,
                    previewAccessory: previewAccessory,
                    previewScene: previewScene
                )
                .padding(.vertical, VGSpacing.sm)

                // Category tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: VGSpacing.sm) {
                        ForEach(ShopCategory.allCases, id: \.self) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                Text(cat.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(selectedCategory == cat ? .bold : .regular)
                                    .foregroundColor(selectedCategory == cat ? .white : VGColors.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedCategory == cat
                                        ? VGColors.primary
                                        : Color.white
                                    )
                                    .cornerRadius(20)
                                    .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, VGSpacing.md)
                    .padding(.vertical, VGSpacing.sm)
                }

                // Items grid
                ScrollView {
                    let filtered = viewModel.items.filter { $0.category == selectedCategory }
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: VGSpacing.sm),
                        GridItem(.flexible(), spacing: VGSpacing.sm),
                    ], spacing: VGSpacing.sm) {
                        ForEach(filtered) { item in
                            ShopItemCard(
                                item: item,
                                ownedCount: viewModel.ownedCount(for: item),
                                isEquipped: viewModel.isEquipped(item),
                                canAfford: viewModel.canAfford(item),
                                onPurchase: { _ = viewModel.purchase(item) },
                                onEquip: {
                                    viewModel.equip(item)
                                    updatePreview(item: item)
                                },
                                onUnequip: {
                                    viewModel.unequip()
                                    previewAccessory = nil
                                    previewScene = nil
                                },
                                onPreview: { updatePreview(item: item) }
                            )
                        }
                    }
                    .padding(.horizontal, VGSpacing.md)
                }
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

    // MARK: - Preview Helper

    private func updatePreview(item: ShopItem) {
        switch item.category {
        case .character:
            break // Character preview handled by CharacterSelectView
        case .hat, .accessory:
            previewAccessory = item.id
        case .scene:
            previewScene = item.id
        case .effect:
            previewEffect = item.id
        case .food:
            break
        }
    }
}

struct ShopItemCard: View {
    let item: ShopItem
    let ownedCount: Int
    let isEquipped: Bool
    let canAfford: Bool
    let onPurchase: () -> Void
    let onEquip: () -> Void
    let onUnequip: () -> Void
    var onPreview: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                Text(itemIcon)
                    .font(.title2)
            }

            Text(item.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(VGColors.textPrimary)
                .lineLimit(1)

            // Description
            Text(item.description)
                .font(.caption2)
                .foregroundColor(VGColors.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 30)

            // Action button
            if item.category == .food {
                foodButton
            } else if isEquipped {
                Button("卸下") { onUnequip() }
                    .font(.caption2)
                    .foregroundColor(VGColors.error)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else if ownedCount > 0 {
                Button("装备") { onEquip() }
                    .font(.caption2)
                    .foregroundColor(VGColors.success)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                purchaseButton
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
        .onTapGesture {
            onPreview?()
        }
    }

    private var foodButton: some View {
        VStack(spacing: 4) {
            if ownedCount > 0 {
                Text("拥有 ×\(ownedCount)")
                    .font(.caption2)
                    .foregroundColor(VGColors.textSecondary)
            }
            purchaseButton
        }
    }

    private var purchaseButton: some View {
        Button {
            onPurchase()
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "coins")
                    .font(.caption2)
                Text("\(item.price)")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .foregroundColor(canAfford ? .white : Color.gray)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(canAfford ? VGColors.primary : Color.gray.opacity(0.3))
            .cornerRadius(8)
        }
        .disabled(!canAfford)
    }

    private var itemIcon: String {
        if item.id.contains("char_egg_pink") { return "🩷" }
        if item.id.contains("char_egg_blue") { return "💙" }
        if item.id.contains("char_egg_green") { return "💚" }
        if item.id.contains("hat") { return "🎩" }
        if item.id.contains("glasses") { return "👓" }
        if item.id.contains("scarf") { return "🧣" }
        if item.id.contains("bow") { return "🎀" }
        if item.id.contains("cape") { return "🦸" }
        if item.id.contains("food_cookie") { return "🍪" }
        if item.id.contains("food_cake") { return "🎂" }
        if item.id.contains("food_icecream") { return "🍦" }
        if item.id.contains("food_starcandy") { return "⭐" }
        if item.id.contains("scene_garden") { return "🌺" }
        if item.id.contains("scene_beach") { return "🏖️" }
        if item.id.contains("scene_starry") { return "🌙" }
        if item.id.contains("scene_castle") { return "🏰" }
        if item.id.contains("effect_rainbow") { return "🌈" }
        if item.id.contains("effect_hearts") { return "💖" }
        if item.id.contains("effect_stars") { return "✨" }
        return "🎁"
    }

    private var iconColor: Color {
        switch item.category {
        case .character: return VGColors.accent
        case .food: return VGColors.peach
        case .hat: return VGColors.primary
        case .accessory: return VGColors.purple
        case .scene: return VGColors.accent
        case .effect: return VGColors.secondary
        }
    }
}

// MARK: - Shop Pet Preview

struct ShopPetPreview: View {
    @ObservedObject var viewModel: ShopViewModel
    let previewAccessory: String?
    let previewScene: String?

    private var previewPetState: PetState {
        var state = viewModel.currentPetState
        if let acc = previewAccessory {
            state.currentAccessory = acc
        }
        if let scene = previewScene {
            state.currentScene = scene
        }
        return state
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("预览效果")
                .font(.caption2)
                .foregroundColor(VGColors.textSecondary)
            PetDisplayView(petState: previewPetState, size: 80)
        }
        .padding(.horizontal, VGSpacing.md)
        .padding(.vertical, VGSpacing.sm)
        .background(Color.white.opacity(0.6))
        .cornerRadius(16)
    }
}
