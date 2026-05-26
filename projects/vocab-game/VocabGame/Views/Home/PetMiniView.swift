import SwiftUI

struct PetMiniView: View {
    let size: CGFloat
    @State private var isBouncing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(VGColors.primary.opacity(0.2))
                .frame(width: size, height: size)

            // Simple egg shape
            Ellipse()
                .fill(VGColors.primary)
                .frame(width: size * 0.6, height: size * 0.7)
                .overlay(
                    VStack(spacing: 2) {
                        // Eyes
                        HStack(spacing: 6) {
                            Circle().fill(.white).frame(width: 5, height: 5)
                            Circle().fill(.white).frame(width: 5, height: 5)
                        }
                        // Mouth
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white)
                            .frame(width: 8, height: 3)
                    }
                )
        }
        .offset(y: isBouncing ? -3 : 0)
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isBouncing)
        .onAppear { isBouncing = true }
    }
}
