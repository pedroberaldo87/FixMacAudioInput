import CoreAudio
import Foundation

/// Audio direction the app protects.
enum AudioScope: String, CaseIterable, Codable {
    case input
    case output

    var label: String { L("scope.\(rawValue)") }

    var streamScope: AudioObjectPropertyScope {
        self == .input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput
    }

    var defaultSelector: AudioObjectPropertySelector {
        self == .input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
    }
}

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let hasInput: Bool
    let hasOutput: Bool

    func supports(_ scope: AudioScope) -> Bool {
        scope == .input ? hasInput : hasOutput
    }
}

/// Thin, stateless wrapper over the CoreAudio C API.
enum CoreAudio {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    static func address(_ selector: AudioObjectPropertySelector,
                        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func deviceIDs() -> [AudioDeviceID] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    static func uint32(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector,
                       scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> UInt32? {
        var addr = address(selector, scope: scope)
        guard AudioObjectHasProperty(id, &addr) else { return nil }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    static func hasStreams(_ id: AudioDeviceID, scope: AudioScope) -> Bool {
        var addr = address(kAudioDevicePropertyStreams, scope: scope.streamScope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr else { return false }
        return size > 0
    }

    static func device(_ id: AudioDeviceID) -> AudioDevice? {
        guard let uid = string(id, kAudioDevicePropertyDeviceUID) else { return nil }
        if uint32(id, kAudioDevicePropertyIsHidden) == 1 { return nil }
        let name = string(id, kAudioObjectPropertyName) ?? uid
        return AudioDevice(id: id, uid: uid, name: name,
                           hasInput: hasStreams(id, scope: .input),
                           hasOutput: hasStreams(id, scope: .output))
    }

    static func devices() -> [AudioDevice] {
        deviceIDs().compactMap(device)
    }

    static func defaultDeviceID(_ selector: AudioObjectPropertySelector) -> AudioDeviceID? {
        guard let v = uint32(system, selector), v != kAudioObjectUnknown else { return nil }
        return v
    }

    static func defaultDevice(_ scope: AudioScope) -> AudioDeviceID? {
        defaultDeviceID(scope.defaultSelector)
    }

    @discardableResult
    static func setDefault(_ selector: AudioObjectPropertySelector, to id: AudioDeviceID) -> OSStatus {
        var addr = address(selector)
        var value = id
        return AudioObjectSetPropertyData(system, &addr, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &value)
    }

    /// Registers a listener on the system object. Returns the block so callers can keep it alive.
    static func listen(_ selector: AudioObjectPropertySelector,
                       queue: DispatchQueue = .main,
                       _ block: @escaping () -> Void) -> AudioObjectPropertyListenerBlock {
        var addr = address(selector)
        let listener: AudioObjectPropertyListenerBlock = { _, _ in block() }
        AudioObjectAddPropertyListenerBlock(system, &addr, queue, listener)
        return listener
    }
}
