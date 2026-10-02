import AppKit
import Carbon
import SwiftUI

// Hides every menu bar item left of our icon (left click toggles), lists them all and mirrors the chosen
// item's menu under our own icon (right-click), icon bar on ⌥-click / its shortcut (Shortcuts.swift). Nothing on the real bar is moved.

let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/SmartHiddenBar.log")
func log(_ s: String) {
    let line = Data("\(ISO8601DateFormatter().string(from: Date())) \(s)\n".utf8)
    if let h = try? FileHandle(forWritingTo: logURL) { h.seekToEndOfFile(); h.write(line); try? h.close() } else { try? line.write(to: logURL) }
}

final class Lister: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let menu = NSMenu()
    let bar: NSPanel = {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return p
    }()
    var barExtras: [Extra] = []
    var last: [Extra] = []  // latest background inventory (refreshHide); the menu and icon bar never walk AX on main
    var monitor: Any?
    var barNames: Bool { UserDefaults.standard.bool(forKey: "iconBarNames") }
    var hidden: Bool {
        get { UserDefaults.standard.bool(forKey: "hidden") }
        set { UserDefaults.standard.set(newValue, forKey: "hidden") }
    }
    var broken = false  // hiding failed this launch: stay shown, don't retry until the user clicks
    var alerted = false  // missing-API alert shown this launch
    var rehide: Timer?
    lazy var settings: NSWindow = {
        let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
        w.title = "SmartHiddenBar Settings"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.center()
        return w
    }()
    var assertion: NSObject?  // held = restriction active; released = full bar back
    var allowed: [String] = []  // allow-list behind `assertion`
    var denied = Set<String>()  // bundles seen on the bar left of us; parked bundles NOT in here are allowed (fail open)
    var generation = 0  // bumped to make an in-flight activation lose

    func applicationDidFinishLaunching(_ n: Notification) {
        UserDefaults.standard.register(defaults: ["hidden": true])
        checkLocation()
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        status.autosaveName = "SmartHiddenBar"
        menu.delegate = self
        status.menu = nil  // every click reaches `clicked`; the menu is popped up by hand
        status.button?.target = self
        status.button?.action = #selector(clicked)
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateIcon()
        installHotKeyHandler()
        HotKeys.shared.migrate()
        HotKeys.shared.register()
        for n in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refreshHide), name: n, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(reapply), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reapply), name: NSWorkspace.didWakeNotification, object: nil)
        // ponytail: 5 s poll also catches items an already-running app adds; push-based if MenuBarAgent ever offers it.
        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(refreshHide), userInfo: nil, repeats: true)
        captureIcons { self.applyHidden() }  // items are all on the bar until the first allow-list activation
    }

    func applicationWillTerminate(_ n: Notification) { stopHiding() }

    /// The allow-list matches bundle ids through LaunchServices, so a copy LS doesn't resolve to hides its own icon.
    func checkLocation() {
        let me = URL(fileURLWithPath: Bundle.main.bundlePath).resolvingSymlinksInPath().path
        let ls = Bundle.main.bundleIdentifier.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }?.resolvingSymlinksInPath().path
        guard ls != me else { return }
        log("launch: running \(me), LaunchServices resolves \(ls ?? "nothing")")
        let a = NSAlert()
        a.messageText = "Move SmartHiddenBar to /Applications and open it from there."
        a.addButton(withTitle: "Quit")
        NSApp.activate()
        a.runModal()
        exit(0)
    }

    @objc func toggleHidden() {
        if broken { broken = false } else { hidden.toggle() }  // after a failure the click retries instead of flipping
        applyHidden()
    }

    /// Applies `hidden`: hide = activate the allow-list; show = release it and arm the auto-rehide timer.
    func applyHidden() {
        rehide?.invalidate()
        rehide = nil
        updateIcon()
        guard !hidden else { return refreshHide() }
        stopHiding()
        let s = UserDefaults.standard.integer(forKey: "autoRehideSeconds")
        if s > 0 { rehide = Timer.scheduledTimer(timeInterval: TimeInterval(s), target: self, selector: #selector(rehideNow), userInfo: nil, repeats: false) }
        // ponytail: fixed 300 ms for MenuBarAgent to put items back; retry/settle check if captures come out empty.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard !self.hidden else { return }
            self.refreshHide()  // refresh `last` with the items back on the bar
            captureIcons {}
        }
    }

    @objc func rehideNow() {
        guard !hidden else { return }
        hidden = true
        applyHidden()
    }

    func updateIcon() {
        let h = hidden && !broken
        let img = NSImage(named: h ? "menubar-hidden" : "menubar-shown")
            ?? NSImage(systemSymbolName: h ? "chevron.right" : "chevron.left", accessibilityDescription: nil)
        img?.isTemplate = true
        img?.accessibilityDescription = "SmartHiddenBar — items \(h ? "hidden" : "shown")"
        status.button?.image = img
    }

    /// Shortcuts (Shortcuts.swift): id 1 = toggle hiding (a left click), 2 = icon bar — works even when macOS hides our own icon.
    func installHotKeyHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &id)
            MainActor.assumeIsolated {
                switch id.id {
                case 1: lister.toggleHidden()
                case 2: lister.bar.isVisible ? lister.hideBar() : lister.showBar()
                case 3: lister.status.button.map { lister.popUp(lister.appsMenu(), below: $0) }
                case 4: lister.openSettings()
                case 5: NSApp.terminate(nil)
                default: break
                }
            }
            return noErr
        }, 1, &spec, nil, nil)
    }

    /// Once ever: nothing sits left of our icon yet, so explain how to use it.
    func firstRunHint() {
        UserDefaults.standard.set(true, forKey: "firstRunHintShown")
        let a = NSAlert()
        a.messageText = "Move the SmartHiddenBar icon"
        a.informativeText = "⌘-drag the SmartHiddenBar icon to the right; everything left of it hides. "
            + "\(Shortcut.stored("barShortcut").map { "\($0.label) (or ⌥-click)" } ?? "⌥-click") shows hidden items."
        NSApp.activate()
        a.runModal()
    }

    /// Left = toggle hiding; right / ⌃-left = menu; ⌥-left = icon bar.
    @objc func clicked() {
        guard let button = status.button else { return }
        let e = NSApp.currentEvent, flags = NSEvent.modifierFlags  // macOS 27 status clicks carry no modifiers/clickCount
        if flags.contains(.option) { return bar.isVisible ? hideBar() : showBar() }
        if e?.type == .rightMouseUp || flags.contains(.control) { return popUp(menu, below: button) }
        // Double click = icon bar with every item; single click waits out the double-click interval, then toggles.
        if let p = pendingToggle, !p.isCancelled {  // second click inside the interval = double click
            p.cancel()
            pendingToggle = nil
            return bar.isVisible ? hideBar() : showBar()
        }
        let w = DispatchWorkItem { [weak self] in self?.pendingToggle = nil; self?.toggleHidden() }
        pendingToggle = w
        DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: w)
    }
    var pendingToggle: DispatchWorkItem?

    @objc func grantAccessibility() { openPane("Privacy_Accessibility") }

    @objc func openSettings() {
        NSApp.activate()
        settings.makeKeyAndOrderFront(nil)
    }

    func popUp(_ m: NSMenu, below view: NSView) {
        m.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height + 4), in: view)
    }

    /// Right-click menu: Show/Hide · Apps ▸ · Settings… · Quit, each showing its recorded shortcut.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        func row(_ title: String, _ action: Selector, _ shortcut: String, fallback: String = "") -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: fallback)
            item.target = self
            Shortcut.stored(shortcut)?.show(on: item)
            return item
        }
        if !AXIsProcessTrusted() { menu.addItem(row("Grant Accessibility…", #selector(grantAccessibility), "")) }
        menu.addItem(row(hidden ? "Show items" : "Hide items", #selector(toggleHidden), "toggleShortcut"))
        let apps = row("Apps", #selector(noop), "appsShortcut")
        apps.submenu = appsMenu()
        menu.addItem(apps)
        menu.addItem(.separator())
        menu.addItem(row("Settings…", #selector(openSettings), "settingsShortcut", fallback: ","))
        menu.addItem(.separator())
        let quit = row("Quit", #selector(NSApplication.terminate(_:)), "quitShortcut", fallback: "q")
        quit.target = NSApp  // `self` doesn't implement terminate:, so with target = self the item auto-disables
        menu.addItem(quit)
    }

    @objc func noop() {}

    /// Every third-party menu bar item (Apple's own skipped), by app name; a pick opens its mirrored menu.
    func appsMenu() -> NSMenu {
        let m = NSMenu()
        let items = last.filter { !($0.app.bundleIdentifier ?? "").hasPrefix("com.apple.") }
        let counts = Dictionary(grouping: items, by: { $0.app.processIdentifier }).mapValues(\.count)
        for e in items.sorted(by: { ($0.app.localizedName ?? "") .localizedCaseInsensitiveCompare($1.app.localizedName ?? "") == .orderedAscending }) {
            let name = e.app.localizedName ?? "?"
            let item = NSMenuItem(title: counts[e.app.processIdentifier, default: 1] > 1 ? e.name : name, action: #selector(open(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = e
            item.image = icon(e, height: 16)
            item.preferredImageVisibility = .visible  // macOS 27 hides menu item images by default
            m.addItem(item)
        }
        if items.isEmpty { m.addItem(NSMenuItem(title: "No menu bar apps found", action: nil, keyEquivalent: "")) }
        return m
    }

    @objc func open(_ sender: NSMenuItem) {
        guard let button = status.button else { return }
        show(sender.representedObject as! Extra, below: button)
    }

    @objc func cell(_ sender: NSButton) { show(barExtras[sender.tag], below: sender) }

    /// Opens the real menu, copies it, closes it, and pops the copy up below `view`. Non-menu items: the press did it.
    func show(_ e: Extra, below view: NSView) {
        unmonitor()  // our own Escape / menu clicks must not hide the bar the copy is anchored to
        DispatchQueue.main.async { [self] in  // let the status menu finish closing first
            defer { hideBar() }
            // Static menus are readable while closed: mirror with no press, no flash, nothing to close.
            // Empty = built lazily in menuNeedsUpdate, so it must be pressed open.
            // ponytail: stale for menuNeedsUpdate-driven titles (e.g. cmux unread count); pick then no-ops on title mismatch.
            if let m = submenu(e.element), !isOpen(m), !kids(m).isEmpty {
                return popUp(mirror(m, item: e.element, path: []), below: view)
            }
            guard let real = openMenu(e.element) else { return }
            let copy = mirror(real, item: e.element, path: [])
            close(real, of: e.element)
            popUp(copy, below: view)
        }
    }

    /// Ice-Bar-style row of app icons just below the menu bar, under our icon, clamped to the screen.
    // ponytail: hidden items only, one row, rebuilt on every show; add a "visible too" toggle if it's missed.
    /// Off the bar right now: parked by macOS, or ours while hidden (AX keeps reporting those at their on-bar frames).
    func offBar(_ e: Extra) -> Bool { !e.isVisible || (hidden && denied.contains(e.app.bundleIdentifier ?? "")) }

    func showBar() {
        unmonitor()
        let win = status.button?.window
        guard let screen = win?.screen ?? NSScreen.main else { return }
        let midX = win?.frame.midX ?? screen.frame.midX
        barExtras = last.filter(offBar).sorted { $0.x < $1.x }  // menu bar order, left to right
        let cells: [NSView] = barExtras.enumerated().map { i, e in
            let b = NSButton(title: barNames ? e.app.localizedName ?? "?" : "", image: icon(e, height: 18) ?? NSImage(), target: self, action: #selector(cell(_:)))
            b.isBordered = false
            b.imagePosition = barNames ? .imageAbove : .imageOnly
            b.font = .systemFont(ofSize: 10)
            b.toolTip = e.name
            b.setAccessibilityLabel(e.name)
            b.tag = i
            return b
        }
        let stack = NSStackView(views: cells.isEmpty ? [NSTextField(labelWithString: "No hidden items")] : cells)
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        stack.frame.size = stack.fittingSize
        let bg = NSVisualEffectView(frame: stack.frame)
        bg.material = .menu
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 8
        bg.addSubview(stack)
        bg.menu = menu  // right-click on the bar = our status menu
        bar.contentView = bg
        let size = stack.frame.size, s = screen.frame
        let x = min(max(midX - size.width / 2, s.minX + 4), s.maxX - size.width - 4)
        let y = screen.visibleFrame.maxY - size.height - 4  // just below the menu bar
        bar.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        bar.orderFrontRegardless()
        // Clicks inside the bar go to us, not to a global monitor, so any global mouse-down is "outside".
        // ponytail: Esc is observed, not consumed — the frontmost app also gets it.
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] e in
            if e.type != .keyDown || e.keyCode == 53 { self?.hideBar() }
        }
    }

    func hideBar() {
        unmonitor()
        bar.orderOut(nil)
    }

    func unmonitor() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }

    /// Copies an open AX menu into an NSMenu; each item remembers its index path for replay.
    func mirror(_ real: AXUIElement, item: AXUIElement, path: [Int]) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for (i, mi) in kids(real).enumerated() {
            let title = text(mi, kAXTitleAttribute)
            let sub = submenu(mi)
            if title.isEmpty && sub == nil { menu.addItem(.separator()); continue }
            let copy = NSMenuItem(title: title, action: #selector(pick(_:)), keyEquivalent: "")
            copy.target = self
            copy.isEnabled = ax(mi, kAXEnabledAttribute) as? Bool ?? true
            copy.state = text(mi, "AXMenuItemMarkChar").isEmpty ? .off : .on
            copy.representedObject = Pick(item: item, path: path + [i])
            if let sub { copy.submenu = mirror(sub, item: item, path: path + [i]) }
            menu.addItem(copy)
        }
        return menu
    }

    /// Reopens the real menu, walks the same path, and presses the item — only if its title still matches.
    @objc func pick(_ sender: NSMenuItem) {
        let p = sender.representedObject as! Pick
        DispatchQueue.main.async {
            guard let root = openMenu(p.item) else { return }
            var menu = root
            for i in p.path.dropLast() {
                let items = kids(menu)
                guard i < items.count, let sub = submenu(items[i]) else { return close(root, of: p.item) }
                menu = sub
            }
            let items = kids(menu)
            guard let last = p.path.last, last < items.count, text(items[last], kAXTitleAttribute) == sender.title
            else { return close(root, of: p.item) }
            // ponytail: replay still opens the real menu (flash); pressing the closed-menu item directly may work — needs a hardware test.
            press(items[last])
            if !closed(root) { close(root, of: p.item) }
        }
    }
}

AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.3)  // a menu press blocks until the menu closes

if CommandLine.arguments.contains("--list") {
    for e in extras() { print(e.isVisible ? "visible" : "hidden ", Int(e.x), e.name) }
    exit(0)
}

let lister = Lister()
NSApplication.shared.delegate = lister
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
