import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Registers bundled LXGW WenKai font at runtime.
/// macOS: CTFontManagerRegisterFontsForURL
/// iOS: UIFont registration via CoreText
enum FontRegistry {
    static let fontName = "LXGWWenKai-Regular"

    /// System fallback font when LXGW WenKai is unavailable
    static let fallbackFontName = "STKaiti"  // macOS/iOS built-in KaiTi

    /// Returns the best available font name; falls back to system font if neither custom nor fallback is found
    /// Cached as static let — computed once at first access
    static let bestAvailableFontName: String = {
        #if canImport(AppKit)
        if NSFont(name: fontName, size: 16) != nil { return fontName }
        if NSFont(name: fallbackFontName, size: 16) != nil { return fallbackFontName }
        #elseif canImport(UIKit)
        if UIFont(name: fontName, size: 16) != nil { return fontName }
        if UIFont(name: fallbackFontName, size: 16) != nil { return fallbackFontName }
        #endif
        return "System" // SwiftUI default
    }()

    /// Call once at app launch (App.init).
    static func registerFonts() {
        guard let fontURL = Bundle.main.url(forResource: "LXGWWenKai-Regular", withExtension: "ttf") else {
            // Fallback: try module bundle for SPM
            #if canImport(AppKit)
            if let moduleURL = Bundle(url: Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/"))?.url(forResource: "LXGWWenKai-Regular", withExtension: "ttf") {
                registerFontAt(moduleURL)
                return
            }
            #endif
            print("[FontRegistry] Warning: LXGWWenKai-Regular.ttf not found in bundle")
            return
        }
        registerFontAt(fontURL)
    }

    private static func registerFontAt(_ url: URL) {
        #if os(macOS)
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !success {
            if let err = error?.takeUnretainedValue() {
                // Font already registered is not an error
                let desc = CFErrorCopyDescription(err) as String? ?? "unknown"
                if desc.contains("already registered") {
                    // OK — font was registered in a previous launch
                } else {
                    print("[FontRegistry] Registration failed: \(desc)")
                }
            }
        }
        #elseif os(iOS)
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !success, let err = error?.takeUnretainedValue() {
            let desc = CFErrorCopyDescription(err) as String? ?? "unknown"
            if !desc.contains("already registered") {
                print("[FontRegistry] Registration failed: \(desc)")
            }
        }
        #endif
    }
}
