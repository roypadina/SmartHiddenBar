import AppKit
import Carbon
import SwiftUI

// MARK: Global shortcuts — Carbon hot keys, recorded in Settings. Stored per action as "keyCode:carbonMods"; "" = off.

/// Defaults key, Settings label, EventHotKeyID.id (the hot-key handler in main.swift dispatches on it).
let shortcutActions: [(key: String, label: String, id: UInt32)] = [
    ("toggleShortcut", "Show / hide items", 1), ("barShortcut", "Icon bar", 2), ("appsShortcut", "List apps", 3),
    ("settingsShortcut", "Settings", 4), ("quitShortcut", "Quit", 5),
]

struct Shortcut: Equatable {
    let key: Int, mods: Int
    init(key: Int, mods: Int) { self.key = key; self.mods = mods }
    init?(_ s: String?) {
        let p = (s ?? "").split(separator: ":").compactMap { Int($0) }
        guard p.count == 2, (0...0xFFFF).contains(p[0]), (0...Int(UInt32.max)).contains(p[1]) else { return nil }  // corrupt defaults must not trap
        (key, mods) = (p[0], p[1])
    }
    static func stored(_ defaultsKey: String) -> Shortcut? { Shortcut(UserDefaults.standard.string(forKey: defaultsKey)) }
    var string: String { "\(key):\(mods)" }
    /// Shows the shortcut on a menu row (character keys only; others keep the row's fallback).
    func show(on item: NSMenuItem) {
        let k = keyName(key)
        guard k.count == 1 else { return }
        item.keyEquivalent = k.lowercased()
        var m = NSEvent.ModifierFlags()
        if mods & controlKey != 0 { m.insert(.control) }
        if mods & optionKey != 0 { m.insert(.option) }
        if mods & shiftKey != 0 { m.insert(.shift) }
        if mods & cmdKey != 0 { m.insert(.command) }
        item.keyEquivalentModifierMask = m
    }
    var label: String {
        [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")].filter { mods & $0.0 != 0 }.map(\.1).joined() + keyName(key)
    }
}

/// Key name in the current ASCII-capable layout (so ⌃⌥B reads B under Hebrew too); fixed names for non-character keys.
func keyName(_ code: Int) -> String {
    let fn = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
              kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20]
    if let i = fn.firstIndex(of: code) { return "F\(i + 1)" }
    let named = [kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
                 kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
                 kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟"]
    if let n = named[code] { return n }
    guard let src = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
          let raw = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) else { return "#\(code)" }
    let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue()
    var dead: UInt32 = 0, len = 0, chars = [UniChar](repeating: 0, count: 4)
    let err = CFDataGetBytePtr(data).withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) {
        UCKeyTranslate($0, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask),
                       &dead, chars.count, &len, &chars)
    }
    return err == noErr && len > 0 ? String(utf16CodeUnits: chars, count: len).uppercased() : "#\(code)"
}

@MainActor @Observable final class HotKeys {
    static let shared = HotKeys()
    var problems: [String: String] = [:]  // defaults key -> inline Settings message
    var recording: String?  // defaults key being recorded; our hot keys are unregistered meanwhile
    @ObservationIgnored var refs: [EventHotKeyRef] = []
    @ObservationIgnored var monitor: Any?

    /// Once: the old preset picker ("hotkey", default ⌃⌥B) becomes barShortcut. New installs get ⌃⌥B too.
    func migrate() {
        let d = UserDefaults.standard
        guard d.object(forKey: "barShortcut") == nil else { return }
        let presets = ["ctrl-opt-b": (kVK_ANSI_B, controlKey | optionKey), "ctrl-opt-cmd-m": (kVK_ANSI_M, controlKey | optionKey | cmdKey),
                       "ctrl-opt-h": (kVK_ANSI_H, controlKey | optionKey), "ctrl-opt-m": (kVK_ANSI_M, controlKey | optionKey)]
        d.set(presets[d.string(forKey: "hotkey") ?? "ctrl-opt-b"].map { Shortcut(key: $0.0, mods: $0.1).string } ?? "", forKey: "barShortcut")
        d.removeObject(forKey: "hotkey")
    }

    func unregister() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs = []
    }

    /// (Re)registers every stored shortcut; a combo another app or macOS holds is reported, not retried.
    func register() {
        guard recording == nil else { return }  // stays paused until the recorder finishes
        unregister()
        problems = [:]
        for a in shortcutActions {
            guard let s = Shortcut.stored(a.key) else { continue }
            var ref: EventHotKeyRef?
            let err = RegisterEventHotKey(UInt32(s.key), UInt32(s.mods), EventHotKeyID(signature: 0x53484252, id: a.id),  // "SHBR"
                                          GetApplicationEventTarget(), 0, &ref)
            if let ref, err == noErr { refs.append(ref) } else { problems[a.key] = "Shortcut unavailable"; log("hotkey: \(a.label) \(s.label) not registered (\(err))") }
        }
    }

    /// Captures the next ⌃/⌥/⌘ combo for `key`. Esc cancels, Delete clears; a combo the other action uses is refused.
    func record(_ key: String) {
        stopRecording()
        unregister()  // so a combo we currently hold reaches the recorder
        recording = key
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            self?.recorded(e)
            return nil
        }
    }

    func recorded(_ e: NSEvent) {
        guard let key = recording else { return }
        let f = e.modifierFlags.intersection([.control, .option, .command, .shift])
        if f.isEmpty, e.keyCode == UInt16(kVK_Escape) { return stopRecording() }
        if f.isEmpty, [kVK_Delete, kVK_ForwardDelete].contains(Int(e.keyCode)) { UserDefaults.standard.set("", forKey: key); return stopRecording() }
        guard !f.isDisjoint(with: [.control, .option, .command]) else { return NSSound.beep() }  // ⇧ alone isn't enough
        let mods = [(NSEvent.ModifierFlags.control, controlKey), (.option, optionKey), (.command, cmdKey), (.shift, shiftKey)]
            .filter { f.contains($0.0) }.reduce(0) { $0 | $1.1 }
        let s = Shortcut(key: Int(e.keyCode), mods: mods)
        if let other = shortcutActions.first(where: { $0.key != key && Shortcut.stored($0.key) == s }) {
            problems[key] = "\(s.label) is already used for \(other.label)"
            return NSSound.beep()
        }
        UserDefaults.standard.set(s.string, forKey: key)
        stopRecording()
    }

    func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard recording != nil else { return }
        recording = nil
        register()
    }
}

/// Settings row: the shortcut (click to record), Off to clear, inline problems.
struct ShortcutRow: View {
    let key: String, label: String
    var hk = HotKeys.shared
    @AppStorage var value: String
    init(key: String, label: String) { self.key = key; self.label = label; _value = AppStorage(wrappedValue: "", key) }

    var body: some View {
        LabeledContent {
            HStack {
                Button(hk.recording == key ? "Press shortcut…" : Shortcut(value)?.label ?? "Record") {
                    hk.recording == key ? hk.stopRecording() : hk.record(key)
                }
                if !value.isEmpty, hk.recording != key {
                    Button("Off") { value = ""; hk.register() }
                }
            }
        } label: {
            Text(label)
            if let p = hk.problems[key] { Text(p).foregroundStyle(.red) }
        }
    }
}
