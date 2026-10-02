import AppKit

// Accessibility reads of every app's menu bar items, and pressing/closing their real menus.

func ax(_ e: AXUIElement, _ attr: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(e, attr as CFString, &v) == .success ? v : nil
}
func kids(_ e: AXUIElement) -> [AXUIElement] { ax(e, kAXChildrenAttribute) as? [AXUIElement] ?? [] }
func text(_ e: AXUIElement, _ attr: String) -> String { ax(e, attr) as? String ?? "" }
func press(_ e: AXUIElement) { AXUIElementPerformAction(e, kAXPressAction as CFString) }
func submenu(_ e: AXUIElement) -> AXUIElement? { kids(e).first { text($0, kAXRoleAttribute) == kAXMenuRole } }
func actions(_ e: AXUIElement) -> [String] { var n: CFArray?; AXUIElementCopyActionNames(e, &n); return n as? [String] ?? [] }
func pid(_ e: AXUIElement) -> pid_t { var p: pid_t = 0; AXUIElementGetPid(e, &p); return p }

struct Extra {
    let app: NSRunningApplication
    let element: AXUIElement
    let x: CGFloat  // AX coordinates, 0 = left edge of the primary screen
    let y: CGFloat  // AX, 0 = top of the primary screen
    let width: CGFloat
    let height: CGFloat
    let index: Int  // position among its app's items: stable while hidden, unlike x
    var isVisible = true

    var name: String {
        let label = [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute]
            .map { text(element, $0).components(separatedBy: .newlines)[0] }.first { !$0.isEmpty }
        return [app.localizedName ?? "?", label].compactMap { $0 }.joined(separator: " — ")
    }
}

func items(of app: NSRunningApplication) -> [Extra] {
    guard let bar = ax(AXUIElementCreateApplication(app.processIdentifier), "AXExtrasMenuBar") else { return [] }
    return kids(bar as! AXUIElement).enumerated().map { i, raw in
        let item = actions(raw).isEmpty ? (kids(raw).first ?? raw) : raw  // MenuBarAgent wraps the real item in an action-less group
        let r = rect(item)
        return Extra(app: app, element: item, x: r.minX, y: r.minY, width: r.width, height: r.height, index: i)
    }
}

func extras() -> [Extra] {
    // Each query is a ~20 ms IPC round trip (300 ms on a timeout) for ~130 processes: ask them all in parallel.
    let apps = NSWorkspace.shared.runningApplications.filter { $0.processIdentifier != getpid() }
    var per = [[Extra]](repeating: [], count: apps.count)
    per.withUnsafeMutableBufferPointer { buf in  // each slot written by exactly one iteration
        DispatchQueue.concurrentPerform(iterations: apps.count) { buf[$0] = items(of: apps[$0]) }
    }
    let all = per.flatMap { $0 }.sorted { $0.x > $1.x }
    // Hidden = left of the notch, or overlapping its right-hand neighbour past its midpoint (macOS stacks overflow items there),
    // or parked off the bar (macOS 27 moves items it hides — e.g. via an allow-list — to ≈(0, screen bottom)).
    // ponytail: primary screen only; without a notch only x < 0 counts. Per-screen check if the notch screen isn't primary.
    let minX = NSScreen.screens.first?.auxiliaryTopRightArea?.minX ?? 0
    var result = all
    for i in result.indices {
        result[i].isVisible = onBar(result[i].y) && result[i].x >= minX && (i == 0 || result[i].x + result[i].width / 2 <= result[i - 1].x)
    }
    return result
}

func rect(_ e: AXUIElement) -> CGRect {
    var p = CGPoint.zero, s = CGSize.zero
    if let v = ax(e, kAXPositionAttribute) { AXValueGetValue(v as! AXValue, .cgPoint, &p) }
    if let v = ax(e, kAXSizeAttribute) { AXValueGetValue(v as! AXValue, .cgSize, &s) }
    return CGRect(origin: p, size: s)
}

/// AX y within a few points of some screen's top edge. ponytail: 10 pt slack, seen y = 0…2 on macOS 27.
func onBar(_ y: CGFloat) -> Bool {
    let h = NSScreen.screens.first?.frame.maxY ?? 0
    return NSScreen.screens.contains { (-1..<10).contains(y - (h - $0.frame.maxY)) }
}

/// Our own status item's AX frame. Never call on the main thread: the main thread is what answers it.
func ownFrame() -> CGRect? {
    guard let bar = ax(AXUIElementCreateApplication(getpid()), "AXExtrasMenuBar"), let raw = kids(bar as! AXUIElement).first else { return nil }
    return rect(actions(raw).isEmpty ? (kids(raw).first ?? raw) : raw)
}

/// Closed status menus stay in the AX tree at 0×0 (static NSStatusItem.menu), so "open" means "has a size".
func isOpen(_ menu: AXUIElement) -> Bool {
    var s = CGSize.zero
    if let v = ax(menu, kAXSizeAttribute) { AXValueGetValue(v as! AXValue, .cgSize, &s) }
    return s.width > 0
}

/// Presses the real item and waits for its menu. nil = not a menu (a panel or a plain click action);
/// the press has already triggered it.
func openMenu(_ item: AXUIElement) -> AXUIElement? {
    AXUIElementSetMessagingTimeout(item, 0.05)  // the press blocks until timeout; shorter = shorter real-menu flash
    press(item)
    AXUIElementSetMessagingTimeout(item, 0)  // back to the global timeout
    for _ in 0..<100 {
        if let m = submenu(item), isOpen(m) { return m }  // a static menu is present while still closed
        usleep(10_000)
    }
    return nil
}

/// Waits up to ~150 ms for the real menu to go away.
func closed(_ menu: AXUIElement) -> Bool {
    for _ in 0..<15 {
        if !isOpen(menu) { return true }
        usleep(10_000)
    }
    return false
}

/// Closes another app's open menu with Escape posted to that app's own event queue, which its
/// menu-tracking loop consumes (AXCancel is advertised on every AXMenu but ignored). Only while it's open.
// ponytail: tiny race — if the menu closes between the check and the post, Escape reaches that app's key window.
func close(_ menu: AXUIElement, of item: AXUIElement) {
    guard isOpen(menu) else { return }
    for down in [true, false] { CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: down)?.postToPid(pid(item)) }
    _ = closed(menu)
}

struct Pick {
    let item: AXUIElement
    let path: [Int]  // menu-item indexes from the top menu down
}
