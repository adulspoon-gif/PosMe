import UIKit
import AVFoundation

/// Suara dibuat langsung oleh aplikasi (tanpa berkas audio) dan getar haptic.
/// Memakai kategori .ambient: ikut senyap saat tombol senyap iPhone aktif.
final class Synth {
    static let shared = Synth()
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let sampleRate: Double = 44100
    private var format: AVAudioFormat
    private var started = false

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    private func startIfNeeded() {
        if started { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            node.play()
            started = true
        } catch {
            started = false
        }
    }

    struct Tone {
        var freq: Double
        var start: Double
        var dur: Double
        var vol: Float
        var sweepTo: Double? = nil
    }

    func play(_ tones: [Tone]) {
        guard !tones.isEmpty else { return }
        startIfNeeded()
        if !started { return }
        let total = tones.map { $0.start + $0.dur }.max() ?? 0.1
        let frames = AVAudioFrameCount(total * sampleRate) + 64
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buffer.frameLength = frames
        guard let data = buffer.floatChannelData?[0] else { return }
        for i in 0..<Int(frames) { data[i] = 0 }
        for tone in tones {
            let startFrame = Int(tone.start * sampleRate)
            let count = Int(tone.dur * sampleRate)
            var phase: Double = 0
            for n in 0..<count {
                let idx = startFrame + n
                if idx >= Int(frames) { break }
                let t = Double(n) / sampleRate
                let progress = t / tone.dur
                let f = tone.sweepTo != nil ? tone.freq * pow(tone.sweepTo! / tone.freq, progress) : tone.freq
                phase += 2.0 * Double.pi * f / sampleRate
                let attack = min(1.0, t / 0.006)
                let decay = exp(-4.2 * progress)
                data[idx] += Float(sin(phase) * attack * decay) * tone.vol
            }
        }
        node.scheduleBuffer(buffer, completionHandler: nil)
    }
}

enum Fx {
    static var soundOn: Bool {
        get { UserDefaults.standard.object(forKey: "soundOn") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "soundOn") }
    }
    static var hapticsOn: Bool {
        get { UserDefaults.standard.object(forKey: "hapticsOn") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "hapticsOn") }
    }

    private static func tones(_ list: [Synth.Tone]) {
        if soundOn { Synth.shared.play(list) }
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        if hapticsOn { UIImpactFeedbackGenerator(style: style).impactOccurred() }
    }

    static func tap() {
        impact(.light)
        tones([Synth.Tone(freq: 1100, start: 0, dur: 0.06, vol: 0.10, sweepTo: 760)])
    }

    static func select() {
        if hapticsOn { UISelectionFeedbackGenerator().selectionChanged() }
        tones([Synth.Tone(freq: 300, start: 0, dur: 0.17, vol: 0.12, sweepTo: 740),
               Synth.Tone(freq: 920, start: 0.05, dur: 0.09, vol: 0.05)])
    }

    static func pop() {
        impact(.medium)
        tones([Synth.Tone(freq: 520, start: 0, dur: 0.09, vol: 0.13, sweepTo: 900)])
    }

    static func open() {
        impact(.soft)
        tones([Synth.Tone(freq: 420, start: 0, dur: 0.13, vol: 0.10, sweepTo: 660)])
    }

    static func success() {
        if hapticsOn { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        tones([Synth.Tone(freq: 523.25, start: 0, dur: 0.22, vol: 0.12),
               Synth.Tone(freq: 659.25, start: 0.08, dur: 0.22, vol: 0.12),
               Synth.Tone(freq: 783.99, start: 0.16, dur: 0.30, vol: 0.12)])
    }

    /// Bunyi "kring" saat transaksi tersimpan.
    static func cash() {
        if hapticsOn { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        tones([Synth.Tone(freq: 1318.5, start: 0, dur: 0.35, vol: 0.12),
               Synth.Tone(freq: 1760, start: 0.09, dur: 0.50, vol: 0.11),
               Synth.Tone(freq: 2637, start: 0.09, dur: 0.25, vol: 0.04)])
    }

    static func error() {
        if hapticsOn { UINotificationFeedbackGenerator().notificationOccurred(.error) }
        tones([Synth.Tone(freq: 190, start: 0, dur: 0.16, vol: 0.12, sweepTo: 140),
               Synth.Tone(freq: 170, start: 0.14, dur: 0.20, vol: 0.12, sweepTo: 120)])
    }

    static func login() {
        if hapticsOn { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        tones([Synth.Tone(freq: 392, start: 0, dur: 0.28, vol: 0.10),
               Synth.Tone(freq: 523.25, start: 0.07, dur: 0.28, vol: 0.10),
               Synth.Tone(freq: 659.25, start: 0.14, dur: 0.28, vol: 0.10),
               Synth.Tone(freq: 783.99, start: 0.21, dur: 0.34, vol: 0.10)])
    }
}
