import SwiftUI

/// v1.17: Character selection screen
struct CharacterSelectView: View {
    @ObservedObject var viewModel: PetHouseViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedCharacterId: String = ""
    @State private var previewCharacterId: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: VGSpacing.md) {
                // Preview area
                ZStack {
                    Circle()
                        .fill(VGColors.primary.opacity(0.1))
                        .frame(width: 180, height: 180)

                    Image("\(previewCharacterId)_idle")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 140, height: 140)
                }
                .padding(.top, VGSpacing.lg)

                Text(EggCharacter.byId(previewCharacterId)?.name ?? "")
                    .font(.headline)
                    .foregroundColor(VGColors.textPrimary)

                // Unlock status
                if !viewModel.ownsCharacter(previewCharacterId) {
                    unlockHint(for: previewCharacterId)
                }

                // Character grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: VGSpacing.md) {
                        ForEach(EggCharacter.catalog) { character in
                            characterCard(character)
                        }
                    }
                    .padding(.horizontal, VGSpacing.md)
                }

                // Confirm button
                if viewModel.ownsCharacter(previewCharacterId) && previewCharacterId != viewModel.petState.currentCharacterId {
                    Button {
                        viewModel.switchCharacter(to: previewCharacterId)
                        dismiss()
                    } label: {
                        Text("使用这个角色")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(VGColors.primary)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, VGSpacing.lg)
                    .padding(.bottom, VGSpacing.md)
                } else if previewCharacterId == viewModel.petState.currentCharacterId {
                    Text("当前使用中")
                        .font(.subheadline)
                        .foregroundColor(VGColors.textSecondary)
                        .padding(.bottom, VGSpacing.md)
                }
            }
            .background(VGColors.background.ignoresSafeArea())
            .navigationTitle("选择角色")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                selectedCharacterId = viewModel.petState.currentCharacterId
                previewCharacterId = viewModel.petState.currentCharacterId
            }
        }
    }

    // MARK: - Character Card

    @ViewBuilder
    private func characterCard(_ character: EggCharacter) -> some View {
        let isOwned = viewModel.ownsCharacter(character.id)
        let isCurrent = character.id == viewModel.petState.currentCharacterId

        Button {
            previewCharacterId = character.id
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            previewCharacterId == character.id
                            ? VGColors.primary.opacity(0.2)
                            : Color.gray.opacity(0.05)
                        )
                        .frame(width: 80, height: 80)

                    Image("\(character.id)_idle")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .opacity(isOwned ? 1.0 : 0.4)

                    if !isOwned {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                    }

                    if isCurrent {
                        Circle()
                            .stroke(VGColors.primary, lineWidth: 3)
                            .frame(width: 80, height: 80)
                    }
                }

                Text(character.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isOwned ? VGColors.textPrimary : VGColors.textSecondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Unlock Hint

    private func unlockHint(for characterId: String) -> some View {
        Group {
            if let character = EggCharacter.byId(characterId), character.unlockType != .free {
                VStack(spacing: 4) {
                    switch character.unlockType {
                    case .coins:
                        HStack(spacing: 4) {
                            Image(systemName: "coins")
                                .foregroundColor(VGColors.secondary)
                            Text("需要 \(character.price) 金币")
                                .font(.caption)
                                .foregroundColor(VGColors.textSecondary)
                        }
                    case .streak7:
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("连续打卡 7 天解锁")
                                .font(.caption)
                                .foregroundColor(VGColors.textSecondary)
                        }
                    case .master50:
                        HStack(spacing: 4) {
                            Image(systemName: "book.fill")
                                .foregroundColor(VGColors.accent)
                            Text("掌握 50 个单词解锁")
                                .font(.caption)
                                .foregroundColor(VGColors.textSecondary)
                        }
                    case .free:
                        EmptyView()
                    }
                }
                .padding(.horizontal, VGSpacing.md)
                .padding(.vertical, VGSpacing.sm)
                .background(Color.white.opacity(0.6))
                .cornerRadius(12)
            }
        }
    }
}
