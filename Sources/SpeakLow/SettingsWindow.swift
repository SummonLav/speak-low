import AppKit

final class SettingsWindow: NSWindow {
    // An accessory app has no Edit menu to route these keys to the field editor.
    private let editingMenu: NSMenu = {
        let menu = NSMenu(title: "编辑")
        menu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return menu
    }()

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if firstResponder is NSTextView, editingMenu.performKeyEquivalent(with: event) { return true }
        return super.performKeyEquivalent(with: event)
    }
}
