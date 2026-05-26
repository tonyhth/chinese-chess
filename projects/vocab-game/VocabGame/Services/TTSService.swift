import Foundation
import AVFoundation

@MainActor
class TTSService {
    static let shared = TTSService()
    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    func speak(_ text: String, language: String = "en-US") {
        guard !synthesizer.isSpeaking else {
            synthesizer.stopSpeaking(at: .immediate)
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    var isAvailable: Bool {
        AVSpeechSynthesisVoice(language: "en-US") != nil
    }
}
