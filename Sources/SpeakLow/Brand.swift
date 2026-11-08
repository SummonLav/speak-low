import AppKit

@MainActor
enum Brand {
    static let charcoal = NSColor(srgbRed: 32/255, green: 32/255, blue: 32/255, alpha: 1)
    static let wordmark = image("speak-low", extension: "svg")
    static let mascot: NSImage = {
        let icon = image("little-oh-template", extension: "png")
            ?? NSImage(systemSymbolName: "text.bubble.fill", accessibilityDescription: nil)!
        icon.size = NSSize(width: 19, height: 19)
        icon.isTemplate = true
        icon.accessibilityDescription = "speak-low"
        return icon
    }()

    private static func image(_ name: String, extension fileExtension: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Brand") else { return nil }
        return NSImage(contentsOf: url)
    }
}
