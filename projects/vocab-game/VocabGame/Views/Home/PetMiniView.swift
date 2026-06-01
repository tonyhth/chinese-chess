import SwiftUI

/// v1.17: Mini pet view using character mini image
/// NOTE: Currently unused dead code — intended for MainTabView avatar or similar small contexts.
/// Remove if still unreferenced in v1.18.
struct PetMiniView: View {
    let size: CGFloat
    var characterId: String = "egg_yellow"

    @State private var isBouncing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(VGColors.primary.opacity(0.2))
                .frame(width: size, height: size)

            Image("\(characterId)_mini")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.8, height: size * 0.8)
        }
        .offset(y: isBouncing ? -3 : 0)
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isBouncing)
        .onAppear { isBouncing = true }
    }
}
