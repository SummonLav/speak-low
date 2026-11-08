import AppKit
import Foundation

@MainActor
final class AppUpdate: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var status = ""
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    private let revision = Bundle.main.object(forInfoDictionaryKey: "SpeakLowRevision") as? String ?? ""

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--update-installed") { status = "已更新到最新版" }
        if arguments.contains("--update-failed") { status = "安装失败，已重新打开原版本。请重试。" }
    }

    func start(canRestart: @escaping @MainActor () -> Bool) {
        guard !busy else { return }
        busy = true
        status = "正在检查更新…"
        Task {
            var workspace: URL?
            defer {
                if let workspace { try? FileManager.default.removeItem(at: workspace) }
                busy = false
            }
            do {
                let bundle = Bundle.main.bundleURL
                guard let helper = Bundle.main.url(forResource: "update", withExtension: "py") else {
                    throw UpdateError("找不到更新组件，请重新安装 speak-low。")
                }
                let latest = try await Self.run(helper, ["latest"])
                guard latest != revision else {
                    status = "已是最新版"
                    return
                }
                status = "正在下载并构建新版，可以继续听写…"
                let folder = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                         appropriateFor: bundle, create: true)
                workspace = folder
                _ = try await Self.run(helper, ["prepare", bundle.path, folder.path, latest])
                if !canRestart() { status = "新版已就绪，本次听写结束后将重新打开。" }
                while !canRestart() { try await Task.sleep(nanoseconds: 250_000_000) }

                let launcher = folder.appendingPathComponent("relaunch.py")
                try FileManager.default.copyItem(at: helper, to: launcher)
                let process = Self.process(launcher, ["relaunch", bundle.path, folder.path,
                                                       String(ProcessInfo.processInfo.processIdentifier), revision])
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                try process.run()
                workspace = nil // The independent launcher now owns the staged app.
                status = "正在重新打开 speak-low…"
                NSApp.terminate(nil)
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private nonisolated static func process(_ script: URL, _ arguments: [String]) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [script.path] + arguments
        process.standardInput = FileHandle.nullDevice
        return process
    }

    private nonisolated static func run(_ script: URL, _ arguments: [String]) async throws -> String {
        try await Task.detached(priority: .utility) {
            let process = Self.process(script, arguments)
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            guard process.terminationStatus == 0 else {
                throw UpdateError(output.isEmpty ? "更新失败，请重试。" : output)
            }
            return output
        }.value
    }
}

private struct UpdateError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
