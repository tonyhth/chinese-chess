import Foundation
import AVFoundation

class SoundEngine {
    static let shared = SoundEngine()
    var isMuted: Bool = false

    private var movePlayer: AVAudioPlayer?
    private var capturePlayer: AVAudioPlayer?
    private let queue = DispatchQueue(label: "com.chinesechess.sound")

    private init() {
        movePlayer = loadSound(name: "move", ext: "wav")
        capturePlayer = loadSound(name: "capture", ext: "wav")
    }

    func playMove() {
        queue.async { [weak self] in
            guard let self, !self.isMuted else { return }
            self.movePlayer?.currentTime = 0
            self.movePlayer?.play()
        }
    }

    func playCapture() {
        queue.async { [weak self] in
            guard let self, !self.isMuted else { return }
            self.capturePlayer?.currentTime = 0
            self.capturePlayer?.play()
        }
    }

    private func loadSound(name: String, ext: String) -> AVAudioPlayer? {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
            return nil
        }
        return try? AVAudioPlayer(contentsOf: url)
    }
}
