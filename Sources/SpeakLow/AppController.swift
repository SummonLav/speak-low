import AppKit
import AVFoundation
import SwiftUI

enum Phase {
    case loading, unavailable, idle, recording, recognizing, cleaning, inserting, cancelling
}

@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate, ObservableObject {
    @Published private(set) var phase = Phase.loading
    @Published private(set) var message = "正在载入本地语音模型…"
    @Published private(set) var hasAccess = false
    @Published private(set) var hasMic = false
    @Published private(set) var hasShortcut = false
    let updater = AppUpdate()
    private let engine = SpeechEngine()
    private let mic = Microphone()
    private let sounds = DictationSounds()
    private let shortcut = ShortcutMonitor()
    private let hud = VoicePanel()
    private var item: NSStatusItem!
    private var settings: NSWindow?
    private var heartbeat: Timer?
    private var recordingStart = Date()
    private var activeID: UUID?
    private var job: Task<Void, Never>?
    private var target: WritingTarget?
    private var lastText = ""
    private var inFlightAudio: URL?
    private var hideHUD: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        shortcut.toggle = { [weak self] in self?.toggle() }
        shortcut.cancel = { [weak self] in self?.cancel() }
        mic.onInterrupted = { [weak self] in
            self?.cancel()
            self?.notice("麦克风录音中断，请检查输入设备。")
        }
        refreshAccess()
        if let front = NSWorkspace.shared.frontmostApplication { WritingTarget.prepare(front) }
        hydrate()
        heartbeat = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(otherAppActivated(_:)),
                                                         name: NSWorkspace.didActivateApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleeping),
                                                         name: NSWorkspace.willSleepNotification, object: nil)
        if !hasAccess || !hasMic || !updater.status.isEmpty { showSettings() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        heartbeat?.invalidate()
        shortcut.stop()
        TextInsertion.restoreClipboard()
        mic.discard()
        job?.cancel()
        if let url = inFlightAudio { try? FileManager.default.removeItem(at: url) }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func otherAppActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        if let target, app.processIdentifier != target.pid { self.target = nil }
        WritingTarget.prepare(app)
    }

    @objc private func sleeping() { cancel() }

    private func tick() {
        refreshAccess()
        if phase == .recording {
            let seconds = Int(Date().timeIntervalSince(recordingStart))
            hud.update(icon: "waveform", text: String(format: "录音中  %d:%02d", seconds / 60, seconds % 60))
        }
    }

    func refreshAccess() {
        let ax = AXIsProcessTrusted()
        let microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        if hasMic != microphone { hasMic = microphone }
        if hasAccess != ax { hasAccess = ax }
        if !ax && shortcut.running { shortcut.stop() }
        if ax && !shortcut.running { _ = shortcut.start() }
        if hasShortcut != shortcut.running { hasShortcut = shortcut.running }
    }

    func askAccessibility() {
        let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(prompt)
        openPrivacy("Privacy_Accessibility")
    }

    func askMicrophone() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            Task {
                _ = await AVCaptureDevice.requestAccess(for: .audio)
                refreshAccess()
            }
        } else { openPrivacy("Privacy_Microphone") }
    }

    func openPrivacy(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func hydrate() {
        setPhase(.loading, "正在载入本地语音模型…")
        Task {
            do {
                try await engine.load(from: bundledModel)
                setPhase(.idle, "本地模型就绪")
            } catch { setPhase(.unavailable, error.localizedDescription) }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(withTitle: message, action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        if phase == .idle || phase == .recording {
            add(phase == .recording ? "结束听写" : "开始听写", #selector(toggle), to: menu)
        }
        if activeID != nil && phase != .inserting { add("取消本次听写", #selector(cancel), to: menu) }
        if phase == .unavailable { add("重新载入模型", #selector(hydrate), to: menu) }
        if !lastText.isEmpty { add("复制上次结果", #selector(copyLast), to: menu) }
        menu.addItem(.separator())
        add("设置…", #selector(showSettings), to: menu)
        add("退出 speak-low", #selector(quit), to: menu)
    }

    private func add(_ title: String, _ action: Selector, to menu: NSMenu) {
        menu.addItem(withTitle: title, action: action, keyEquivalent: "").target = self
    }

    @objc func showSettings() {
        if settings == nil {
            let controller = NSHostingController(rootView: SettingsView(app: self))
            let window = NSWindow(contentViewController: controller)
            window.title = "speak-low 设置"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settings = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settings?.makeKeyAndOrderFront(nil)
    }

    func checkForUpdates() {
        updater.start { [weak self] in
            guard let self else { return false }
            return phase == .idle || phase == .unavailable || phase == .loading
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc func toggle() {
        switch phase {
        case .idle: begin()
        case .recording: finish()
        case .loading, .unavailable: notice(message)
        case .recognizing, .cleaning, .inserting, .cancelling: break
        }
    }

    private func begin() {
        guard hasMic else {
            showSettings()
            askMicrophone()
            return
        }
        hideHUD?.cancel()
        target = WritingTarget.current()
        do { try mic.start() }
        catch {
            target = nil
            notice(error.localizedDescription)
            return
        }
        sounds.started()
        activeID = UUID()
        shortcut.handlesEscape = true
        recordingStart = Date()
        setPhase(.recording, "正在听写 · 再按右 ⌥ 结束")
        hud.update(icon: "waveform", text: "录音中  0:00")
        hud.show()
    }

    private func finish() {
        guard let id = activeID, let audio = mic.finish() else {
            cancel()
            return
        }
        sounds.stopped()
        inFlightAudio = audio
        setPhase(.recognizing, "正在本地转写…")
        hud.update(icon: "waveform", text: "正在转写…")
        let preferences = UserDefaults.standard
        let lang = preferences.string(forKey: "language") ?? "zh"
        let polish = preferences.bool(forKey: "claudeEnabled")
        let model = preferences.string(forKey: "claudeModel") ?? Claude.defaultModel
        job = Task {
            defer {
                try? FileManager.default.removeItem(at: audio)
                if inFlightAudio == audio { inFlightAudio = nil }
            }
            do {
                var text = try await engine.text(from: audio, language: lang == "auto" ? nil : lang)
                guard activeID == id else { return }
                var fallback: String?
                if polish {
                    setPhase(.cleaning, "正在用 Claude 整理…")
                    hud.update(icon: "text.line.first.and.arrowtriangle.forward", text: "正在整理…")
                    do {
                        guard let key = try Credentials.read(), !key.isEmpty else { throw VoiceError("缺少 API Key。") }
                        text = try await Claude.clean(text, key: key, model: model)
                    } catch { fallback = error.localizedDescription }
                }
                guard activeID == id else { return }
                lastText = text
                shortcut.handlesEscape = false
                setPhase(.inserting, "正在写入光标…")
                hud.update(icon: "text.cursor", text: "正在写入光标…")
                let confirmed = await TextInsertion.insert(text, into: target)
                let delivery = confirmed ? "已输入" : "未确认写入 · 从菜单栏复制上次结果"
                endSession()
                if let fallback {
                    notice("\(delivery) · 已用本地稿", detail: "\(delivery) · 已用本地稿（\(fallback)）")
                } else { notice(delivery) }
            } catch {
                guard activeID == id else { return }
                endSession()
                notice(error.localizedDescription)
            }
        }
    }

    @objc func cancel() {
        guard activeID != nil, phase != .inserting else { return }
        let wasRecording = phase == .recording
        activeID = nil
        shortcut.handlesEscape = false
        target = nil
        mic.discard()
        if wasRecording { sounds.stopped() }
        if let pending = job {
            pending.cancel()
            setPhase(.cancelling, "正在取消…")
            hud.update(icon: "xmark", text: "正在取消…")
            Task {
                await pending.value
                endSession()
                notice("已取消听写")
            }
        } else {
            endSession()
            notice("已取消听写")
        }
    }

    private func endSession() {
        activeID = nil
        shortcut.handlesEscape = false
        target = nil
        job = nil
        setPhase(.idle, "本地模型就绪")
    }

    private func notice(_ title: String, detail: String? = nil) {
        message = detail ?? title
        hideHUD?.cancel()
        hud.update(icon: "text.bubble", text: title)
        hud.show()
        let hide = DispatchWorkItem { [weak self] in self?.hud.orderOut(nil) }
        hideHUD = hide
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6, execute: hide)
    }

    @objc private func copyLast() {
        guard !lastText.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(lastText, forType: .string)
        notice("已复制")
    }

    private func setPhase(_ value: Phase, _ description: String) {
        phase = value
        message = description
        guard let button = item?.button else { return }
        button.image = value == .recording
            ? NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "speak-low 录音中")
            : Brand.mascot
        button.toolTip = "speak-low · \(description)"
    }
}
