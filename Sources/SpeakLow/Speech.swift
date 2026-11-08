import AVFoundation
import Foundation
import WhisperKit

actor SpeechEngine {
    private var pipeline: WhisperKit?

    func load(from folder: URL) async throws {
        guard pipeline == nil else { return }
        for name in ["AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc", "TextDecoder.mlmodelc", "tokenizer.json", "tokenizer_config.json"] {
            guard FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path) else {
                throw VoiceError("模型文件不完整，请重新安装完整的 App。")
            }
        }
        let config = WhisperKitConfig(modelFolder: folder.path, tokenizerFolder: folder,
                                      verbose: false, prewarm: false, load: true, download: false)
        pipeline = try await WhisperKit(config)
    }

    func text(from file: URL, language: String?) async throws -> String {
        guard let pipeline else { throw VoiceError("语音模型尚未就绪。") }
        let samples = try AudioProcessor.loadAudioAsFloatArray(fromPath: file.path)
        // Four 20 ms frames above -60 dBFS exclude digital silence and isolated clicks.
        var active = 0
        for start in stride(from: 0, to: samples.count, by: 320) {
            let frame = samples[start..<min(start + 320, samples.count)]
            if frame.reduce(Float(0), { $0 + $1 * $1 }) > Float(frame.count) * 0.000001 {
                active += 1
                if active >= 4 { break }
            }
        }
        guard active >= 4 else { throw VoiceError("没有听到语音。请检查麦克风后重试。") }
        let options = DecodingOptions(language: language, temperatureFallbackCount: 2,
                                      detectLanguage: language == nil, skipSpecialTokens: true,
                                      concurrentWorkerCount: 2, chunkingStrategy: .vad)
        let results = try await pipeline.transcribe(audioArray: samples, decodeOptions: options)
        let pieces = results.flatMap(\.segments).map(\.text)
        let raw = pieces.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { throw VoiceError("没有识别到文字。") }
        let simplified = raw.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? raw
        return simplified.replacingOccurrences(of: #"(?<=\p{Han}),\s*(?=\p{Han})"#,
                                               with: "，", options: .regularExpression)
    }
}

@MainActor
final class Microphone: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var file: URL?
    var onInterrupted: (() -> Void)?

    func start() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("speak-low-\(UUID().uuidString).caf")
        file = url
        do {
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false
            ]
            let mic = try AVAudioRecorder(url: url, settings: settings)
            mic.delegate = self
            recorder = mic
            guard mic.record() else { throw VoiceError("麦克风启动失败，请检查声音输入设备。") }
        } catch {
            discard()
            throw error
        }
    }

    func finish() -> URL? {
        recorder?.delegate = nil
        recorder?.stop()
        recorder = nil
        defer { file = nil }
        return file
    }

    func discard() {
        if let url = finish() { try? FileManager.default.removeItem(at: url) }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in if self.recorder === recorder { self.onInterrupted?() } }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in if self.recorder === recorder { self.onInterrupted?() } }
    }
}
