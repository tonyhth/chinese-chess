import Foundation

// MARK: - 资源 Bundle 定位

/// 兼容 SPM 开发环境和打包 .app 的资源加载
enum ResourceBundle {
    
    private static let _spmBundle: Bundle? = {
        let bundleName = "ChineseChess_ChineseChess"
        var candidates: [String] = []
        
        // 1. Bundle.main 旁边（标准位置）
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("\(bundleName).bundle").path)
        // 2. Contents/Resources（.app 结构）
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(bundleName).bundle").path)
        // 3. 可执行文件旁边
        if let exec = Bundle.main.executableURL?.deletingLastPathComponent() {
            candidates.append(exec.appendingPathComponent("\(bundleName).bundle").path)
        }
        // 4. 基于当前工作目录（SPM 测试时 cwd 是项目根目录）
        let cwd = FileManager.default.currentDirectoryPath
        candidates.append("\(cwd)/.build/debug/\(bundleName).bundle")
        candidates.append("\(cwd)/.build/release/\(bundleName).bundle")
        candidates.append("\(cwd)/.build/x86_64-apple-macosx/debug/\(bundleName).bundle")
        candidates.append("\(cwd)/.build/x86_64-apple-macosx/release/\(bundleName).bundle")
        // 5. 相对于可执行文件的 .build 路径（swift test 运行时）
        if let exec = Bundle.main.executableURL?.path {
            // swift-testing-helper 在 /usr/libexec/swift/pm/ 下，项目在 .build 上一级
            // 尝试环境变量 SOURCE_PACKAGES_PATH
            if let srcPath = ProcessInfo.processInfo.environment["SOURCE_PACKAGES_PATH"] {
                candidates.append("\(srcPath)/.build/debug/\(bundleName).bundle")
                candidates.append("\(srcPath)/.build/release/\(bundleName).bundle")
            }
        }
        
        #if DEBUG
        AppLog.resourceBundle.debug("Bundle.main.bundleURL = \(Bundle.main.bundleURL)")
        AppLog.resourceBundle.debug("cwd = \(cwd)")
        AppLog.resourceBundle.debug("Searching \(candidates.count) paths for \(bundleName).bundle")
        #endif
        
        for path in candidates {
            if let bundle = Bundle(path: path) {
                #if DEBUG
                AppLog.resourceBundle.debug("Found: \(path)")
                #endif
                return bundle
            }
        }
        
        #if DEBUG
        AppLog.resourceBundle.error("Not found in any path")
        #endif
        return nil
    }()
    
    static func url(forResource name: String, withExtension ext: String?, subdirectory: String? = nil) -> URL? {
        // 1. SPM bundle（开发/测试环境，优先因为 Bundle.main 可能也有同名文件）
        if let bundle = _spmBundle {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
                return url
            }
            if subdirectory != nil,
               let url = bundle.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        
        // 2. Bundle.main（打包 .app）
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
            return url
        }
        if subdirectory != nil,
           let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }
        
        return nil
    }
}
