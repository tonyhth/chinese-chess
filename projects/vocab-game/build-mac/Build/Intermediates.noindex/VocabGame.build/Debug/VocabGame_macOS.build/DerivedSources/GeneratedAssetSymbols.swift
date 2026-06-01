import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "egg_black_excited" asset catalog image resource.
    static let eggBlackExcited = DeveloperToolsSupport.ImageResource(name: "egg_black_excited", bundle: resourceBundle)

    /// The "egg_black_happy" asset catalog image resource.
    static let eggBlackHappy = DeveloperToolsSupport.ImageResource(name: "egg_black_happy", bundle: resourceBundle)

    /// The "egg_black_idle" asset catalog image resource.
    static let eggBlackIdle = DeveloperToolsSupport.ImageResource(name: "egg_black_idle", bundle: resourceBundle)

    /// The "egg_black_mini" asset catalog image resource.
    static let eggBlackMini = DeveloperToolsSupport.ImageResource(name: "egg_black_mini", bundle: resourceBundle)

    /// The "egg_black_sad" asset catalog image resource.
    static let eggBlackSad = DeveloperToolsSupport.ImageResource(name: "egg_black_sad", bundle: resourceBundle)

    /// The "egg_blue_excited" asset catalog image resource.
    static let eggBlueExcited = DeveloperToolsSupport.ImageResource(name: "egg_blue_excited", bundle: resourceBundle)

    /// The "egg_blue_happy" asset catalog image resource.
    static let eggBlueHappy = DeveloperToolsSupport.ImageResource(name: "egg_blue_happy", bundle: resourceBundle)

    /// The "egg_blue_idle" asset catalog image resource.
    static let eggBlueIdle = DeveloperToolsSupport.ImageResource(name: "egg_blue_idle", bundle: resourceBundle)

    /// The "egg_blue_mini" asset catalog image resource.
    static let eggBlueMini = DeveloperToolsSupport.ImageResource(name: "egg_blue_mini", bundle: resourceBundle)

    /// The "egg_blue_sad" asset catalog image resource.
    static let eggBlueSad = DeveloperToolsSupport.ImageResource(name: "egg_blue_sad", bundle: resourceBundle)

    /// The "egg_green_excited" asset catalog image resource.
    static let eggGreenExcited = DeveloperToolsSupport.ImageResource(name: "egg_green_excited", bundle: resourceBundle)

    /// The "egg_green_happy" asset catalog image resource.
    static let eggGreenHappy = DeveloperToolsSupport.ImageResource(name: "egg_green_happy", bundle: resourceBundle)

    /// The "egg_green_idle" asset catalog image resource.
    static let eggGreenIdle = DeveloperToolsSupport.ImageResource(name: "egg_green_idle", bundle: resourceBundle)

    /// The "egg_green_mini" asset catalog image resource.
    static let eggGreenMini = DeveloperToolsSupport.ImageResource(name: "egg_green_mini", bundle: resourceBundle)

    /// The "egg_green_sad" asset catalog image resource.
    static let eggGreenSad = DeveloperToolsSupport.ImageResource(name: "egg_green_sad", bundle: resourceBundle)

    /// The "egg_pink_excited" asset catalog image resource.
    static let eggPinkExcited = DeveloperToolsSupport.ImageResource(name: "egg_pink_excited", bundle: resourceBundle)

    /// The "egg_pink_happy" asset catalog image resource.
    static let eggPinkHappy = DeveloperToolsSupport.ImageResource(name: "egg_pink_happy", bundle: resourceBundle)

    /// The "egg_pink_idle" asset catalog image resource.
    static let eggPinkIdle = DeveloperToolsSupport.ImageResource(name: "egg_pink_idle", bundle: resourceBundle)

    /// The "egg_pink_mini" asset catalog image resource.
    static let eggPinkMini = DeveloperToolsSupport.ImageResource(name: "egg_pink_mini", bundle: resourceBundle)

    /// The "egg_pink_sad" asset catalog image resource.
    static let eggPinkSad = DeveloperToolsSupport.ImageResource(name: "egg_pink_sad", bundle: resourceBundle)

    /// The "egg_red_excited" asset catalog image resource.
    static let eggRedExcited = DeveloperToolsSupport.ImageResource(name: "egg_red_excited", bundle: resourceBundle)

    /// The "egg_red_happy" asset catalog image resource.
    static let eggRedHappy = DeveloperToolsSupport.ImageResource(name: "egg_red_happy", bundle: resourceBundle)

    /// The "egg_red_idle" asset catalog image resource.
    static let eggRedIdle = DeveloperToolsSupport.ImageResource(name: "egg_red_idle", bundle: resourceBundle)

    /// The "egg_red_mini" asset catalog image resource.
    static let eggRedMini = DeveloperToolsSupport.ImageResource(name: "egg_red_mini", bundle: resourceBundle)

    /// The "egg_red_sad" asset catalog image resource.
    static let eggRedSad = DeveloperToolsSupport.ImageResource(name: "egg_red_sad", bundle: resourceBundle)

    /// The "egg_yellow_excited" asset catalog image resource.
    static let eggYellowExcited = DeveloperToolsSupport.ImageResource(name: "egg_yellow_excited", bundle: resourceBundle)

    /// The "egg_yellow_happy" asset catalog image resource.
    static let eggYellowHappy = DeveloperToolsSupport.ImageResource(name: "egg_yellow_happy", bundle: resourceBundle)

    /// The "egg_yellow_idle" asset catalog image resource.
    static let eggYellowIdle = DeveloperToolsSupport.ImageResource(name: "egg_yellow_idle", bundle: resourceBundle)

    /// The "egg_yellow_mini" asset catalog image resource.
    static let eggYellowMini = DeveloperToolsSupport.ImageResource(name: "egg_yellow_mini", bundle: resourceBundle)

    /// The "egg_yellow_sad" asset catalog image resource.
    static let eggYellowSad = DeveloperToolsSupport.ImageResource(name: "egg_yellow_sad", bundle: resourceBundle)

}

