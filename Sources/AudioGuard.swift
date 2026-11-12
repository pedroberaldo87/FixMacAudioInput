import CoreAudio
import Foundation

struct LogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let text: String
}

/// Core of the app: watches CoreAudio and undoes automatic device switches caused by a
/// freshly connected device (headphones, headset, USB dongle, AirPods...).
///
/// Rules:
/// - Default switches to a device that appeared less than `newDeviceWindow` seconds ago
///   -> automatic macOS switch -> go back to the preferred device.
/// - Default switches to a device that was already there -> your choice -> new preferred.
/// - Preferred device disconnects -> macOS falls back to something else; the preference is
///   kept and restored when the device comes back.
final class AudioGuard: ObservableObject {
    static let shared = AudioGuard()

    /// Window in which a switch to a freshly connected device counts as automatic.
    let newDeviceWindow: TimeInterval = 8

    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var current: [AudioScope: String] = [:]
    @Published private(set) var preferred: [AudioScope: String] = [:]
    @Published private(set) var log: [LogEntry] = []
    @Published private(set) var revertCount = 0

    @Published var enabled: Bool {
        didSet {
            defaults.set(enabled, forKey: "enabled")
            note(L(enabled ? "log.enabled" : "log.paused"))
            resyncPreferred()
        }
    }
    @Published var protectInput: Bool {
        didSet { defaults.set(protectInput, forKey: "protectInput"); resyncPreferred() }
    }
    @Published var protectOutput: Bool {
        didSet { defaults.set(protectOutput, forKey: "protectOutput"); resyncPreferred() }
    }

    private let defaults = UserDefaults.standard
    private var firstSeen: [String: Date] = [:]
    private var removedAt: [String: Date] = [:]
    private var names: [String: String] = [:]
    private var listeners: [AudioObjectPropertyListenerBlock] = []
    private let logURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("FixMacAudioInput.log")
    }()

    private init() {
        defaults.register(defaults: ["enabled": true, "protectInput": true, "protectOutput": false])
        enabled = defaults.bool(forKey: "enabled")
        protectInput = defaults.bool(forKey: "protectInput")
        protectOutput = defaults.bool(forKey: "protectOutput")
    }

    func isProtecting(_ scope: AudioScope) -> Bool {
        enabled && (scope == .input ? protectInput : protectOutput)
    }

    func start() {
        let list = CoreAudio.devices()
        devices = list
        for d in list { firstSeen[d.uid] = .distantPast; names[d.uid] = d.name }
        for scope in AudioScope.allCases {
            let uid = currentUID(scope)
            current[scope] = uid
            preferred[scope] = uid
        }
        note(L("log.started",
               name(preferred[.input]), L(isProtecting(.input) ? "state.fixed" : "state.free"),
               name(preferred[.output]), L(isProtecting(.output) ? "state.fixed" : "state.free")))

        listen(kAudioHardwarePropertyDevices) { [weak self] in self?.devicesChanged() }
        listen(kAudioHardwarePropertyDefaultInputDevice) { [weak self] in self?.defaultChanged(.input) }
        listen(kAudioHardwarePropertyDefaultOutputDevice) { [weak self] in self?.defaultChanged(.output) }
        listen(kAudioHardwarePropertyDefaultSystemOutputDevice) { [weak self] in self?.systemOutputChanged() }
    }

    // MARK: - User actions (UI)

    /// Explicit choice made in the app window: becomes preferred immediately.
    func choose(_ uid: String, for scope: AudioScope) {
        guard let dev = devices.first(where: { $0.uid == uid }) else { return }
        preferred[scope] = uid
        CoreAudio.setDefault(scope.defaultSelector, to: dev.id)
        if scope == .output { CoreAudio.setDefault(kAudioHardwarePropertyDefaultSystemOutputDevice, to: dev.id) }
        note(L("log.appChosen.\(scope.rawValue)", dev.name))
    }

    // MARK: - CoreAudio events

    private func listen(_ selector: AudioObjectPropertySelector, _ block: @escaping () -> Void) {
        listeners.append(CoreAudio.listen(selector, block))
    }

    /// Refreshes the device list and the "first seen" map. Idempotent.
    @discardableResult
    private func refreshDevices() -> (added: [AudioDevice], removed: [AudioDevice]) {
        let now = Date()
        let list = CoreAudio.devices()
        let newUIDs = Set(list.map(\.uid))
        let added = list.filter { firstSeen[$0.uid] == nil }
        let removed = devices.filter { !newUIDs.contains($0.uid) }
        for d in added { firstSeen[d.uid] = now; removedAt[d.uid] = nil }
        for d in removed { firstSeen[d.uid] = nil; removedAt[d.uid] = now }
        for d in list { names[d.uid] = d.name }
        devices = list
        return (added, removed)
    }

    private func isFresh(_ uid: String, now: Date = Date()) -> Bool {
        firstSeen[uid].map { now.timeIntervalSince($0) < newDeviceWindow } ?? false
    }

    private func devicesChanged() {
        let (added, removed) = refreshDevices()
        for d in added { note(L("log.connected", d.name)) }
        for d in removed { note(L("log.disconnected", d.name)) }

        // Preferred device came back (e.g. USB mic re-plugged) while default is elsewhere -> restore.
        for scope in AudioScope.allCases where isProtecting(scope) {
            guard let pref = preferred[scope], added.contains(where: { $0.uid == pref }),
                  currentUID(scope) != pref else { continue }
            // Short delay: let macOS finish its own switching first.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, self.isProtecting(scope), self.preferred[scope] == pref,
                      self.currentUID(scope) != pref else { return }
                self.apply(pref, scope: scope, logKey: "log.restored.\(scope.rawValue)", replaced: nil)
            }
        }
    }

    private func defaultChanged(_ scope: AudioScope) {
        refreshDevices() // the default switch may arrive before the device-list notification
        let previous = current[scope]
        let uid = currentUID(scope)
        current[scope] = uid
        guard let uid, uid != preferred[scope] else { return }

        guard isProtecting(scope) else {
            preferred[scope] = uid
            return
        }

        let now = Date()
        let fresh = isFresh(uid, now: now)
        let prefUID = preferred[scope]
        let prefPresent = prefUID.flatMap(device(uid:))?.supports(scope) ?? false

        if fresh && prefPresent, let prefUID {
            apply(prefUID, scope: scope, logKey: "log.reverted.\(scope.rawValue)", replaced: uid)
            return
        }

        // Preferred is absent, but something else was in use before the automatic switch:
        // go back to it without touching the preference.
        if fresh, let previous, previous != uid, device(uid: previous)?.supports(scope) == true {
            apply(previous, scope: scope, logKey: "log.reverted.\(scope.rawValue)", replaced: uid)
            return
        }

        if !prefPresent, let prefUID, let gone = removedAt[prefUID], now.timeIntervalSince(gone) < newDeviceWindow {
            note(L("log.prefGone.\(scope.rawValue)", name(prefUID), name(uid)))
            return
        }

        preferred[scope] = uid
        note(L("log.chosen.\(scope.rawValue)", name(uid)))
    }

    /// "Play sound effects through" also jumps to new devices. It follows the output rule but
    /// never changes the preference.
    private func systemOutputChanged() {
        guard isProtecting(.output) else { return }
        refreshDevices()
        guard let sysID = CoreAudio.defaultDeviceID(kAudioHardwarePropertyDefaultSystemOutputDevice),
              let sysUID = CoreAudio.string(sysID, kAudioDevicePropertyDeviceUID),
              isFresh(sysUID),
              let target = (preferred[.output].flatMap(device(uid:)) ?? current[.output].flatMap(device(uid:))),
              target.uid != sysUID, target.hasOutput else { return }
        if CoreAudio.setDefault(kAudioHardwarePropertyDefaultSystemOutputDevice, to: target.id) == noErr {
            note(L("log.systemOutput", name(sysUID), target.name))
        }
    }

    private func apply(_ uid: String, scope: AudioScope, logKey: String, replaced: String?) {
        guard let dev = device(uid: uid) else { return }
        let status = CoreAudio.setDefault(scope.defaultSelector, to: dev.id)
        if scope == .output,
           let sys = CoreAudio.defaultDeviceID(kAudioHardwarePropertyDefaultSystemOutputDevice),
           sys != dev.id, let sysUID = CoreAudio.string(sys, kAudioDevicePropertyDeviceUID),
           sysUID == replaced || isFresh(sysUID) {
            CoreAudio.setDefault(kAudioHardwarePropertyDefaultSystemOutputDevice, to: dev.id)
        }
        current[scope] = currentUID(scope)
        if status == noErr {
            revertCount += 1
            note(replaced.map { L(logKey, name($0), dev.name) } ?? L(logKey, dev.name))
        } else {
            note(L("log.failed.\(scope.rawValue)", dev.name, Int(status)))
        }
    }

    /// When protection is toggled, whatever is in use becomes the preference.
    private func resyncPreferred() {
        guard !current.isEmpty else { return }
        for scope in AudioScope.allCases {
            if let uid = currentUID(scope) { preferred[scope] = uid; current[scope] = uid }
        }
    }

    // MARK: - Helpers

    func currentUID(_ scope: AudioScope) -> String? {
        CoreAudio.defaultDevice(scope).flatMap { CoreAudio.string($0, kAudioDevicePropertyDeviceUID) }
    }

    func device(uid: String) -> AudioDevice? {
        devices.first { $0.uid == uid } ?? CoreAudio.devices().first { $0.uid == uid }
    }

    func name(_ uid: String?) -> String {
        guard let uid else { return "—" }
        return device(uid: uid)?.name ?? names[uid] ?? uid
    }

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    func note(_ text: String) {
        let entry = LogEntry(date: Date(), text: text)
        log.insert(entry, at: 0)
        if log.count > 200 { log.removeLast(log.count - 200) }
        let line = "\(Self.stamp.string(from: entry.date)) \(text)\n"
        if let h = try? FileHandle(forWritingTo: logURL) {
            h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close()
        } else {
            try? Data(line.utf8).write(to: logURL)
        }
    }
}
