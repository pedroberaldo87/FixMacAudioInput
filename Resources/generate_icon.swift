// Renders AppIcon.iconset (mic + lock). Usage: swift generate_icon.swift <out.iconset>
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

    func symbol(_ name: String, _ pt: CGFloat, _ origin: NSPoint) {
        let cfg = NSImage.SymbolConfiguration(pointSize: pt, weight: .semibold)
            .applying(.init(paletteColors: [.white]))
        guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg) else { return }
        img.draw(in: NSRect(origin: origin, size: img.size))
    }
    symbol("mic.fill", s * 0.42, NSPoint(x: s * 0.27, y: s * 0.26))
    symbol("lock.fill", s * 0.20, NSPoint(x: s * 0.58, y: s * 0.18))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (base, scales) in [(16, [1, 2]), (32, [1, 2]), (128, [1, 2]), (256, [1, 2]), (512, [1, 2])] {
    for sc in scales {
        let name = sc == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! render(base * sc).write(to: out.appendingPathComponent(name))
    }
}
