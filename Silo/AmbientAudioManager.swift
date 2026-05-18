import AVFoundation
import Observation

private final class RenderState: @unchecked Sendable {
    var p0: Float = 0, p1: Float = 0, p2: Float = 0
    var p3: Float = 0, p4: Float = 0, p5: Float = 0, p6: Float = 0
    var brown: Float = 0
    var lowPass: Float = 0
}

@MainActor
@Observable
final class AmbientAudioManager {
    private(set) var currentSound: String = "None"
    var volume: Float = 0.5 {
        didSet { engine?.mainMixerNode.outputVolume = volume }
    }
    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?

    func play(sound: String) {
        if sound == currentSound, let e = engine, e.isRunning { return }
        stop()
        guard sound != "None" else { return }
        currentSound = sound
        startEngine(sound: sound)
    }

    func stop() {
        engine?.stop()
        if let src = sourceNode { engine?.detach(src) }
        engine = nil
        sourceNode = nil
        currentSound = "None"
    }

    func pause() {
        engine?.pause()
    }

    func resume() {
        guard currentSound != "None", let e = engine else { return }
        if !e.isRunning {
            try? e.start()
        }
    }

    private func startEngine(sound: String) {
        let e = AVAudioEngine()

        let sampleRate: Double = 44100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            currentSound = "None"
            return
        }

        let state = RenderState()
        let amp = amplitude(for: sound)
        let capturedSound = sound

        let src = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = Self.generateSample(sound: capturedSound, state: state, amp: amp)
                for buffer in abl {
                    buffer.mData!.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }
            return noErr
        }

        e.attach(src)
        e.connect(src, to: e.mainMixerNode, format: format)
        e.mainMixerNode.outputVolume = volume

        do {
            try e.start()
            engine = e
            sourceNode = src
        } catch {
            currentSound = "None"
            engine = nil
            sourceNode = nil
        }
    }

    private func amplitude(for sound: String) -> Float {
        switch sound {
        case "Rain":        return 0.40
        case "Library":     return 0.07
        case "White Noise": return 0.30
        case "Fireplace":   return 0.25
        case "Ocean":       return 0.35
        case "Cafe":        return 0.08
        default:            return 0.20
        }
    }

    private static func generateSample(sound: String, state: RenderState, amp: Float) -> Float {
        switch sound {
        case "White Noise":
            return Float.random(in: -1...1) * amp

        case "Rain":
            let noise = Float.random(in: -1...1)
            state.lowPass += 0.04 * (noise - state.lowPass)
            return max(-1, min(1, state.lowPass * amp * 9))

        case "Library":
            let w = Float.random(in: -1...1)
            state.p0 = 0.99886 * state.p0 + w * 0.0555179
            state.p1 = 0.99332 * state.p1 + w * 0.0750759
            state.p2 = 0.96900 * state.p2 + w * 0.1538520
            state.p3 = 0.86650 * state.p3 + w * 0.3104856
            state.p4 = 0.55000 * state.p4 + w * 0.5329522
            state.p5 = -0.7616 * state.p5 - w * 0.0168980
            let pink = state.p0 + state.p1 + state.p2 + state.p3 + state.p4 + state.p5 + state.p6 + w * 0.5362
            state.p6 = w * 0.115926
            return max(-1, min(1, pink * amp * 0.11))

        case "Fireplace":
            let w = Float.random(in: -1...1)
            state.brown = (state.brown + 0.02 * w) / 1.02
            let crackle: Float = Float.random(in: 0...1) > 0.9985 ? Float.random(in: -0.4...0.4) : 0
            return max(-1, min(1, (state.brown * 3.5 + crackle) * amp))

        case "Ocean":
            // Brown noise with slow modulation = ocean waves
            let w = Float.random(in: -1...1)
            state.brown = (state.brown + 0.005 * w) / 1.005
            state.lowPass += 0.002 * (state.brown - state.lowPass)
            return max(-1, min(1, state.lowPass * amp * 8))

        case "Cafe":
            // Pink noise at very low amplitude = distant cafe chatter
            let w = Float.random(in: -1...1)
            state.p0 = 0.99886 * state.p0 + w * 0.0555179
            state.p1 = 0.99332 * state.p1 + w * 0.0750759
            state.p2 = 0.96900 * state.p2 + w * 0.1538520
            state.p3 = 0.86650 * state.p3 + w * 0.3104856
            let pink = state.p0 + state.p1 + state.p2 + state.p3 + w * 0.5362
            return max(-1, min(1, pink * amp * 0.15))

        default:
            return 0
        }
    }
}
