import AppKit
import ScreenCaptureKit

// MARK: Icons — app icon, or the item's real look captured while it was on the bar (needs Screen Recording).
// macOS 27 has no per-item status windows (the bar is one layer-24 "Menubar" window; layer-25 windows are app panels),
// so crops come from a display capture and include the bar's wallpaper tint. Variants are keyed by the strip's luminance.

var iconCache: [String: NSImage] = [:]  // main thread only; the launch capture refills it after a restart
var barDark = false  // luminance of the last captured strip

var realIcons: Bool { UserDefaults.standard.string(forKey: "iconStyle") == "real" && CGPreflightScreenCaptureAccess() }
func iconKey(_ e: Extra, dark: Bool) -> String { "\(e.app.bundleIdentifier ?? "?")#\(e.index)#\(dark ? "D" : "L")" }

/// Icon for a menu/panel row, `h` points tall, aspect kept. Real capture when chosen, granted and cached; else the app icon.
func icon(_ e: Extra, height h: CGFloat) -> NSImage? {
    let real = realIcons ? iconCache[iconKey(e, dark: barDark)] : nil
    guard let img = (real ?? e.app.icon)?.copy() as? NSImage, img.size.height > 0 else { return nil }
    img.size = NSSize(width: h * img.size.width / img.size.height, height: h)
    return img
}

/// Mean luminance below half, averaged over a 128×8 downscale of the strip.
func isDark(_ img: CGImage) -> Bool {
    let w = 128, h = 8
    var px = [UInt8](repeating: 0, count: w * h * 4)
    let sum: Double = px.withUnsafeMutableBytes { buf in
        guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return 0 }
        ctx.interpolationQuality = .high
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return stride(from: 0, to: buf.count, by: 4).reduce(0) { $0 + 0.299 * Double(buf[$1]) + 0.587 * Double(buf[$1 + 1]) + 0.114 * Double(buf[$1 + 2]) }
    }
    return sum / Double(w * h) < 128
}

/// Screenshots the primary display's menu bar strip and crops every visible item out of it, then runs `done` on main.
/// Call only while items are shown: hidden ones aren't on screen.
func captureIcons(_ done: @escaping () -> Void) {
    guard realIcons else { return done() }
    let w = NSScreen.screens.first?.frame.width ?? 0
    SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, err in
        // AX read here, right before the capture, so the frames match what gets captured.
        let items = extras().filter { $0.isVisible && $0.y < 10 && $0.x >= 0 && $0.x + $0.width <= w && $0.width > 0 }
        guard let display = content?.displays.first(where: { $0.displayID == CGMainDisplayID() }),
              let h = items.map({ $0.y + $0.height }).max()
        else { log("icons: no display/items (\(err.map { "\($0)" } ?? "\(items.count) items"))"); return DispatchQueue.main.async(execute: done) }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        filter.includeMenuBar = true
        let scale = CGFloat(filter.pointPixelScale)
        let cfg = SCStreamConfiguration()
        cfg.sourceRect = CGRect(x: 0, y: 0, width: CGFloat(display.width), height: ceil(h))  // display points
        cfg.width = Int(CGFloat(display.width) * scale)
        cfg.height = Int(ceil(h) * scale)
        cfg.showsCursor = false
        SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg) { img, err in
            DispatchQueue.main.async {
                defer { done() }
                guard let img else { return log("icons: capture failed: \(err.map { "\($0)" } ?? "?")") }
                barDark = isDark(img)
                for e in items {
                    guard let crop = img.cropping(to: CGRect(x: e.x, y: e.y, width: e.width, height: e.height).applying(.init(scaleX: scale, y: scale)).integral)
                    else { continue }
                    iconCache[iconKey(e, dark: barDark)] = NSImage(cgImage: crop, size: NSSize(width: e.width, height: e.height))  // colored, not template
                }
                log("icons: display-strip capture, \(items.count) items at \(scale)x, bar \(barDark ? "dark" : "light")")
            }
        }
    }
}
