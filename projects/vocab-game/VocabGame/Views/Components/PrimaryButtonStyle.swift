import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [VGColors.primary, Color(hex: "FF8CAE")],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
            .shadow(color: VGColors.primary.opacity(0.3), radius: 8, y: 4)
    }
}
