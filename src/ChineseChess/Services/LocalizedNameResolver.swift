import Foundation

/// 多语言名称解析器
/// 根据当前语言环境自动选择显示中文名或英文名
enum LocalizedNameResolver {
    /// 当前是否中文环境
    static var isChinese: Bool {
        L10n.shared.language.hasPrefix("zh")
    }

    /// 通用选择逻辑
    /// - 中文环境：优先用中文名（需含中文字符），无则 fallback 英文
    /// - 英文环境：直接用英文名
    static func display(en: String, cn: String?) -> String {
        if isChinese {
            if let cn, !cn.isEmpty, hasChinese(cn) {
                return cn
            }
            return en
        } else {
            return en
        }
    }

    /// 判断字符串是否含中文字符
    private static func hasChinese(_ s: String) -> Bool {
        s.unicodeScalars.contains { $0.value >= 0x4e00 && $0.value <= 0x9fff }
    }
}
