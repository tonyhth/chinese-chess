import SwiftUI

// MARK: - 跨平台条件编译辅助
// Phase 2+ 视图适配时使用，目前为预留

#if os(macOS)
typealias PlatformColor = NSColor
#else
typealias PlatformColor = UIColor
#endif
