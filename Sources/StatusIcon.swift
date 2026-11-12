import AppKit

/// FixMacAudioInput's own glyph: a microphone with a small padlock ("the mic is locked in").
/// Drawn in code so it stays crisp at any scale. Canvas: 18 × 18, origin bottom-left.
enum StatusIcon {
    /// Template image for the menu bar (macOS tints it for light/dark menu bars).
    static func image(paused: Bool) -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            draw(paused: paused, color: .black)
            return true
        }
        img.isTemplate = true
        return img
    }

    // Padlock geometry (bottom-right corner).
    private static let lockBody = NSRect(x: 11, y: 0.8, width: 6, height: 5.2)
    private static let shackleCenter = NSPoint(x: 14, y: 6)
    private static let shackleRadius: CGFloat = 1.8

    /// Draws the glyph into the current graphics context, scaled to the 18 × 18 canvas.
    static func draw(paused: Bool, color: NSColor) {
        color.setFill()
        color.setStroke()

        // Microphone: capsule, cradle, stem, base.
        NSBezierPath(roundedRect: NSRect(x: 3.5, y: 8.5, width: 6, height: 9), xRadius: 3, yRadius: 3).fill()
        let stand = NSBezierPath()
        stand.lineWidth = 1.5
        stand.lineCapStyle = .round
        stand.appendArc(withCenter: NSPoint(x: 6.5, y: 11.5), radius: 4.5, startAngle: 180, endAngle: 360)
        stand.move(to: NSPoint(x: 6.5, y: 7)); stand.line(to: NSPoint(x: 6.5, y: 3))
        stand.move(to: NSPoint(x: 4, y: 3)); stand.line(to: NSPoint(x: 9, y: 3))
        stand.stroke()

        // Thin transparent halo around the padlock so it reads as a separate badge.
        NSGraphicsContext.current?.compositingOperation = .clear
        NSBezierPath(roundedRect: lockBody.insetBy(dx: -1.2, dy: -1.2), xRadius: 2, yRadius: 2).fill()
        let halo = shackle()
        halo.lineWidth = 3.7
        halo.stroke()
        NSGraphicsContext.current?.compositingOperation = .sourceOver

        // Padlock: body + shackle + keyhole.
        NSBezierPath(roundedRect: lockBody, xRadius: 1.1, yRadius: 1.1).fill()
        let s = shackle()
        s.lineWidth = 1.3
        s.stroke()
        NSGraphicsContext.current?.compositingOperation = .clear
        NSBezierPath(ovalIn: NSRect(x: 13.4, y: 2.7, width: 1.2, height: 1.2)).fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver

        if paused {
            NSGraphicsContext.current?.compositingOperation = .clear
            let gap = NSBezierPath()
            gap.lineWidth = 4
            gap.move(to: NSPoint(x: 1.5, y: 17)); gap.line(to: NSPoint(x: 12, y: 6.5))
            gap.stroke()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            let slash = NSBezierPath()
            slash.lineWidth = 1.5
            slash.lineCapStyle = .round
            slash.move(to: NSPoint(x: 2, y: 16.5)); slash.line(to: NSPoint(x: 11.5, y: 7))
            slash.stroke()
        }
    }

    private static func shackle() -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: shackleCenter.x - shackleRadius, y: lockBody.maxY - 0.2))
        p.appendArc(withCenter: shackleCenter, radius: shackleRadius, startAngle: 180, endAngle: 0, clockwise: true)
        p.line(to: NSPoint(x: shackleCenter.x + shackleRadius, y: lockBody.maxY - 0.2))
        return p
    }
}
