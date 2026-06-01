import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @State private var previousTab: Int = 0

    private let tabs: [(icon: String, label: String)] = [
        ("house.fill", "首页"),
        ("map.fill", "关卡"),
        ("egg.fill", "蛋仔"),
        ("person.fill", "我的")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                let isSelected = selectedTab == index
                let tab = tabs[index]

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        previousTab = selectedTab
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            // Background pill for selected tab
                            if isSelected {
                                Capsule()
                                    .fill(VGColors.primary.opacity(0.12))
                                    .frame(width: 48, height: 32)
                                    .transition(.opacity.combined(with: .scale))
                            }

                            Image(systemName: tab.icon)
                                .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? VGColors.primary : Color.gray.opacity(0.5))
                                .scaleEffect(isSelected ? 1.15 : 1.0)
                        }
                        .frame(height: 32)

                        Text(tab.label)
                            .font(.system(size: 10, weight: isSelected ? .medium : .regular))
                            .foregroundColor(isSelected ? VGColors.primary : Color.gray.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .overlay(alignment: .top) {
                    Divider()
                }
        )
    }
}
