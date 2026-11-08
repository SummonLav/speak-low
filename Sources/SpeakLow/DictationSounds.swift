import AVFoundation

@MainActor
final class DictationSounds {
    private let opening = load("start")
    private let closing = load("stop")

    func started() { play(opening, stopping: closing) }
    func stopped() { play(closing, stopping: opening) }

    private static func load(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return player
    }

    private func play(_ player: AVAudioPlayer?, stopping other: AVAudioPlayer?) {
        other?.stop()
        player?.currentTime = 0
        player?.play()
    }
}
