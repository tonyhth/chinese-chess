import Foundation

// MARK: - SPM → xcodegen 兼容 shim
// SPM 自动生成 Bundle.module；xcodegen 不会。
// 在 xcodegen 构建中，测试资源通过 Copy Bundle Resources 打包到 host app，
// 因此 Bundle.main 可以访问所有资源。

#if !SWIFT_PACKAGE
extension Bundle {
    static var module: Bundle {
        Bundle.main
    }
}
#endif
