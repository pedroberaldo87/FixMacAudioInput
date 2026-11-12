// Renders AppIcon.iconset from the same mic-with-padlock glyph used in the menu bar.
// Built by build.sh together with Sources/StatusIcon.swift: generate_icon <out.iconset>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = s * 0.1
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let bg = NSBezierPath(roundedRect: rect, xRadius: s * 0.18, yRadius: s * 0.18)
    NSGradient(starting: NSColor(calibratedRed: 0.13, green: 0.55, blue: 0.42, alpha: 1),
               ending: NSColor(calibratedRed: 0.05, green: 0.25, blue: 0.30, alpha: 1))!.draw(in: bg, angle: -90)

    // Glyph occupies ~56% of the tile, centered. Rendered on its own transparent layer first:
    // the glyph's knockout halo must not punch through the background.
    let g = s * 0.56
    let glyph = NSImage(size: NSSize(width: g, height: g), flipped: false) { _ in
        let t = NSAffineTransform()
        t.scale(by: g / 18)
        t.concat()
        StatusIcon.draw(paused: false, color: .white)
        return true
    }
    glyph.draw(in: NSRect(x: (s - g) / 2, y: (s - g) / 2, width: g, height: g))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    for sc in [1, 2] {
        let name = sc == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! render(base * sc).write(to: out.appendingPathComponent(name))
    }
}
