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
        let surface = NSView()
        surface.wantsLayer = true
        surface.layer?.backgroundColor = Brand.charcoal.cgColor
        surface.layer?.cornerRadius = 19
        surface.layer?.borderColor = NSColor(white: 1, alpha: 0.22).cgColor
        surface.layer?.borderWidth = 1
        surface.layer?.masksToBounds = true
        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        glyph.contentTintColor = .white
        glyph.imageScaling = .scaleProportionallyUpOrDown
        glyph.widthAnchor.constraint(equalToConstant: 23).isActive = true
        glyph.heightAnchor.constraint(equalToConstant: 23).isActive = true
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
        glyph.image = text.hasPrefix("录音中") || icon == "text.bubble"
            ? Brand.mascot : NSImage(systemSymbolName: icon, accessibilityDescription: nil)
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

    @Environment(\.colorScheme) private var appearance
    @State private var editingModel = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                if let wordmark = Brand.wordmark {
                    Image(nsImage: wordmark).resizable().scaledToFit()
                        .frame(width: 163, height: 70)
                        .accessibilityLabel("speak-low · speak anything")
                } else {
                    Text("speak-low").font(.title.bold())
                }
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    shortcut("右 ⌥", "开始或结束听写")
                    shortcut("esc", "取消听写")
                }
            }
            .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 5)

            Form {
                Section {
                    Picker("识别语言", selection: $language) {
                        Text("中文优先（中英混说）").tag("zh")
                        Text("自动识别").tag("auto")
                        Text("English").tag("en")
                    }
                    permission("麦克风", ok: app.hasMic, action: app.askMicrophone)
                    permission("辅助功能", ok: app.hasAccess, action: app.askAccessibility)
                    if app.hasAccess && !app.hasShortcut {
                        permission("输入监控", ok: false) { app.openPrivacy("Privacy_ListenEvent") }
                    }
                } header: {
                    Text("本地听写")
                } footer: {
                    Text(app.phase == .loading || app.phase == .unavailable ? app.message : "Whisper 模型已内置，可离线听写。")
                }
                Section {
                    Toggle("启用文字整理", isOn: Binding(get: { enabled }, set: toggle))
                        .toggleStyle(.switch)
                    LabeledContent("API Key") {
                        SecureField("输入或替换密钥", text: $key)
                            .labelsHidden().accessibilityLabel("API Key").textFieldStyle(.plain)
                            .padding(.horizontal, 7).frame(width: 235, height: 24)
                            .background(fieldBackground, in: RoundedRectangle(cornerRadius: 5))
                    }
                    LabeledContent("模型 ID") {
                        ModelIDField(text: $model, editing: $editingModel)
                            .padding(.horizontal, 6).frame(width: 235, height: 24)
                            .background(fieldBackground, in: RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color.primary.opacity(editingModel ? 0.55 : 0.12), lineWidth: editingModel ? 1.5 : 1)
                                .allowsHitTesting(false))
                    }
                } header: {
                    Text("Claude 文字整理")
                } footer: {
                    Text("仅发送本次转写文字，费用由你的 Anthropic API 账户承担。")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            Divider()
            HStack(spacing: 10) {
                Button("移除密钥", action: remove)
                Spacer()
                Text(feedback).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Button("保存配置", action: save)
            }
            .padding(.horizontal, 20).padding(.vertical, 11)
        }
        .tint(.gray)
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(width: 510, height: 570)
        .onAppear { model = storedModel; key = ""; feedback = ""; app.refreshAccess() }
    }

    private var fieldBackground: Color {
        Color(white: appearance == .dark ? 0.16 : 0.96)
    }

    private func shortcut(_ key: String, _ action: String) -> some View {
        HStack(spacing: 8) {
            Text(key).font(.system(size: 10, weight: .medium, design: .monospaced))
                .frame(width: 34, height: 19)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.16)))
            Text(action).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func permission(_ title: String, ok: Bool, action: @escaping () -> Void) -> some View {
        LabeledContent(title) {
            if ok {
                Label("已授权", systemImage: "checkmark.circle.fill").foregroundStyle(.secondary)
            } else {
                Button("开启…", action: action).controlSize(.small)
            }
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
