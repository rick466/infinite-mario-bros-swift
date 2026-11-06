import AVFoundation

final class SoundManager {
    enum Effect {
        case jump, coin, stomp, block
    }

    private var players: [Effect: AVAudioPlayer] = [:]

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .game)
        try? AVAudioSession.sharedInstance().setActive(true)

        load(.jump, "jump.wav")
        load(.coin, "coin.wav")
        load(.stomp, "stomp.wav")
        load(.block, "breakblock.wav")\n        load(.powerUp, "powerup.wav")
    }

    private func load(_ effect: Effect, _ filename: String) {
        guard let url = Bundle.module.url(forResource: filename, withExtension: nil) else {
            return
        }
        players[effect] = try? AVAudioPlayer(contentsOf: url)
        players[effect]?.prepareToPlay()
    }

    func play(_ effect: Effect) {
        guard let player = players[effect] else { return }
        player.currentTime = 0
        player.play()
    }
}
