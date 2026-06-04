import Foundation
import AVFoundation

class SoundEngine {
    static let shared = SoundEngine()
    var isMuted: Bool = false

    private var players: [String: AVAudioPlayer] = [:]
    private let queue = DispatchQueue(label: "com.chinesechess.sound")

    private init() {
        // 预加载所有音效
        let soundFiles = [
            ("move", "wav"), ("capture", "wav"),
            ("check", "wav"), ("checkmate", "wav"),
            ("undo", "wav"), ("victory", "wav"), ("defeat", "wav")
        ]
        for (name, ext) in soundFiles {
            if let player = loadSound(name: name, ext: ext) {
                players[name] = player
            } else {
                #if DEBUG
                print("[Sound] missing: \(name).\(ext)")
                #endif
            }
        }
    }

    // MARK: - v1.0 已有

    func playMove() {
        queue.async { [weak self] in
            self?.play("move")
        }
    }

    func playCapture() {
        queue.async { [weak self] in
            self?.play("capture")
        }
    }

    // MARK: - v2.0 新增

    func playCheck() {
        queue.async { [weak self] in
            self?.play("check")
        }
    }

    func playCheckmate() {
        queue.async { [weak self] in
            self?.play("checkmate")
        }
    }

    func playUndo() {
        queue.async { [weak self] in
            self?.play("undo")
        }
    }

    func playVictory() {
        queue.async { [weak self] in
            self?.play("victory")
        }
    }

    func playDefeat() {
        queue.async { [weak self] in
            self?.play("defeat")
        }
    }

    // MARK: - 内部

    private func play(_ name: String) {
        guard !isMuted, let player = players[name] else { return }
        player.currentTime = 0
        player.play()
    }

    private func loadSound(name: String, ext: String) -> AVAudioPlayer? {
        guard let url = ResourceBundle.url(forResource: name, withExtension: ext) else {
            return nil
        }
        return try? AVAudioPlayer(contentsOf: url)
    }
}
