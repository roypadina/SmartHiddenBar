import ServiceManagement
import SwiftUI

// MARK: Settings (defaults domain com.roypadina.SmartHiddenBar)

func openPane(_ anchor: String) {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!)
}

struct SettingsView: View {
    @AppStorage("autoRehideSeconds") var rehide = 0
    @AppStorage("iconStyle") var iconStyle = "app"
    @AppStorage("iconBarNames") var names = false
    @State var login = SMAppService.mainApp.status == .enabled
    @State var loginStatus = SMAppService.mainApp.status
    @State var axOK = AXIsProcessTrusted()
    @State var screenOK = CGPreflightScreenCaptureAccess()
    @State var asked = false  // Screen Recording already requested once from here: the button opens Settings instead

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $login).onChange(of: login) { _, on in
                    guard on != (SMAppService.mainApp.status == .enabled) else { return }
                    do { try on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
                    catch { log("login item: \(error)") }
                    loginStatus = SMAppService.mainApp.status
                    login = loginStatus == .enabled
                }
                Picker("Auto-rehide after", selection: $rehide) {
                    Text("Never").tag(0)
                    ForEach([5, 10, 30, 60], id: \.self) { Text("\($0) s").tag($0) }
                }
                ForEach(shortcutActions, id: \.key) { ShortcutRow(key: $0.key, label: "\($0.label) shortcut") }
            } header: { Text("General") } footer: {
                if loginStatus == .requiresApproval {
                    HStack {
                        Text("Launch at login needs your approval in Login Items.").foregroundStyle(.secondary)
                        Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                    }
                }
            }
            Section {
                Picker("Icons", selection: $iconStyle) {
                    Text("App icons").tag("app")
                    Text("Real menu bar icons").tag("real")
                }.onChange(of: iconStyle) { _, style in
                    if style == "real", !CGPreflightScreenCaptureAccess() { asked = true; _ = CGRequestScreenCaptureAccess() }
                }
                Toggle("Show names in icon bar", isOn: $names)
            } header: { Text("Hidden items") } footer: {
                Text(iconStyle == "real" && !screenOK
                     ? "Screen Recording isn't granted, so app icons are shown. Grant it under Permissions."
                     : "Real icons need Screen Recording; macOS asks about once a month whether to keep allowing screen access.")
                    .foregroundStyle(.secondary)
            }
            Section("Permissions") {
                LabeledContent("Accessibility \(axOK ? "✓" : "✗")") {
                    Button("Open System Settings") { openPane("Privacy_Accessibility") }
                }
                LabeledContent("Screen Recording \(screenOK ? "✓" : "✗")") {
                    Button(screenOK || asked ? "Open System Settings" : "Request") {
                        if screenOK || asked { openPane("Privacy_ScreenCapture") } else { asked = true; screenOK = CGRequestScreenCaptureAccess() }
                    }
                }
            }
            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                Link("github.com/roypadina/SmartHiddenBar", destination: URL(string: "https://github.com/roypadina/SmartHiddenBar")!)
                Button("Reveal log") { NSWorkspace.shared.activateFileViewerSelecting([logURL]) }
                Text("MIT · hiding approach from Hidden Bar (MIT)").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 620)  // ponytail: fixed size, the grouped form scrolls if a section grows
        // ponytail: permission state refreshes when the app reactivates (e.g. back from System Settings), not live.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            axOK = AXIsProcessTrusted()
            screenOK = CGPreflightScreenCaptureAccess()
            loginStatus = SMAppService.mainApp.status
            login = loginStatus == .enabled
        }
        // A recording left open must not keep our shortcuts unregistered.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in HotKeys.shared.stopRecording() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in HotKeys.shared.stopRecording() }
    }
}
