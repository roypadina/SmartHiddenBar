import AppKit

// MARK: Hiding via macOS 27's private MenuBarClientCore "assessment mode" allow-list.
// Approach and API shape from Hidden Bar v1.11.1 (dwarvesf/hidden, MIT, © 2026 Dwarves Foundation):
// hidden/Features/StatusBar/Engine/Native/HBNativeVisibilityShim.m + NativeVisibilityEngine.swift.
// MenuBarAgent shows only the allowed bundles + system items until `invalidate` or until this process exits.
// ponytail: Swift can't catch an NSException from a changed private API; we only check classes/selectors up front.

let invalidateSel = NSSelectorFromString("invalidate")
var hideAPIMissing = false

/// Activates an allow-list; `done` runs on main with the assertion to hold, or nil (logged).
func restrictMenuBar(to bundles: [String], _ done: @escaping (NSObject?) -> Void) {
    let initSel = NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:")
    let actSel = NSSelectorFromString("activateWithConfiguration:completionHandler:")
    guard dlopen("/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore", RTLD_NOW) != nil,
          let cfgClass = NSClassFromString("MBAssessmentModeConfiguration") as? NSObject.Type,
          let asrClass = NSClassFromString("MBAssessmentModeAssertion") as? NSObject.Type,
          cfgClass.instancesRespond(to: initSel), asrClass.instancesRespond(to: actSel), asrClass.instancesRespond(to: invalidateSel)
    else { log("hide: MenuBarClientCore API missing"); hideAPIMissing = true; return done(nil) }
    // Both must be NSArrays (the framework indexes into them). Unknown system ids are ignored; Hidden Bar passes 0..<64.
    let system = (0..<64).map { NSNumber(value: $0) } as NSArray
    // alloc's +1 is consumed by init; init's +1 is balanced by takeRetainedValue.
    let raw: AnyObject = (cfgClass as AnyObject).perform(NSSelectorFromString("alloc")).takeUnretainedValue()
    guard let cfg = raw.perform(initSel, with: system, with: bundles as NSArray)?.takeRetainedValue() else {
        log("hide: configuration init returned nil"); return done(nil)
    }
    let asr = asrClass.init()
    typealias Activate = @convention(c) (AnyObject, Selector, AnyObject, @escaping @convention(block) (NSError?) -> Void) -> Void
    unsafeBitCast(asr.method(for: actSel), to: Activate.self)(asr, actSel, cfg) { err in
        DispatchQueue.main.async {
            if let err { log("hide: activate failed: \(err)") }
            done(err == nil ? asr : nil)
        }
    }
}

extension Lister {
    /// Display changes and wake can leave MenuBarAgent with a stale layout: release, let items settle, re-apply.
    // ponytail: fixed 1 s settle; items still parked then are allowed (fail open) until the next 5 s poll re-denies them.
    @objc func reapply() {
        broken = false
        guard hidden || !alwaysHidden.isEmpty else { return }
        log("hide: re-applying after screen change / wake")
        stopHiding()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.refreshHide() }
    }

    func stopHiding() {
        generation += 1
        assertion?.perform(invalidateSel)
        if assertion != nil { log("hide: released") }
        assertion = nil
        allowed = []
    }

    /// AX walk off the main thread (our own item's AX is answered by the main thread), then decide on main.
    /// Runs whether or not we hide: `last` is the inventory the menu and icon bar show.
    /// "New menu bar apps: Always hide" (Settings): a bundle never seen before goes straight onto the always-hidden list.
    /// The first run only records what's already there.
    func noteNewApps(_ all: [Extra]) {
        let d = UserDefaults.standard
        let seen = Set(all.compactMap(\.app.bundleIdentifier).filter { !$0.hasPrefix("com.apple.") })
        guard let known = d.stringArray(forKey: "knownApps").map(Set.init) else { return d.set(seen.sorted(), forKey: "knownApps") }
        let fresh = seen.subtracting(known)
        guard !fresh.isEmpty else { return }
        d.set(known.union(fresh).sorted(), forKey: "knownApps")
        guard d.string(forKey: "newApps") == "hide" else { return }
        log("new menu bar apps, always hidden: \(fresh.sorted())")
        d.set(alwaysHidden.union(fresh).sorted(), forKey: "alwaysHidden")
    }

    /// Apply at once from the last inventory (the 5 s poll keeps it fresh), then re-read to catch anything that moved.
    func hideNow() {
        if !last.isEmpty { applyHide(last, lastMe) }
        refreshHide()
    }

    @objc func refreshHide() {
        guard AXIsProcessTrusted() else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let all = extras(), me = ownFrame()
            DispatchQueue.main.async {
                self.last = all
                self.lastMe = me
                self.noteNewApps(all)
                self.applyHide(all, me)
            }
        }
    }

    /// Hidden: allow = us + system owners + every bundle with an item right of our midX + parked bundles never seen left of us.
    /// Shown: allow = every bundle on the bar. Either way minus the always-hidden list (shown + empty list = no restriction).
    /// ponytail: one AX coordinate space assumed (macOS 27 reports one bar here even with 3 displays); per-display
    /// projection like Hidden Bar PR #422 if the log shows items on other screens.
    func applyHide(_ all: [Extra], _ me: CGRect?) {
        let always = alwaysHidden
        guard hidden || !always.isEmpty, !broken, !ncOpen else { return }
        // Our own item parked (or gone) = the allow-list is hiding us too: release rather than leave nothing to click.
        guard let me, onBar(me.minY) else {
            stopHiding()
            broken = true
            updateIcon()
            return log("hide: own item \(me == nil ? "not found" : "parked"), released")
        }
        var right = Set<String>(), left = Set<String>(), parked = Set<String>()
        for e in all {
            guard let b = e.app.bundleIdentifier else { continue }
            if !onBar(e.y) { parked.insert(b) }
            else if e.x + e.width / 2 > me.midX { right.insert(b) }
            else { left.insert(b) }
        }
        if left.isEmpty, denied.isEmpty, !UserDefaults.standard.bool(forKey: "firstRunHintShown") { firstRunHint() }
        denied = denied.union(left).subtracting(right)
        let own = Bundle.main.bundleIdentifier ?? "com.roypadina.SmartHiddenBar"
        // System owners too: phase 1 never hides macOS's own items (Now Playing may be bundle-owned, not a system id).
        let system = ["com.apple.MenuBarAgent", "com.apple.controlcenter", "com.apple.systemuiserver"]
        let visible = hidden ? right.union(parked.subtracting(denied)) : right.union(left).union(parked)
        let allow = Set([own] + system).union(visible.subtracting(always)).sorted()
        guard allow != allowed || assertion == nil else { return }
        generation += 1
        let g = generation
        restrictMenuBar(to: allow) { [self] a in
            guard g == generation, hidden || !alwaysHidden.isEmpty else { a?.perform(invalidateSel); return }
            guard let a else {  // fail open, and stop retrying every 5 s until the user clicks again
                stopHiding()
                broken = true
                updateIcon()
                guard hideAPIMissing, !alerted else { return }
                alerted = true
                let alert = NSAlert()
                alert.messageText = "Hiding isn't available on this macOS"
                alert.informativeText = "SmartHiddenBar relies on a private menu bar API that this macOS build doesn't have, so all items stay visible. Right-click the icon to reach every item; details in ~/Library/Logs/SmartHiddenBar.log."
                NSApp.activate()
                alert.runModal()
                return
            }
            let old = assertion
            assertion = a  // new before old, like Hidden Bar: no full-bar flash between lists
            allowed = allow
            old?.perform(invalidateSel)
            log("hide: active \(allow.count) allowed, \(denied.count) denied")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.refreshHide() }  // re-read so `last` sees the newly parked items
        }
    }
}
