import AppKit

let bundledModel = Bundle.main.resourceURL!.appendingPathComponent("Whisper")
if CommandLine.arguments.dropFirst().first == "--transcribe" {
    var files = Array(CommandLine.arguments.dropFirst(2))
    var language: String? = "zh"
    if files.first == "--language" {
        guard files.count >= 3, ["auto", "zh", "en"].contains(files[1]) else {
            fputs("Usage: speak-low --transcribe [--language zh|auto|en] AUDIO ...\n", stderr)
            exit(2)
        }
        language = files[1] == "auto" ? nil : files[1]
        files.removeFirst(2)
    }
    guard !files.isEmpty else { fputs("Usage: speak-low --transcribe AUDIO ...\n", stderr); exit(2) }
    Task {
        do {
            let speech = SpeechEngine()
            try await speech.load(from: bundledModel)
            for path in files {
                let start = Date()
                let result = try await speech.text(from: URL(fileURLWithPath: path), language: language)
                print(result)
                fputs(String(format: "%.2f s\n", Date().timeIntervalSince(start)), stderr)
            }
            exit(0)
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
    dispatchMain()
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let controller = AppController()
    app.delegate = controller
    withExtendedLifetime(controller) { app.run() }
}
