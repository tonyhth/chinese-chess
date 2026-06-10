import Foundation
import AVFoundation

class SoundEngine {
    static let shared = SoundEngine()

    private var _isMuted: Bool = false
    var isMuted: Bool {
        get { queue.sync { _isMuted } }
        set { queue.async { [weak self] in self?._isMuted = newValue } }
    }

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
        guard !_isMuted, let player = players[name] else { return }
        // AVAudioPlayer 不保证线程安全，调度回主线程执行
        DispatchQueue.main.async {
            player.currentTime = 0
            player.play()
        }
    }

    private func loadSound(name: String, ext: String) -> AVAudioPlayer? {
        var url = ResourceBundle.url(forResource: name, withExtension: ext)
        // Fallback: 打包 .app 时音频可能在 Sounds/ 子目录
        if url == nil {
            url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Sounds")
        }
        guard let soundURL = url else { return nil }
        return try? AVAudioPlayer(contentsOf: soundURL)
    }
}
