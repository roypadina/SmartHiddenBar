// SmartHiddenBar demo: the kit's menu bar plus ten fake third-party status icons (generic SF Symbols, no real brands) to the left of
// SmartHiddenBar's own icon. The app has no SwiftUI views in this flow (status item + icon bar are AppKit in main.swift), so nothing
// is compiled from it: the status glyph is the app's real asset (Assets/icons/fold-chevron/menubar-{shown,hidden}@2x.png, the set
// build.sh ships), the icon bar copies the geometry of Lister.showBar (main.swift @ v1.4.0), the click flow follows Lister.clicked.
import AppKit
import SwiftUI

private let W = Demo.size.width, H = Demo.size.height

// MARK: fake third-party apps (data only: nothing here exists in SmartHiddenBar)

private struct FakeApp { let symbol: String; let top: Color; let bottom: Color }
// Left to right = menu bar order; the icon bar lists them in the same order (main.swift:450 "menu bar order, left to right").
private let fakeApps: [FakeApp] = [
    .init(symbol: "cpu", top: Color(red: 0.98, green: 0.45, blue: 0.55), bottom: Color(red: 0.80, green: 0.18, blue: 0.32)),
    .init(symbol: "timer", top: Color(red: 1.00, green: 0.62, blue: 0.20), bottom: Color(red: 0.93, green: 0.36, blue: 0.10)),
    .init(symbol: "doc.on.clipboard", top: Color(red: 0.55, green: 0.62, blue: 0.72), bottom: Color(red: 0.32, green: 0.38, blue: 0.48)),
    .init(symbol: "waveform", top: Color(red: 0.62, green: 0.40, blue: 0.95), bottom: Color(red: 0.38, green: 0.20, blue: 0.75)),
    .init(symbol: "keyboard", top: Color(red: 0.40, green: 0.40, blue: 0.44), bottom: Color(red: 0.20, green: 0.20, blue: 0.24)),
    .init(symbol: "cloud", top: Color(red: 0.36, green: 0.70, blue: 1.00), bottom: Color(red: 0.10, green: 0.42, blue: 0.92)),   // the one whose menu opens (menuApp)
    .init(symbol: "externaldrive", top: Color(red: 0.55, green: 0.80, blue: 0.45), bottom: Color(red: 0.20, green: 0.55, blue: 0.28)),
    .init(symbol: "lock.shield", top: Color(red: 0.30, green: 0.80, blue: 0.78), bottom: Color(red: 0.05, green: 0.50, blue: 0.55)),
    .init(symbol: "bolt.fill", top: Color(red: 1.00, green: 0.84, blue: 0.25), bottom: Color(red: 0.95, green: 0.60, blue: 0.05)),
    .init(symbol: "moon.fill", top: Color(red: 0.45, green: 0.40, blue: 0.85), bottom: Color(red: 0.22, green: 0.18, blue: 0.55)),
]
private let menuApp = 5

// Menu of the fake "Cloud Sync" app, as SmartHiddenBar mirrors it (main.swift:503-517 mirror(): titles, enabled state, separators; the copy
// is made with keyEquivalent: "", so no shortcuts are shown).
private let menuRows: [MenuMock.Row] = [
    .item("Up to date", enabled: false),
    .separator,
    .item("Sync Now"),
    .item("Pause Syncing"),
    .item("Open Sync Folder"),
    .separator,
    .item("Settings…"),
    .item("Quit Cloud Sync"),
]
private let pickRow = 3, hoverRow = 2

// MARK: pieces

/// A hidden app's icon in the icon bar: a generic squircle tile (the real bar shows each app's own icon, e.app.icon).
private struct FakeAppIcon: View {
    let app: FakeApp
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24 * 0.225, style: .continuous).fill(LinearGradient(colors: [app.top, app.bottom], startPoint: .top, endPoint: .bottom))
            Image(systemName: app.symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
        }
        .frame(width: 24, height: 24)    // iconBarSize default 24 pt (main.swift:62)
    }
}

/// Lister.showBar: NSStackView spacing 10 (main.swift:463), insets top/bottom 6, left/right 10 (:464), cells = icons only.
private struct IconBar: View {
    var body: some View {
        HStack(spacing: 10) { ForEach(fakeApps.indices, id: \.self) { FakeAppIcon(app: fakeApps[$0]) } }
            .padding(.horizontal, 10).padding(.vertical, 6)
    }
}

/// A template menu bar image (white, like the system tints them) from one of the app's real PNG assets, 18 pt.
@MainActor private func glyph(_ name: String) -> CGImage {
    let dir = ProcessInfo.processInfo.environment["SHB_ASSETS"] ?? "Assets/icons/fold-chevron"
    let path = "\(dir)/\(name)@2x.png"
    guard let src = NSImage(contentsOfFile: path)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fatalError("missing \(path)") }
    let px = Int((18 * Demo.scale).rounded())
    let c = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .high
    c.draw(src, in: CGRect(x: 0, y: 0, width: px, height: px))
    c.setBlendMode(.sourceIn); c.setFillColor(CGColor(gray: 1, alpha: 0.95)); c.fill(CGRect(x: 0, y: 0, width: px, height: px))
    return c.makeImage()!
}

@MainActor func smartHiddenBarScenes() -> [Scene] {
    let shown = glyph("menubar-shown"), hiddenGlyph = glyph("menubar-hidden")   // Lister.updateIcon, main.swift:300 (h ? "menubar-hidden" : "menubar-shown")
    let barImg = renderView(IconBar())!
    let appImgs = fakeApps.map { a in
        renderView(Image(systemName: a.symbol).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.white.opacity(0.95)))!
    }

    // The kit's menu bar takes one SF-Symbol/text item. Reserve an 18 pt blank text slot for the app's real glyph and draw it on top.
    let space = NSAttributedString(string: " ", attributes: [.font: NSFont.systemFont(ofSize: 13)]).size().width
    let slot = StatusItem(text: String(repeating: " ", count: Int((18 / space).rounded(.up))))
    let item = Canvas(background: nil).menuBar(app: slot)
    let glyphCenter = CGPoint(x: item.midX, y: Demo.barHeight / 2)

    // Fake icons: same pitch as the kit's system icons (16 pt gap), ending where the app's own item begins.
    var appX: [CGFloat] = Array(repeating: 0, count: appImgs.count)
    var rx = item.minX + 8 - 16
    for i in appImgs.indices.reversed() { let w = CGFloat(appImgs[i].width) / Demo.scale; rx -= w; appX[i] = rx; rx -= 16 }

    // Lister.showBar placement (main.swift:475-476): centred on our icon, clamped, 4 pt below the bar.
    let barSize = CGSize(width: CGFloat(barImg.width) / Demo.scale, height: CGFloat(barImg.height) / Demo.scale)
    let barOrigin = CGPoint(x: min(max(item.midX - barSize.width / 2, 4), W - barSize.width - 4), y: Demo.barHeight + 4)
    func cellCenter(_ i: Int) -> CGPoint { CGPoint(x: barOrigin.x + 10 + 34 * CGFloat(i) + 12, y: barOrigin.y + 6 + 12) }
    let cell = CGRect(x: cellCenter(menuApp).x - 12, y: barOrigin.y + 6, width: 24, height: 24)

    // Lister.show: popUp(copy, below: cell) = 4 pt under the clicked cell (main.swift:433, popUp(_:below:)). The kit drops menus
    // straight under the bar, so draw it on a transparent canvas and shift it down to sit under the icon bar.
    let menuDy = cell.maxY + 4 - (Demo.barHeight + 2)
    let menuOrigin = Canvas.menuFrame(menuRows, under: cell).origin
    let rows = MenuMock.frames(menuRows).map { $0.offsetBy(dx: menuOrigin.x, dy: menuOrigin.y + menuDy) }
    func rowPoint(_ i: Int) -> CGPoint { CGPoint(x: menuOrigin.x + 70, y: rows[i].midY) }
    func drawMenu(_ c: Canvas, hover: CGPoint, alpha: CGFloat) {
        let mc = Canvas(background: nil)
        mc.menu(menuRows, under: cell, hover: CGPoint(x: hover.x, y: hover.y - menuDy), alpha: alpha)
        c.draw(mc.image, in: Demo.bounds.offsetBy(dx: 0, dy: menuDy))
    }

    /// Menu bar: fake icons at `apps` opacity, then our glyph (shown / hidden state), highlighted while the click is down.
    func bar(apps: Double, hidden: Bool, pressed: Bool) -> Canvas {
        let c = Canvas()
        c.menuBar(app: slot, appActive: pressed)
        if apps > 0 { for i in appImgs.indices { c.draw(appImgs[i], at: CGPoint(x: appX[i], y: (Demo.barHeight - CGFloat(appImgs[i].height) / Demo.scale) / 2), alpha: CGFloat(apps)) } }
        c.draw(hidden ? hiddenGlyph : shown, in: CGRect(x: glyphCenter.x - 9, y: glyphCenter.y - 9, width: 18, height: 18))
        return c
    }
    func down(_ t: Double, _ at: Double) -> Bool { t >= at && t < at + 0.14 }   // the item highlights while the button is down

    // 1. a crowded bar (the Welcome window's premise: macOS drops icons that don't fit next to a notch)
    let s1 = Scene(name: "crowded", duration: 1.8, caption: "Too many icons for your menu bar?") { _ in
        bar(apps: 1, hidden: false, pressed: false).image
    }

    // 2. click = the display's click mode; "cycle" with nothing off the bar already hides (Lister.clicked, main.swift:340-343)
    let p2 = CursorPath(start: CGPoint(x: W * 0.62, y: H * 0.46), moves: [.init(t0: 0.10, t1: 0.75, to: glyphCenter)], clicks: [0.85])
    let s2 = Scene(name: "hide", duration: 2.5, caption: "One click hides everything left of its icon") { t in
        let c = bar(apps: 1 - ramp(t, 0.90, 1.02), hidden: t >= 0.90, pressed: down(t, 0.85))
        let k = p2.click(t)
        c.cursor(at: p2.position(t), alpha: CGFloat(ramp(t, 0, 0.25)), press: k.press, pulse: k.pulse)
        return c.image
    }

    // 3. ⌥-click opens the icon bar with everything off the bar (main.swift:335); the panel is ordered front at once
    let p3 = CursorPath(start: glyphCenter, moves: [.init(t0: 1.20, t1: 1.85, to: cellCenter(menuApp))], clicks: [0.50])
    let s3 = Scene(name: "icon bar", duration: 2.6, caption: "⌥-click opens an icon bar of hidden apps") { t in
        let c = bar(apps: 0, hidden: true, pressed: down(t, 0.50))
        c.panel(barImg, at: barOrigin, radius: 8, alpha: CGFloat(ramp(t, 0.50, 0.58)))   // bg.layer.cornerRadius = 8 (main.swift:470)
        let k = p3.click(t)
        c.cursor(at: p3.position(t), press: k.press, pulse: k.pulse)
        return c.image
    }

    // 4. click a cell: the app's real menu is mirrored under the cell, a pick is replayed; the bar hides when the menu closes (defer, :423)
    let p4 = CursorPath(start: cellCenter(menuApp),
                        moves: [.init(t0: 0.90, t1: 1.30, to: rowPoint(hoverRow)), .init(t0: 1.50, t1: 1.85, to: rowPoint(pickRow))],
                        clicks: [0.35, 2.10])
    let s4 = Scene(name: "menu", duration: 3.0, caption: "Use a hidden app's menu without unhiding it") { t in
        let c = bar(apps: 0, hidden: true, pressed: false)
        let gone = ramp(t, 2.10, 2.16)
        if gone < 1 { c.panel(barImg, at: barOrigin, radius: 8, alpha: CGFloat(1 - gone)) }
        let menuA = min(ramp(t, 0.37, 0.47), 1 - gone)
        if menuA > 0 { drawMenu(c, hover: p4.position(t), alpha: CGFloat(menuA)) }
        let k = p4.click(t)
        c.cursor(at: p4.position(t), alpha: CGFloat(1 - ramp(t, 2.45, 2.70)), press: k.press, pulse: k.pulse)
        return c.image
    }

    // 5. click again: hidden -> show items (main.swift:341), and the clip loops
    let p5 = CursorPath(start: CGPoint(x: W * 0.80, y: H * 0.55), moves: [.init(t0: 0.10, t1: 0.75, to: glyphCenter)], clicks: [0.85])
    let s5 = Scene(name: "show", duration: 2.2, caption: "Click again to bring them all back") { t in
        let c = bar(apps: ramp(t, 0.93, 1.05), hidden: t < 0.93, pressed: down(t, 0.85))
        let k = p5.click(t)
        c.cursor(at: p5.position(t), alpha: CGFloat(ramp(t, 0, 0.25) * (1 - ramp(t, 1.70, 1.95))), press: k.press, pulse: k.pulse)
        return c.image
    }
    return [s1, s2, s3, s4, s5]
}

@main struct SmartHiddenBarDemo {
    @MainActor static func main() { Demo.run(scenes: smartHiddenBarScenes()) }
}
