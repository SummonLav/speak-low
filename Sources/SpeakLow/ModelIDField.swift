import AppKit
import SwiftUI

// Use a private field editor so the model's neutral selection never changes
// selection colours in the API key field or other native text controls.
private final class ModelCell: NSTextFieldCell {
    private lazy var editor: NSTextView = {
        let view = NSTextView()
        view.isFieldEditor = true
        return view
    }()

    override func fieldEditor(for controlView: NSView) -> NSTextView? { editor }

    override func setUpFieldEditorAttributes(_ textObj: NSText) -> NSText {
        let configured = super.setUpFieldEditorAttributes(textObj)
        if let view = configured as? NSTextView {
            view.insertionPointColor = .labelColor
            view.selectedTextAttributes = [
                .foregroundColor: NSColor.labelColor,
                .backgroundColor: NSColor(name: nil) { appearance in
                    let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    return NSColor(white: dark ? 0.38 : 0.78, alpha: 1)
                }
            ]
        }
        return configured
    }
}

struct ModelIDField: NSViewRepresentable {
    @Binding var text: String
    @Binding var editing: Bool

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var field: ModelIDField
        init(_ field: ModelIDField) { self.field = field }
        func controlTextDidChange(_ note: Notification) {
            if let input = note.object as? NSTextField { field.text = input.stringValue }
        }
        func controlTextDidBeginEditing(_ note: Notification) { field.editing = true }
        func controlTextDidEndEditing(_ note: Notification) { field.editing = false }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.cell = ModelCell(textCell: "")
        field.isEditable = true
        field.isSelectable = true
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.placeholderString = "Claude 模型 ID"
        field.setAccessibilityLabel("模型 ID")
        field.delegate = context.coordinator
        field.cell?.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.field = self
        if field.stringValue != text { field.stringValue = text }
    }
}
