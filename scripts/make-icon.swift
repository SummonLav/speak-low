import AppKit

// Build all square icons from the approved mascot in the repository wordmark.
let iconset = URL(fileURLWithPath: CommandLine.arguments[1])
let brand = URL(fileURLWithPath: CommandLine.arguments[2])
let logo = try XMLDocument(contentsOf: brand.appendingPathComponent("speak-low.svg"), options: [])
guard let face = try logo.nodes(forXPath: "//*[@id='little-oh']").first as? XMLElement else {
    fatalError("Missing little-oh in the brand SVG")
}
face.removeAttribute(forName: "transform") // Remove the placement in the horizontal wordmark.

func vector(viewBox: String, background: String = "") -> NSImage {
    let svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="\(viewBox)">
    \(background)\(face.xmlString)
    </svg>
    """
    return NSImage(data: Data(svg.utf8))!
}

func render(_ image: NSImage, pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero,
               operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let tile = ##"<rect x="-16" y="-25" width="152" height="152" rx="36" fill="#202020"/>"##
let appIcon = vector(viewBox: "-25 -34 170 170", background: tile)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let name = "icon_\(size)x\(size)\(suffix).png"
        try render(appIcon, pixels: size * scale).representation(using: .png, properties: [:])!
            .write(to: iconset.appendingPathComponent(name))
    }
}

// macOS tints a template using its alpha channel. Punch out the eyes and mouth.
let mask = render(vector(viewBox: "-5 -14 132 132"), pixels: 72)
for y in 0..<mask.pixelsHigh {
    for x in 0..<mask.pixelsWide {
        var rgba = [Int](repeating: 0, count: 4)
        mask.getPixel(&rgba, atX: x, y: y)
        let alpha = min(rgba[3], max(0, (rgba[0] * 255 - 25 * rgba[3]) / 225))
        rgba = [0, 0, 0, alpha]
        mask.setPixel(&rgba, atX: x, y: y)
    }
}
try mask.representation(using: .png, properties: [:])!
    .write(to: brand.appendingPathComponent("little-oh-template.png"))
