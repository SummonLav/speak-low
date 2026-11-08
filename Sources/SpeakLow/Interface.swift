import AppKit
import SwiftUI

@MainActor
final class VoicePanel: NSPanel {
    private let label = NSTextField(labelWithString: "")
    private let glyph = NSImageView()
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 220, height: 44),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isReleasedWhenClosed = false
        isFloatingPanel = true
        level = .statusBar
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let surface = NSVisualEffectView()
        surface.material = .hudWindow
        surface.state = .active
        surface.wantsLayer = true
        surface.layer?.cornerRadius = 17
        surface.layer?.masksToBounds = true
        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        let row = NSStackView(views: [glyph, label])
        row.spacing = 9
        row.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(row)
        NSLayoutConstraint.activate([row.centerXAnchor.constraint(equalTo: surface.centerXAnchor),
                                     row.centerYAnchor.constraint(equalTo: surface.centerYAnchor),
                                     row.widthAnchor.constraint(lessThanOrEqualTo: surface.widthAnchor, constant: -20)])
        contentView = surface
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    func update(icon: String, text: String) {
        label.stringValue = text
        glyph.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        glyph.contentTintColor = text.hasPrefix("录音中") ? .systemRed : .labelColor
        let size = NSSize(width: min(380, max(148, label.intrinsicContentSize.width + 60)), height: 42)
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            setFrame(NSRect(x: frame.midX - size.width / 2, y: frame.minY + 26,
                            width: size.width, height: size.height), display: true)
        }
    }
    func show() { orderFrontRegardless() }
}

struct SettingsView: View {
    @ObservedObject var app: AppController
    @AppStorage("language") private var language = "zh"
    @AppStorage("claudeEnabled") private var enabled = false
    @AppStorage("claudeModel") private var storedModel = Claude.defaultModel
    @State private var key = ""
    @State private var model = ""
    @State private var feedback = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill").font(.system(size: 34)).foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 3) {
                    Text("speak-low").font(.title2.weight(.semibold))
                    Text("单按右 ⌥ 开始，再按一次输入。Esc 取消。").foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack {
                Text("本地听写").font(.headline)
                Spacer()
                Picker("语言", selection: $language) {
                    Text("中文优先（中英混说）").tag("zh")
                    Text("自动识别").tag("auto")
                    Text("English").tag("en")
                }.fixedSize()
            }
            Text(app.phase == .loading || app.phase == .unavailable ? app.message : "Whisper · 模型已内置，可离线使用")
                .font(.callout).foregroundStyle(.secondary)
            permission("麦克风", ok: app.hasMic, action: app.askMicrophone)
            permission("辅助功能 · 快捷键与光标写入", ok: app.hasAccess, action: app.askAccessibility)
            if app.hasAccess && !app.hasShortcut {
                permission("输入监控 · 系统尚未放行快捷键", ok: false) { app.openPrivacy("Privacy_ListenEvent") }
            }
            Divider()
            HStack {
                Text("Claude 文字整理").font(.headline)
                Spacer()
                Toggle("启用整理", isOn: Binding(get: { enabled }, set: toggle)).labelsHidden().toggleStyle(.switch)
                    .accessibilityLabel("启用 Claude 文字整理")
            }
            Text("启用后仅向 Anthropic 发送本次转写文字，费用由你的 API 账户承担。")
                .font(.callout).foregroundStyle(.secondary)
            LabeledContent("API Key") {
                SecureField("输入或替换密钥", text: $key).textFieldStyle(.roundedBorder)
            }
            LabeledContent("模型 ID") {
                TextField("Claude 模型 ID", text: $model).textFieldStyle(.roundedBorder)
            }
            HStack {
                Button("保存配置", action: save)
                Button("移除密钥", action: remove)
                Spacer()
                Text(feedback).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .padding(24).frame(width: 490)
        .onAppear { model = storedModel; key = ""; feedback = ""; app.refreshAccess() }
    }

    private func permission(_ title: String, ok: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(ok ? Color.teal : Color.secondary)
            Text(title)
            Spacer()
            if ok { Text("已授权").font(.callout).foregroundStyle(.secondary) }
            else { Button("开启…", action: action).controlSize(.small) }
        }
    }
    private func save() {
        let chosen = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !chosen.isEmpty else { feedback = "请填写模型 ID。"; return }
        do {
            let secret = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !secret.isEmpty { try Credentials.set(secret); key = "" }
            storedModel = chosen
            feedback = "已保存"
        } catch { feedback = error.localizedDescription }
    }
    private func toggle(_ on: Bool) {
        if !on { enabled = false; feedback = ""; return }
        save()
        guard feedback == "已保存" else { return }
        do {
            guard try Credentials.read() != nil else { feedback = "请先填写 API Key。"; return }
            enabled = true
            feedback = "已启用"
        } catch { feedback = error.localizedDescription }
    }
    private func remove() {
        do {
            try Credentials.remove()
            key = ""
            enabled = false
            feedback = "已移除"
        } catch { feedback = error.localizedDescription }
    }
}
