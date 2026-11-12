import ServiceManagement
import SwiftUI

struct ContentView: View {
    @ObservedObject var guardian = AudioGuard.shared
    @State private var loginItem = LoginItem.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: guardian.enabled ? "lock.shield.fill" : "pause.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(guardian.enabled ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L(guardian.enabled ? "ui.title.on" : "ui.title.off"))
                        .font(.headline)
                    Text(L("ui.subtitle"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $guardian.enabled).toggleStyle(.switch).labelsHidden()
                    .help(L(guardian.enabled ? "dock.pause" : "dock.resume"))
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    row(.input, protect: $guardian.protectInput)
                    Divider()
                    row(.output, protect: $guardian.protectOutput)
                }
                .padding(6)
            }

            HStack {
                Toggle(L("ui.openAtLogin"), isOn: $loginItem)
                    .onChange(of: loginItem) { _, value in
                        let real = LoginItem.set(value)
                        if real != value { loginItem = real }
                    }
                Spacer()
                Text(L("ui.revertCount", guardian.revertCount))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Text(L("ui.history")).font(.subheadline.bold())
            List(guardian.log) { entry in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.date, format: .dateTime.hour().minute().second())
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Text(entry.text).font(.caption).textSelection(.enabled)
                }
            }
            .listStyle(.bordered)
            .frame(minHeight: 140)
        }
        .padding(18)
        .frame(minWidth: 520, minHeight: 460)
    }

    @ViewBuilder
    private func row(_ scope: AudioScope, protect: Binding<Bool>) -> some View {
        let options = guardian.devices.filter { $0.supports(scope) }
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(scope.label, systemImage: scope == .input ? "mic.fill" : "speaker.wave.2.fill")
                    .font(.body.bold())
                Spacer()
                Toggle(L("ui.keepFixed"), isOn: protect)
                    .disabled(!guardian.enabled)
            }
            Picker(L("ui.preferred"), selection: Binding(
                get: { guardian.preferred[scope] ?? "" },
                set: { guardian.choose($0, for: scope) }
            )) {
                if guardian.preferred[scope] == nil { Text("—").tag("") }
                if let p = guardian.preferred[scope], !options.contains(where: { $0.uid == p }) {
                    Text(L("ui.disconnected", guardian.name(p))).tag(p)
                }
                ForEach(options) { d in Text(d.name).tag(d.uid) }
            }
            if guardian.current[scope] != guardian.preferred[scope] {
                Text(L("ui.inUseNow", guardian.name(guardian.current[scope])))
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }
}

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns the real state after the attempt.
    static func set(_ on: Bool) -> Bool {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            AudioGuard.shared.note(L("log.loginError", error.localizedDescription))
        }
        if on, SMAppService.mainApp.status == .requiresApproval {
            AudioGuard.shared.note(L("log.loginApproval"))
            SMAppService.openSystemSettingsLoginItems()
        }
        return isEnabled
    }
}
