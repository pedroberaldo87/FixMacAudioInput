// End-to-end check: simulates "a new device is plugged in and macOS switches to it".
// Creates a public aggregate device (the whole system sees it as a brand-new device),
// makes it the default right away — exactly what macOS does with headphones — and checks
// whether the running FixMacAudioInput app switched back.
//
// Usage: simulate_plug <input|output> <auto|manual>
//   auto   -> switch right after connecting: the app MUST undo it.
//   manual -> switch 10 s after connecting (a human choice): the app must NOT undo it.
//
// For `output`, launch the app with output protection on:
//   open build/FixMacAudioInput.app --args -protectOutput YES
import CoreAudio
import Foundation

let args = CommandLine.arguments
guard args.count == 3, let scope = AudioScope(rawValue: args[1]), ["auto", "manual"].contains(args[2]) else {
    print("usage: simulate_plug <input|output> <auto|manual>"); exit(2)
}
let manual = args[2] == "manual"

func uid(_ id: AudioDeviceID?) -> String { id.flatMap { CoreAudio.string($0, kAudioDevicePropertyDeviceUID) } ?? "nil" }
func nameOf(_ id: AudioDeviceID?) -> String { id.flatMap { CoreAudio.string($0, kAudioObjectPropertyName) } ?? "nil" }

let originalID = CoreAudio.defaultDevice(scope)
let originalSys = CoreAudio.defaultDeviceID(kAudioHardwarePropertyDefaultSystemOutputDevice)
print("current default (\(scope.rawValue)): \(nameOf(originalID))")

// Sub-device: any real device for this scope that is NOT the current default (built-in first).
let candidates = CoreAudio.devices().filter { $0.supports(scope) && $0.id != originalID && !$0.uid.hasPrefix("fmai-test") }
guard let sub = candidates.first(where: { CoreAudio.uint32($0.id, kAudioDevicePropertyTransportType) == kAudioDeviceTransportTypeBuiltIn }) ?? candidates.first else {
    print("SKIP: no alternative \(scope.rawValue) device"); exit(3)
}

let aggUID = "fmai-test-\(UUID().uuidString.prefix(8))"
let desc: [String: Any] = [
    kAudioAggregateDeviceNameKey: "FMAI Test Headphones",
    kAudioAggregateDeviceUIDKey: aggUID,
    kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: sub.uid]],
    kAudioAggregateDeviceMainSubDeviceKey: sub.uid,
    kAudioAggregateDeviceIsPrivateKey: 0,
]
var agg: AudioObjectID = 0
let st = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &agg)
guard st == noErr else { print("FAIL: create aggregate OSStatus \(st)"); exit(1) }
print("\"connected\": FMAI Test Headphones (sub: \(sub.name))")

func cleanup() {
    if let o = originalID, CoreAudio.defaultDevice(scope) != o { CoreAudio.setDefault(scope.defaultSelector, to: o) }
    if scope == .output, let s = originalSys { CoreAudio.setDefault(kAudioHardwarePropertyDefaultSystemOutputDevice, to: s) }
    Thread.sleep(forTimeInterval: 0.5)
    AudioHardwareDestroyAggregateDevice(agg)
}

Thread.sleep(forTimeInterval: manual ? 10 : 0.3)
CoreAudio.setDefault(scope.defaultSelector, to: agg)
if scope == .output { CoreAudio.setDefault(kAudioHardwarePropertyDefaultSystemOutputDevice, to: agg) }
print("switched default to the aggregate (\(manual ? "manual, 10 s after connecting" : "automatic, 0.3 s after connecting"))")

Thread.sleep(forTimeInterval: 2.5)
let after = CoreAudio.defaultDevice(scope)
let afterSys = CoreAudio.defaultDeviceID(kAudioHardwarePropertyDefaultSystemOutputDevice)
print("default after 2.5 s: \(nameOf(after))" + (scope == .output ? " · sound effects: \(nameOf(afterSys))" : ""))

var ok: Bool
if manual {
    ok = after == agg
    print(ok ? "PASS: manual choice respected" : "FAIL: app undid a manual choice")
} else {
    ok = after == originalID
    if scope == .output { ok = ok && afterSys != agg }
    print(ok ? "PASS: automatic switch undone" : "FAIL: stayed on the new device")
}
cleanup()
print("restored: \(nameOf(CoreAudio.defaultDevice(scope)))")
exit(ok ? 0 : 1)
