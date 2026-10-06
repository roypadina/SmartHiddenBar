import ServiceManagement
import SwiftUI

// MARK: Settings (defaults domain com.roypadina.SmartHiddenBar)

func openPane(_ anchor: String) {
    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!)
}

/// Built-in display: cycle (its bar is short, the icon bar holds the overflow); external displays: plain toggle.
func defaultClickMode(_ screen: NSScreen) -> String {
    let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    return CGDisplayIsBuiltin(id) != 0 ? "cycle" : "toggle"
}

/// Third-party menu bar apps seen this launch plus any already always-hidden: (bundle id, name), by name.
func menuBarApps() -> [(id: String, name: String)] {
    var names: [String: String] = [:]
    for e in lister.last { if let b = e.app.bundleIdentifier, !b.hasPrefix("com.apple.") { names[b] = e.app.localizedName ?? b } }
    for b in lister.alwaysHidden where names[b] == nil {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: b) else { continue }  // uninstalled: off the list
        names[b] = FileManager.default.displayName(atPath: url.path)
    }
    return names.map { ($0.key, $0.value) }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

struct SettingsView: View {
    @AppStorage("autoRehideSeconds") var rehide = 0
    @AppStorage("iconStyle") var iconStyle = "app"
    @AppStorage("iconBarNames") var names = false
    @AppStorage("iconBarSize") var iconSize = 24.0
    @AppStorage("hoverReveal") var hoverReveal = false
    @AppStorage("clickEmptyBar") var clickEmptyBar = false
    @AppStorage("newApps") var newApps = "show"
    @State var login = SMAppService.mainApp.status == .enabled
    @State var loginStatus = SMAppService.mainApp.status
    @State var axOK = AXIsProcessTrusted()
    @State var screenOK = CGPreflightScreenCaptureAccess()
    @State var clickModes = UserDefaults.standard.dictionary(forKey: "clickModes") as? [String: String] ?? [:]
    @State var always = lister.alwaysHidden
    @State var apps = menuBarApps()
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
                    Text("When the pointer leaves the menu bar").tag(-1)
                }
                Toggle("Show items when hovering empty menu bar space", isOn: $hoverReveal)
                Toggle("Click empty menu bar space to show / hide", isOn: $clickEmptyBar)
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
                ForEach(NSScreen.screens, id: \.localizedName) { screen in
                    Picker(screen.localizedName, selection: Binding(
                        get: { clickModes[screen.localizedName] ?? defaultClickMode(screen) },
                        set: { clickModes[screen.localizedName] = $0; UserDefaults.standard.set(clickModes, forKey: "clickModes") })) {
                        Text("Show → icon bar → hide").tag("cycle")
                        Text("Show / hide").tag("toggle")
                        Text("Icon bar only").tag("bar")
                    }
                }
            } header: { Text("Click") } footer: {
                Text("What a left click on the SmartHiddenBar icon does on each display. ⌥-click always opens the icon bar.").foregroundStyle(.secondary)
            }
            Section {
                Picker("New menu bar apps", selection: $newApps) {
                    Text("Show normally").tag("show")
                    Text("Always hide").tag("hide")
                }
                ForEach(apps, id: \.id) { app in
                    Toggle(isOn: Binding(
                        get: { always.contains(app.id) },
                        set: { on in
                            if on { always.insert(app.id) } else { always.remove(app.id) }
                            UserDefaults.standard.set(always.sorted(), forKey: "alwaysHidden")
                            lister.alwaysHiddenChanged()
                        })) {
                        Label {
                            Text(app.name)
                        } icon: {
                            Image(nsImage: NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.id)
                                .map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSImage())
                                .resizable().frame(width: 16, height: 16)
                        }
                    }
                }
                if apps.isEmpty { Text("No menu bar apps found yet").foregroundStyle(.secondary) }
            } header: { Text("Always hidden") } footer: {
                Text("Stay hidden even when items are shown; reach them from the icon bar.").foregroundStyle(.secondary)
            }
            Section {
                Picker("Icons", selection: $iconStyle) {
                    Text("App icons").tag("app")
                    Text("Real menu bar icons").tag("real")
                }.onChange(of: iconStyle) { _, style in
                    if style == "real", !CGPreflightScreenCaptureAccess() { asked = true; _ = CGRequestScreenCaptureAccess() }
                }
                Slider(value: $iconSize, in: 16...48, step: 2) { Text("Icon size in icon bar: \(Int(iconSize)) pt") }
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
                HStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 48, height: 48)
                    VStack(alignment: .leading) {
                        Text("SmartHiddenBar").font(.headline)
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")").foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Button("About SmartHiddenBar…") { AboutWindow.show() }
                    Button("Support on Ko-fi ☕") { NSWorkspace.shared.open(kofiURL) }.buttonStyle(.borderedProminent)
                    Button("Reveal log") { NSWorkspace.shared.activateFileViewerSelecting([logURL]) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 620)  // ponytail: fixed size, the grouped form scrolls if a section grows
        // ponytail: permission state refreshes when the app reactivates (e.g. back from System Settings), not live.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            axOK = AXIsProcessTrusted()
            apps = menuBarApps()
            always = lister.alwaysHidden
            screenOK = CGPreflightScreenCaptureAccess()
            loginStatus = SMAppService.mainApp.status
            login = loginStatus == .enabled
        }
        .onReceive(NotificationCenter.default.publisher(for: inventoryChanged)) { _ in apps = menuBarApps() }
        // A recording left open must not keep our shortcuts unregistered.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in HotKeys.shared.stopRecording() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in HotKeys.shared.stopRecording() }
    }
}

let kofiURL = URL(string: "https://ko-fi.com/roypadina")!

/// Custom About window: the standard panel's fixed-height credits box clipped the text.
enum AboutWindow {
    static var window: NSWindow?
    static func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: AboutView()))
            w.title = "About SmartHiddenBar"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct AboutView: View {
    private let info = Bundle.main.infoDictionary ?? [:]

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
            VStack(spacing: 2) {
                Text("SmartHiddenBar").font(.title.bold())
                Text("Version \(info["CFBundleShortVersionString"] as? String ?? "") (\(info["CFBundleVersion"] as? String ?? ""))")
                    .font(.callout).foregroundStyle(.secondary)
            }
            VStack(spacing: 8) {
                Text("Made by Roy Padina").font(.headline)
                Text("I'm a software engineer from Israel who builds small, focused Mac tools to fix the little annoyances in my own day — then shares them free and open source.")
                Text("If this app saves you time, a coffee on Ko-fi keeps the next one coming. ☕")
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Link(destination: kofiURL) { Text("Support on Ko-fi ☕").frame(minWidth: 140) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                Link(destination: URL(string: "https://github.com/roypadina/SmartHiddenBar")!) { Text("GitHub").frame(minWidth: 70) }
                    .buttonStyle(.bordered).controlSize(.large)
            }
            Link("Report an issue", destination: URL(string: "https://github.com/roypadina/SmartHiddenBar/issues")!).font(.callout)
            Divider().padding(.vertical, 4)
            VStack(spacing: 3) {
                Text("Hiding approach from [Hidden Bar](https://github.com/dwarvesf/hidden) by Dwarves Foundation · MIT")
                Text("© Roy Padina · MIT")
            }
            .font(.caption).foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 380)
    }
}
