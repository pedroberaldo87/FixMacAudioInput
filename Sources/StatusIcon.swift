import AppKit

/// FixMacAudioInput's own glyph: a mic capsule held by an anchor ("the mic stays put").
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

    /// Draws the glyph into the current graphics context, scaled to the 18 × 18 canvas.
    static func draw(paused: Bool, color: NSColor) {
        color.setFill()
        color.setStroke()
        NSBezierPath(roundedRect: NSRect(x: 6, y: 9.5, width: 6, height: 8), xRadius: 3, yRadius: 3).fill()

        let stem = NSBezierPath()
        stem.lineWidth = 1.6
        stem.lineCapStyle = .round
        stem.move(to: NSPoint(x: 9, y: 9.5)); stem.line(to: NSPoint(x: 9, y: 1.6))
        stem.move(to: NSPoint(x: 6.5, y: 7.2)); stem.line(to: NSPoint(x: 11.5, y: 7.2))
        stem.stroke()

        let arc = NSBezierPath()
        arc.lineWidth = 1.6
        arc.lineCapStyle = .round
        arc.appendArc(withCenter: NSPoint(x: 9, y: 6.4), radius: 5.6, startAngle: 200, endAngle: 340)
        arc.stroke()

        for (tip, dx) in [(NSPoint(x: 3.7, y: 4.5), 1.0), (NSPoint(x: 14.3, y: 4.5), -1.0)] {
            let t = NSBezierPath()
            t.move(to: NSPoint(x: tip.x - 1.2 * dx, y: tip.y + 2.2))
            t.line(to: NSPoint(x: tip.x + 0.4 * dx, y: tip.y - 0.4))
            t.line(to: NSPoint(x: tip.x + 2.4 * dx, y: tip.y + 1.0))
            t.close()
            t.fill()
        }

        if paused {
            NSGraphicsContext.current?.compositingOperation = .clear
            let gap = NSBezierPath()
            gap.lineWidth = 4
            gap.move(to: NSPoint(x: 2, y: 16)); gap.line(to: NSPoint(x: 16, y: 2))
            gap.stroke()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            let slash = NSBezierPath()
            slash.lineWidth = 1.6
            slash.lineCapStyle = .round
            slash.move(to: NSPoint(x: 2.5, y: 15.5)); slash.line(to: NSPoint(x: 15.5, y: 2.5))
            slash.stroke()
        }
    }
}
