// Renders the settings window with demo data for the docs.
// Run by Tools/screenshot/run.sh (the binary must live inside an app bundle so the
// localizations resolve):  screenshot <out.png> <light|dark> -AppleLanguages "(en)"
import AppKit
import SwiftUI

let out = URL(fileURLWithPath: CommandLine.arguments[1])
let dark = CommandLine.arguments[2] == "dark"
let size = NSSize(width: 560, height: 500)
let scale: CGFloat = 2

/// Key + active window so controls render in their active (colored) state.
final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
AudioGuard.shared.loadDemo()

let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
let window = KeyWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless],
                      backing: .buffered, defer: false)
window.appearance = appearance
let host = NSHostingView(rootView: ContentView().environment(\.controlActiveState, .key))
host.frame = NSRect(origin: .zero, size: size)
window.contentView = host
host.layoutSubtreeIfNeeded()
window.setFrameOrigin(NSPoint(x: -20000, y: -20000)) // off-screen
window.orderFrontRegardless()
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
RunLoop.main.run(until: Date().addingTimeInterval(1.5))

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
                           pixelsHigh: Int(size.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = size
host.cacheDisplay(in: host.bounds, to: rep)

// Window background of macOS 14+ (dynamic colors don't resolve reliably off-screen).
let background = dark ? NSColor(calibratedWhite: 0.157, alpha: 1) : NSColor(calibratedWhite: 0.925, alpha: 1)
let final = NSImage(size: size)
final.lockFocus()
background.setFill()
NSRect(origin: .zero, size: size).fill()
rep.draw(in: NSRect(origin: .zero, size: size))
final.unlockFocus()

let outRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
                              pixelsHigh: Int(size.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                              hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
outRep.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: outRep)
final.draw(in: NSRect(origin: .zero, size: size))
NSGraphicsContext.restoreGraphicsState()
try outRep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote \(out.path)")
