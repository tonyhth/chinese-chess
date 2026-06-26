import SwiftUI

// MARK: - 跨平台条件编译辅助

#if os(macOS)
import AppKit
typealias PlatformColor = NSColor
#else
import UIKit
typealias PlatformColor = UIColor
#endif

// MARK: - 跨平台语义颜色

extension Color {
    static var controlBackground: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(uiColor: .systemGroupedBackground)
        #endif
    }

    static var windowBackground: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(uiColor: .systemBackground)
        #endif
    }
}
