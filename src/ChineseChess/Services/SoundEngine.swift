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
    #if os(iOS)
    private var isAudioSessionActive = false
    #endif

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
                AppLog.soundEngine.warning("missing: \(name).\(ext)")
                #endif
            }
        }

        // iOS: 监听音频打断通知
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        #endif
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

    // MARK: - AVAudioSession 管理（仅 iOS）

    /// 激活音频会话（游戏开始/音效播放前调用）
    func activateAudioSession() {
        #if os(iOS)
        guard !isAudioSessionActive else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            isAudioSessionActive = true
        } catch {
            #if DEBUG
            AppLog.soundEngine.warning("AVAudioSession activate failed: \(error)")
            #endif
        }
        #endif
    }

    /// 停用音频会话（游戏结束/进入后台时调用）
    func deactivateAudioSession() {
        #if os(iOS)
        guard isAudioSessionActive else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            isAudioSessionActive = false
        } catch {
            #if DEBUG
            AppLog.soundEngine.warning("AVAudioSession deactivate failed: \(error)")
            #endif
        }
        #endif
    }

    #if os(iOS)
    /// 处理音频打断通知（来电、闹钟等）
    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            // 打断开始：停止所有播放
            isAudioSessionActive = false
            DispatchQueue.main.async {
                for (_, player) in self.players { player.stop() }
            }
        case .ended:
            // 打断结束：重新激活
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    activateAudioSession()
                }
            }
        @unknown default:
            break
        }
    }
    #endif

    // MARK: - 内部

    private func play(_ name: String) {
        guard !_isMuted, let player = players[name] else { return }
        // 确保音频会话已激活
        activateAudioSession()
        // AVAudioPlayer 不保证线程安全，调度回主线程执行
        DispatchQueue.main.async {
            player.currentTime = 0
            player.play()
        }
    }

    private func loadSound(name: String, ext: String) -> AVAudioPlayer? {
        var url = ResourceBundle.url(forResource: name, withExtension: ext)
        // Fallback: .app 打包时音频可能在 Sounds/ 子目录
        if url == nil {
            url = ResourceBundle.url(forResource: name, withExtension: ext, subdirectory: "Sounds")
        }
        guard let soundURL = url else { return nil }
        return try? AVAudioPlayer(contentsOf: soundURL)
    }
}
