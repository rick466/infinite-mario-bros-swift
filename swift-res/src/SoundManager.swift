import AVFoundation

final class SoundManager {
    enum Effect: Hashable { case jump, coin, stomp, block, powerUp, fireball, oneUp }
    private var players: [Effect: AVAudioPlayer] = [:]
    private var bgm: AVAudioPlayer?

    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        load(.jump, "jump.wav")
        load(.coin, "coin.wav")
        load(.stomp, "stomp.wav")
        load(.block, "breakblock.wav")
        load(.powerUp, "powerup.wav")
        load(.fireball, "fireball.wav")
        load(.oneUp, "1-up.wav")
        startBGM()
    }

    private func load(_ effect: Effect, _ filename: String) {
        guard let url = Bundle.module.url(forResource: filename, withExtension: nil) else { return }
        players[effect] = try? AVAudioPlayer(contentsOf: url)
        players[effect]?.prepareToPlay()
    }

    func play(_ effect: Effect) {
        guard let player = players[effect] else { return }
        player.currentTime = 0
        player.play()
    }

    private func startBGM() {
        guard let data = makeBGMData() else { return }
        bgm = try? AVAudioPlayer(data: data)
        bgm?.numberOfLoops = -1
        bgm?.volume = 0.12
        bgm?.prepareToPlay()
        bgm?.play()
    }

    private func makeBGMData() -> Data? {
        let sampleRate = 22050
        let notes: [(Double, Double)] = [
            (659.25, 0.16), (659.25, 0.16), (0, 0.16), (659.25, 0.16),
            (0, 0.16), (523.25, 0.16), (659.25, 0.16), (783.99, 0.32),
            (392.00, 0.32), (523.25, 0.16), (392.00, 0.16), (330.00, 0.16)
        ]
        var pcm = Data()
        for (frequency, duration) in notes {
            let count = Int(Double(sampleRate) * duration)
            for i in 0..<count {
                let t = Double(i) / Double(sampleRate)
                let envelope = min(1, Double(i) / 400.0) * min(1, Double(count - i) / 700.0)
                let value = frequency == 0 ? 0.0 : sin(2 * Double.pi * frequency * t) * 0.32 * envelope
                var sample = Int16(max(-1, min(1, value)) * Double(Int16.max))
                pcm.append(Data(bytes: &sample, count: MemoryLayout<Int16>.size))
            }
        }

        let byteRate = sampleRate * 2
        var data = Data()
        func appendLE<T: FixedWidthInteger>(_ value: T) {
            var v = value.littleEndian
            data.append(Data(bytes: &v, count: MemoryLayout<T>.size))
        }
        data.append(Data("RIFF".utf8))
        appendLE(UInt32(36 + pcm.count))
        data.append(Data("WAVE".utf8))
        data.append(Data("fmt ".utf8))
        appendLE(UInt32(16))
        appendLE(UInt16(1))
        appendLE(UInt16(1))
        appendLE(UInt32(sampleRate))
        appendLE(UInt32(byteRate))
        appendLE(UInt16(2))
        appendLE(UInt16(16))
        data.append(Data("data".utf8))
        appendLE(UInt32(pcm.count))
        data.append(pcm)
        return data
    }
}
