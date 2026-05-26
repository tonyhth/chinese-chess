import Foundation
import AVFoundation

@MainActor
class AudioService {
    static let shared = AudioService()

    private var cache: [String: AVAudioPlayer] = [:]
    var isEnabled: Bool = true {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "audioEnabled") }
    }
    var isBGMEnabled: Bool = true {
        didSet { UserDefaults.standard.set(isBGMEnabled, forKey: "bgmEnabled") }
    }
    private var bgmPlayer: AVAudioPlayer?

    enum SoundEffect: String, CaseIterable {
        case correct
        case wrong
        case combo
        case levelComplete
        case petTap
        case flip
        case match
        case buttonTap
        case upgrade
    }

    private init() {
        isEnabled = UserDefaults.standard.object(forKey: "audioEnabled") as? Bool ?? true
        isBGMEnabled = UserDefaults.standard.object(forKey: "bgmEnabled") as? Bool ?? true
    }

    func play(_ effect: SoundEffect) {
        guard isEnabled else { return }

        // Use cached player if available
        if let cached = cache[effect.rawValue] {
            cached.currentTime = 0
            cached.play()
            return
        }

        // Try to load from bundle
        if let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") {
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                cache[effect.rawValue] = player
                player.play()
                return
            }
        }

        // Phase 3: Generate system beep as fallback
        playSystemFallback(effect)
    }

    private func playSystemFallback(_ effect: SoundEffect) {
        // Use AudioServices system sounds as lightweight fallback
        switch effect {
        case .correct, .match:
            // Short positive beep
            AudioServicesPlaySystemSound(1057) // Tock
        case .wrong:
            AudioServicesPlaySystemSound(1073) // Basso
        case .combo, .upgrade, .levelComplete:
            AudioServicesPlaySystemSound(1025) // Hero
        case .flip, .buttonTap:
            AudioServicesPlaySystemSound(1104) // Key press
        case .petTap:
            AudioServicesPlaySystemSound(1394) // Tink
        }
    }

    func preload() {
        for effect in SoundEffect.allCases {
            if let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") {
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    player.prepareToPlay()
                    cache[effect.rawValue] = player
                }
            }
        }
    }

    // MARK: - BGM (Background Music Framework)

    func startBGM() {
        guard isBGMEnabled, bgmPlayer == nil else { return }
        guard let url = Bundle.main.url(forResource: "bgm", withExtension: "mp3") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.3
            player.prepareToPlay()
            player.play()
            bgmPlayer = player
        } catch {
            print("[AudioService] BGM load failed: \(error)")
        }
    }

    func stopBGM() {
        bgmPlayer?.stop()
        bgmPlayer = nil
    }

    func toggleBGM() {
        if bgmPlayer?.isPlaying == true {
            stopBGM()
        } else {
            isBGMEnabled = true
            startBGM()
        }
    }
}
