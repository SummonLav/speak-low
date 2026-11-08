import AppKit
import ApplicationServices

private func attr(_ node: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(node, name as CFString, &value) == .success else { return nil }
    return value
}

private func element(_ node: AXUIElement, _ name: String) -> AXUIElement? {
    guard let value = attr(node, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return (value as! AXUIElement)
}

private func settable(_ node: AXUIElement, _ name: String) -> Bool {
    var writable = DarwinBoolean(false)
    return AXUIElementIsAttributeSettable(node, name as CFString, &writable) == .success && writable.boolValue
}

struct WritingTarget {
    let pid: pid_t
    let field: AXUIElement
    let window: AXUIElement?
    let selection: NSRange?
    let prefersPaste: Bool

    static func prepare(_ app: NSRunningApplication) {
        guard AXIsProcessTrusted(), app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        let node = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(node, 0.25)
        // Chromium and Electron publish accessibility trees lazily.
        for flag in ["AXEnhancedUserInterface", "AXManualAccessibility"] where settable(node, flag) {
            AXUIElementSetAttributeValue(node, flag as CFString, kCFBooleanTrue)
        }
    }

    private static func browserEditor(_ app: NSRunningApplication) -> Bool {
        let id = app.bundleIdentifier ?? ""
        if ["com.google.Chrome", "com.apple.Safari", "com.microsoft.edgemac", "com.brave.Browser",
            "org.mozilla.firefox", "company.thebrowser.Browser", "com.electron."].contains(where: { id.hasPrefix($0) }) {
            return true
        }
        guard let bundle = app.bundleURL else { return false }
        return FileManager.default.fileExists(atPath: bundle.appendingPathComponent("Contents/Frameworks/Electron Framework.framework").path)
    }

    private static func selectedRange(_ field: AXUIElement) -> NSRange? {
        guard let value = attr(field, kAXSelectedTextRangeAttribute),
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
        return NSRange(location: range.location, length: range.length)
    }

    static func current() -> WritingTarget? {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        let node = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(node, 0.3)
        var field = element(node, kAXFocusedUIElementAttribute)
        if field.map(isEditable) != true {
            prepare(app)
            field = element(node, kAXFocusedUIElementAttribute)
            if field == nil, let global = element(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute) {
                var owner = pid_t(0)
                if AXUIElementGetPid(global, &owner) == .success && owner == app.processIdentifier { field = global }
            }
        }
        guard let field, isEditable(field) else { return nil }
        return WritingTarget(pid: app.processIdentifier, field: field, window: element(node, kAXFocusedWindowAttribute),
                             selection: selectedRange(field), prefersPaste: browserEditor(app))
    }

    private static func isEditable(_ field: AXUIElement) -> Bool {
        if attr(field, kAXSubroleAttribute) as? String == kAXSecureTextFieldSubrole { return false }
        if attr(field, kAXEnabledAttribute) as? Bool == false { return false }
        let role = attr(field, kAXRoleAttribute) as? String ?? ""
        return [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role) ||
            attr(field, "AXEditable") as? Bool == true || settable(field, kAXSelectedTextAttribute)
    }

    func stillFocused() -> Bool {
        guard let current = Self.current(), current.pid == pid, CFEqual(field, current.field),
              selection == current.selection else { return false }
        switch (window, current.window) {
        case let (a?, b?): return CFEqual(a, b)
        case (nil, nil): return true
        default: return false
        }
    }
}

@MainActor
enum TextInsertion {
    private static var previousClipboard: (change: Int, items: [NSPasteboardItem])?

    static func restoreClipboard() {
        guard let previous = previousClipboard else { return }
        previousClipboard = nil
        let board = NSPasteboard.general
        guard board.changeCount == previous.change else { return }
        board.clearContents()
        if !previous.items.isEmpty { board.writeObjects(previous.items) }
    }

    static func insert(_ text: String, into target: WritingTarget?) -> Bool {
        guard let target, target.stillFocused() else { return false }
        if !target.prefersPaste, settable(target.field, kAXSelectedTextAttribute),
           AXUIElementSetAttributeValue(target.field, kAXSelectedTextAttribute as CFString, text as CFString) == .success {
            return true
        }
        // Some editors expose a text field but only accept a normal Paste command.
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { return false }
        restoreClipboard()
        let pb = NSPasteboard.general
        let change = pb.changeCount
        let items = pb.pasteboardItems ?? []
        var saved = [NSPasteboardItem]()
        for item in items {
            let clone = NSPasteboardItem()
            for type in item.types {
                guard let data = item.data(forType: type), clone.setData(data, forType: type) else { return false }
            }
            saved.append(clone)
        }
        guard change == pb.changeCount, target.stillFocused() else { return false }
        pb.clearContents()
        guard pb.setString(text, forType: .string) else {
            if !saved.isEmpty { pb.writeObjects(saved) }
            return false
        }
        let owned = pb.changeCount
        previousClipboard = (owned, saved)
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(target.pid)
        up.postToPid(target.pid)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            if previousClipboard?.change == owned { restoreClipboard() }
        }
        return true
    }
}
