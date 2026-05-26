import SwiftUI

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VGSpacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.15))
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(VGColors.textPrimary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(VGColors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(VGColors.textSecondary)
            }
            .padding(VGSpacing.md)
            .cardStyle()
        }
        .buttonStyle(PlainButtonStyle())
    }
}
