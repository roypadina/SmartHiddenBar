import ServiceManagement
import SwiftUI

/// First-launch welcome (MBX-18): why the app exists, how to use it, how to get back in without the icon (MBX-8),
/// the login item (MBX-17) and the Accessibility grant. Shown once from applicationDidFinishLaunching, again from Settings.
@MainActor
enum WelcomeWindow {
    private static var window: NSWindow?

    static func show() {
        if window?.isVisible != true {  // rebuilt each time so the shortcut text is current
            let w = NSWindow(contentViewController: NSHostingController(rootView: WelcomeView(
                onOpenSettings: { lister.openSettings(); window?.close() },
                onDone: { window?.close() })))
            w.title = "Welcome"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        if let window { AccessoryWindows.shared.show(window) }
    }
}

struct WelcomeView: View {
    let onOpenSettings: () -> Void
    let onDone: () -> Void
    @State private var trusted = AXIsProcessTrusted()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to SmartHiddenBar").font(.title2.bold())
                    Text("A MacBook notch leaves little room in the menu bar, and macOS quietly drops the icons that don't fit. SmartHiddenBar tucks away the ones you rarely need and keeps them one click away.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            row("menubar.rectangle", "SmartHiddenBar lives in the menu bar.",
                "⌘-drag its icon to the right. Everything to its left hides. Click the icon to show or hide those items.")
            row("rectangle.split.3x1", "Hidden items stay one click away.",
                "⌥-click the icon\(Shortcut.stored("barShortcut").map { ", or press \($0.label)," } ?? "") to open the icon bar. Pick an item to use its menu without unhiding anything.")
            row("hand.raised", "Needs Accessibility access.",
                "SmartHiddenBar reads other apps' menu bar items through Accessibility. Without it, nothing hides.")
            row("questionmark.circle", "Icon missing?",
                "Open SmartHiddenBar again from Applications to get Settings, or check System Settings > Menu Bar.")
            LaunchAtLoginToggle()
            SupportBox()
            HStack {
                if trusted {
                    Button("Open Settings", action: onOpenSettings)
                } else {
                    // Adds SmartHiddenBar to System Settings > Privacy & Security > Accessibility.
                    Button("Allow Accessibility…") {
                        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
                    }
                }
                Spacer()
                Button("Done", action: onDone).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            trusted = AXIsProcessTrusted()  // the user may have granted it in System Settings
        }
    }

    private func row(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.title2).foregroundStyle(.tint).frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Settings > General and the welcome window (MBX-17): user action only, status re-read on activation.
struct LaunchAtLoginToggle: View {
    @State private var status = SMAppService.mainApp.status

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Open at Login", isOn: Binding(
                get: { status == .enabled },
                set: { on in
                    do { try on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
                    catch { log("login item: \(error)") }
                    status = SMAppService.mainApp.status
                }))
            if status == .requiresApproval {
                Button("Allow in Login Items…") { SMAppService.openSystemSettingsLoginItems() }
            } else if status == .notFound {
                Text("Move SmartHiddenBar to Applications to open it at login.").font(.callout).foregroundStyle(.secondary)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            status = SMAppService.mainApp.status  // the user may change it in System Settings
        }
    }
}

/// Quiet Ko-fi box (house style H1): the app's own next step stays the primary button, so this one is `.bordered`.
struct SupportBox: View {
    var body: some View {
        GroupBox {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Free and open source").font(.headline)
                    Text("If SmartHiddenBar saves you time, a coffee on Ko-fi keeps the next one coming.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Link("Support on Ko-fi ☕", destination: kofiURL).buttonStyle(.bordered)
            }
            .padding(4)
        }
    }
}
