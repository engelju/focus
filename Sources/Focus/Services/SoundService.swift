import AVFoundation
import AppKit

/// Alert sounds plus the optional ticking loop.
///
/// The tick is synthesised at runtime (a short decaying sine burst looped once
/// per second) so the app ships without any audio files.
final class SoundService {
    static let shared = SoundService()

    private let settings = AppSettings.shared
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var tickBuffer: AVAudioPCMBuffer?
    private var tickingEnabled = false

    private init() {}

    // MARK: - Alert sounds

    func playFlowEndSound() { play(named: settings.flowEndSound) }
    func playBreakEndSound() { play(named: settings.breakEndSound) }

    func play(named name: String) {
        guard name != "None", let sound = NSSound(named: name) else { return }
        sound.volume = Float(settings.notificationVolume)
        sound.stop()
        sound.play()
    }

    // MARK: - Ticking

    func setTicking(_ on: Bool) {
        if on {
            guard !tickingEnabled else { return }
            startTicking()
        } else {
            guard tickingEnabled else { return }
            stopTicking()
        }
    }

    func refreshTickingVolume() {
        player.volume = Float(settings.notificationVolume) * 0.35
    }

    private func startTicking() {
        guard let buffer = makeTickBuffer() else { return }
        do {
            if engine.attachedNodes.contains(player) == false {
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
            }
            if !engine.isRunning { try engine.start() }
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            refreshTickingVolume()
            player.play()
            tickingEnabled = true
        } catch {
            NSLog("Focus: ticking unavailable — \(error.localizedDescription)")
        }
    }

    private func stopTicking() {
        player.stop()
        if engine.isRunning { engine.pause() }
        tickingEnabled = false
    }

    private func makeTickBuffer() -> AVAudioPCMBuffer? {
        if let tickBuffer { return tickBuffer }
        let sampleRate = 44_100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleRate))
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(sampleRate)
        guard let samples = buffer.floatChannelData?[0] else { return nil }

        let clickFrames = Int(sampleRate * 0.012)
        let frequency = 1_050.0
        for frame in 0..<Int(buffer.frameLength) {
            if frame < clickFrames {
                let t = Double(frame) / sampleRate
                let envelope = exp(-Double(frame) / (Double(clickFrames) * 0.35))
                samples[frame] = Float(sin(2 * .pi * frequency * t) * envelope * 0.6)
            } else {
                samples[frame] = 0
            }
        }
        tickBuffer = buffer
        return buffer
    }
}
