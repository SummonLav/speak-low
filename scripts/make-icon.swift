import AppKit
let iconset = URL(fileURLWithPath: CommandLine.arguments[1])
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(pixels) / 128)
        transform.concat()
        let tile = NSBezierPath(roundedRect: NSRect(x: 7, y: 7, width: 114, height: 114), xRadius: 27, yRadius: 27)
        NSGradient(starting: NSColor(srgbRed: 0.04, green: 0.34, blue: 0.38, alpha: 1),
                   ending: NSColor(srgbRed: 0.06, green: 0.19, blue: 0.23, alpha: 1))!.draw(in: tile, angle: -75)
        NSColor(srgbRed: 0.74, green: 0.98, blue: 0.85, alpha: 1).setFill()
        for (index, h) in [18, 40, 63, 47, 25].enumerated() {
            NSBezierPath(roundedRect: NSRect(x: 30 + CGFloat(index) * 15, y: 64 - CGFloat(h)/2,
                                            width: 8, height: CGFloat(h)), xRadius: 4, yRadius: 4).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
