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
        // Codex ships Chromium as Codex Framework, including in the ChatGPT-branded app.
        if id == "com.openai.codex" { return true }
        if ["com.google.Chrome", "com.apple.Safari", "com.microsoft.edgemac", "com.brave.Browser",
            "org.mozilla.firefox", "company.thebrowser.Browser", "com.electron."].contains(where: { id.hasPrefix($0) }) {
            return true
        }
        guard let bundle = app.bundleURL else { return false }
        return FileManager.default.fileExists(atPath: bundle.appendingPathComponent("Contents/Frameworks/Electron Framework.framework").path)
    }

    fileprivate static func selectedRange(_ field: AXUIElement) -> NSRange? {
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
            if field.map(isEditable) != true, let global = element(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute) {
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

    private static func string(in field: AXUIElement, range: NSRange) -> String? {
        var span = CFRange(location: range.location, length: range.length)
        guard let param = AXValueCreate(.cfRange, &span) else { return nil }
        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(field, kAXStringForRangeParameterizedAttribute as CFString,
                                                         param, &result) == .success else { return nil }
        return result as? String
    }

    private static func confirm(_ text: String, in target: WritingTarget, before: InsertionCheck) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        repeat {
            let field = target.field
            if before.confirms(text, valueAfter: attr(field, kAXValueAttribute) as? String,
                               caret: WritingTarget.selectedRange(field),
                               countAfter: attr(field, kAXNumberOfCharactersAttribute) as? Int,
                               readRange: { string(in: field, range: $0) }) { return true }
            if Task.isCancelled { return false }
            try? await Task.sleep(for: .milliseconds(70))
        } while clock.now < deadline
        return false
    }

    // Use the application's standard Paste action when available. This enters
    // Chromium's editing pipeline just like Edit > Paste, independent of keyboard layout.
    private static func pasteCommand(in pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        guard let bar = element(app, kAXMenuBarAttribute),
              let menus = attr(bar, kAXChildrenAttribute) as? [AXUIElement] else { return nil }
        for menu in menus where ["Edit", "编辑", "編輯"].contains(attr(menu, kAXTitleAttribute) as? String ?? "") {
            guard let contents = (attr(menu, kAXChildrenAttribute) as? [AXUIElement])?.first,
                  let commands = attr(contents, kAXChildrenAttribute) as? [AXUIElement] else { continue }
            return commands.first {
                (attr($0, kAXMenuItemCmdCharAttribute) as? String)?.uppercased() == "V" &&
                (attr($0, kAXMenuItemCmdModifiersAttribute) as? Int) == 0 &&
                (attr($0, kAXEnabledAttribute) as? Bool) == true
            }
        }
        return nil
    }

    static func insert(_ text: String, into target: WritingTarget?) async -> Bool {
        guard !text.isEmpty, let target, target.stillFocused() else { return false }
        let before = InsertionCheck(value: attr(target.field, kAXValueAttribute) as? String,
                                    selection: target.selection,
                                    count: attr(target.field, kAXNumberOfCharactersAttribute) as? Int)
        if !target.prefersPaste, settable(target.field, kAXSelectedTextAttribute), target.stillFocused() {
            let result = AXUIElementSetAttributeValue(target.field, kAXSelectedTextAttribute as CFString, text as CFString)
            // A timeout can mean delivery took place. Replaying it could duplicate the text.
            if result == .success || result == .cannotComplete {
                return await confirm(text, in: target, before: before)
            }
        }

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
        let cleared = pb.clearContents()
        guard pb.setString(text, forType: .string) else {
            if pb.changeCount == cleared, !saved.isEmpty { pb.writeObjects(saved) }
            return false
        }
        let owned = pb.changeCount
        previousClipboard = (owned, saved)
        defer { if previousClipboard?.change == owned { restoreClipboard() } }

        let command = pasteCommand(in: target.pid)
        guard target.stillFocused(), pb.changeCount == owned else { return false }
        if let command {
            AXUIElementSetMessagingTimeout(command, 0.35)
            let result = AXUIElementPerformAction(command, kAXPressAction as CFString)
            if result == .success || result == .cannotComplete {
                return await confirm(text, in: target, before: before)
            }
        }
        guard target.stillFocused(), pb.changeCount == owned else { return false }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(target.pid)
        up.postToPid(target.pid)
        return await confirm(text, in: target, before: before)
    }
}
