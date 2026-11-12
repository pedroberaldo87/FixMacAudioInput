import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        AudioGuard.shared.start()

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "FixMacAudioInput"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ContentView())
        window.setFrameAutosaveName("MainWindow")
        if !window.setFrameUsingName("MainWindow") { window.center() }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // Closing the window does not quit: the app keeps guarding and stays in the Dock.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let g = AudioGuard.shared
        let toggle = NSMenuItem(title: L(g.enabled ? "dock.pause" : "dock.resume"),
                                action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())
        menu.addItem(withTitle: L("dock.input", g.name(g.preferred[.input])), action: nil, keyEquivalent: "")
        menu.addItem(withTitle: L("dock.output", g.name(g.preferred[.output])), action: nil, keyEquivalent: "")
        return menu
    }

    @objc private func toggleEnabled() { AudioGuard.shared.enabled.toggle() }

    @objc func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("menu.showWindow"), action: #selector(showWindow), keyEquivalent: "0").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("menu.hide"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let windowItem = NSMenuItem()
        main.addItem(windowItem)
        let windowMenu = NSMenu(title: L("menu.window"))
        windowMenu.addItem(withTitle: L("menu.close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: L("menu.minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
    }
}

// Single instance: two guards fighting over the same device would double-log and race.
if let bundleID = Bundle.main.bundleIdentifier,
   let other = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
       .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
    other.activate()
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
