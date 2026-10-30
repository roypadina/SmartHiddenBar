# SmartHiddenBar demo — storyboard (12.1 s, loops)

Real parts: the status glyph is the app's own asset (`Assets/icons/fold-chevron/menubar-{shown,hidden}@2x.png`, picked by `Lister.updateIcon`,
`main.swift:300` @ v1.4.0). The flow has no SwiftUI views (status item + icon bar are AppKit in `main.swift`), so nothing is compiled; geometry
and behaviour are copied with `// main.swift:line` comments in `scene.swift`: icon bar = `Lister.showBar` (`:445-476`: spacing 10, insets 6/10,
radius 8, 24 pt icons, 4 pt below the bar, menu bar order), click flow = `Lister.clicked` (`:332-347`), picked menu = `show`/`mirror`
(`:420-433`, `:503-517`: titles, enabled state, separators, no shortcuts). Fake data: ten generic SF-Symbol "apps" (no real brands) and a fake
"Cloud Sync" menu (Up to date [disabled], Sync Now, Pause Syncing, Open Sync Folder, Settings…, Quit Cloud Sync). Clock "Thu Oct 30 9:41 AM".

| # | Scene | Start | Dur | What happens | Caption |
|---|-------|-------|-----|--------------|---------|
| 1 | crowded | 0.0 | 1.8 | Menu bar only: ten third-party icons crowd the right side, SmartHiddenBar's glyph (shown) last. | Too many icons for your menu bar? |
| 2 | hide | 1.8 | 2.5 | Cursor glides to the glyph, click: item highlights, the ten icons vanish at once, glyph flips to the "hidden" asset (cycle mode with nothing off the bar hides: `clicked`, `:340-343`). | One click hides everything left of its icon |
| 3 | icon bar | 4.3 | 2.6 | ⌥-click: the icon bar opens under the glyph at once (`:335`), ten app icons in menu-bar order. Cursor glides to the cloud icon. | ⌥-click opens an icon bar of hidden apps |
| 4 | menu | 6.9 | 3.0 | Click the cloud icon: the app's menu opens under it at once (disabled "Up to date" row gray). Cursor hovers Sync Now, moves to Pause Syncing, click: menu and icon bar close at once (`defer { hideBar() }`, `:423`), cursor fades. | Use a hidden app's menu without unhiding it |
| 5 | show | 9.9 | 2.2 | Cursor glides to the glyph, click: ten icons return at once, glyph flips back to "shown", cursor fades. Last 0.2 s dissolves into scene 1 (clean loop). | Click again to bring them all back |

Transitions: 0.2 s crossfade between scenes; captions fade old 0–0.12 s / new 0.12–0.35 s (never two pills at once).
Cursor: system arrow (`NSCursor.arrow`), eased 0.4–0.75 s glides on a slight arc, click = dip + white ripple; visible only while it points at something.
Render: `./render.sh` (swiftc + 30 fps frames + encode; passes `SHB_ASSETS` = the app's `Assets/icons/fold-chevron`).
