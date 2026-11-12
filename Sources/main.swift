import AppKit
import Combine
import SwiftUI

/// Menu bar app (LSUIElement): no Dock icon. The status item menu is the main UI; the window
/// (settings + history) opens on demand.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static let showWindowNotification = Notification.Name("br.com.pedroberaldo.FixMacAudioInput.showWindow")

    private var window: NSWindow?
    private var statusItem: NSStatusItem!
    private var cancellables = Set<AnyCancellable>()
    private let guardian = AudioGuard.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
        guardian.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "FixMacAudioInputStatusItem"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        guardian.$enabled.receive(on: RunLoop.main).sink { [weak self] on in self?.updateIcon(on) }
            .store(in: &cancellables)

        // A second launch (Finder, Spotlight) asks this instance to show its window.
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(showWindow), name: Self.showWindowNotification, object: nil)

        // First run ever: show the window once so people know where the app went.
        if !UserDefaults.standard.bool(forKey: "launchedBefore") {
            UserDefaults.standard.set(true, forKey: "launchedBefore")
            showWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    private func updateIcon(_ on: Bool) {
        let image = NSImage(systemSymbolName: on ? "mic.fill" : "mic.slash",
                            accessibilityDescription: "FixMacAudioInput")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = "FixMacAudioInput — " + L(on ? "ui.title.on" : "ui.title.off")
    }

    // MARK: - Status menu (rebuilt every time it opens, so it is always current)

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let g = guardian

        let header = NSMenuItem(title: L(g.enabled ? "ui.title.on" : "ui.title.off"), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(item(L(g.enabled ? "action.pause" : "action.resume"), #selector(toggleEnabled)))

        for scope in AudioScope.allCases {
            menu.addItem(.separator())
            menu.addItem(.sectionHeader(title: scope.label))
            let pref = g.preferred[scope]
            let options = g.devices.filter { $0.supports(scope) }
            for d in options {
                let it = item(d.name, #selector(chooseDevice(_:)))
                it.representedObject = [scope.rawValue, d.uid]
                it.state = d.uid == pref ? .on : .off
                menu.addItem(it)
            }
            if let pref, !options.contains(where: { $0.uid == pref }) {
                let it = NSMenuItem(title: L("ui.disconnected", g.name(pref)), action: nil, keyEquivalent: "")
                it.state = .on
                it.isEnabled = false
                menu.addItem(it)
            }
            let fixed = item(L("ui.keepFixed"), #selector(toggleFixed(_:)))
            fixed.representedObject = scope.rawValue
            fixed.state = (scope == .input ? g.protectInput : g.protectOutput) ? .on : .off
            fixed.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)
            if !g.enabled { fixed.action = nil }
            menu.addItem(fixed)
        }

        menu.addItem(.separator())
        let count = NSMenuItem(title: L("ui.revertCount", g.revertCount), action: nil, keyEquivalent: "")
        count.isEnabled = false
        menu.addItem(count)
        menu.addItem(item(L("menu.showWindow"), #selector(showWindow), key: ","))
        let login = item(L("ui.openAtLogin"), #selector(toggleLogin))
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(item(L("menu.quit"), #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))
    }

    private func item(_ title: String, _ action: Selector, key: String = "", target: AnyObject? = nil) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
        it.target = target ?? self
        return it
    }

    @objc private func toggleEnabled() { guardian.enabled.toggle() }

    @objc private func toggleFixed(_ sender: NSMenuItem) {
        if sender.representedObject as? String == AudioScope.input.rawValue {
            guardian.protectInput.toggle()
        } else {
            guardian.protectOutput.toggle()
        }
    }

    @objc private func chooseDevice(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? [String], pair.count == 2,
              let scope = AudioScope(rawValue: pair[0]) else { return }
        guardian.choose(pair[1], for: scope)
    }

    @objc private func toggleLogin() { _ = LoginItem.set(!LoginItem.isEnabled) }

    // MARK: - Window

    @objc func showWindow() {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            w.title = "FixMacAudioInput"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: ContentView())
            w.setFrameAutosaveName("MainWindow")
            if !w.setFrameUsingName("MainWindow") { w.center() }
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Hidden main menu: invisible for a menu bar app, but keeps ⌘W/⌘M/⌘Q/⌘C working in the window.
    private func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        main.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu

        let windowItem = NSMenuItem()
        main.addItem(windowItem)
        let windowMenu = NSMenu(title: L("menu.window"))
        windowMenu.addItem(withTitle: L("menu.close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: L("menu.minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        NSApp.mainMenu = main
    }
}

// Single instance: two guards fighting over the same device would double-log and race.
// A second launch tells the running one to show its window, then exits.
if let bundleID = Bundle.main.bundleIdentifier,
   NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
       .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
    DistributedNotificationCenter.default().postNotificationName(
        AppDelegate.showWindowNotification, object: nil, userInfo: nil, deliverImmediately: true)
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
