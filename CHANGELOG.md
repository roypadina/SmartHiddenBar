# Changelog

All notable changes to SmartHiddenBar are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- A Welcome window on first launch (and once after this update) explains why SmartHiddenBar exists, how to hide and reach items, why it needs Accessibility, and asks for it. Open it again from Settings > About > Welcome Guide…
- Opening SmartHiddenBar again from Finder or Raycast now shows Settings, so you can get in even when macOS has dropped its icon from the menu bar.
- While Settings, About or Welcome is open, SmartHiddenBar shows in the Dock and Cmd-Tab with a menu bar: About, Settings… (⌘,), Close (⌘W) and Quit (⌘Q).
- The menu bar icon becomes a warning triangle when Accessibility isn't granted or hiding failed, with a tooltip that says what to do. Clicking it without Accessibility opens the menu with Grant Accessibility… at the top.
- The menu bar icon has a tooltip.
- Settings has a Shortcuts section that says Esc cancels and Delete turns a shortcut off, and a Permissions section that says Granted or Not granted and why Accessibility is needed. Permissions moves to the top while Accessibility is missing.

### Changed
- The first-run alert and the Accessibility prompt at launch are replaced by the Welcome window.
- Settings sections are reordered (General, Click, Shortcuts, Icon Bar, Permissions, Always Hidden, About), and the icon size label no longer shows the value.
- Menu titles: Show Items, Hide Items, Menu Bar Apps, Quit SmartHiddenBar; the Settings section Hidden items is now Icon Bar.
- The "run from Applications" alert says why and offers Show in Finder.
- Launch at login is now Open at Login, with a button when macOS needs your approval.
- VoiceOver no longer reads the decorative app icons.

## [1.3.4] - 2026-10-29

### Fixed
- With several displays, apps no longer flip between hidden and shown as you move between screens. The menu bar each app reports can lag behind the active display, so SmartHiddenBar now compares positions as distance from each display's right edge.

## [1.3.3] - 2026-10-29

### Fixed
- Hiding right after you ⌘-drag the icon, or soon after showing, no longer hides the apps to the right of the icon too ([#7](https://github.com/roypadina/SmartHiddenBar/issues/7)). SmartHiddenBar now re-reads the menu bar instead of trusting a position from before the move.

### Changed
- The log now names each app that moves into or out of the hidden set, with its position relative to the icon.

## [1.3.2] - 2026-10-25

### Changed
- Releases are now signed with a stable identity, so permissions survive future updates. After this one update you may need to re-allow Accessibility once.

## [1.3.1] - 2026-10-23

### Added
- About: request a feature / contribute. Two buttons open the feature-request form and CONTRIBUTING.md; Ko-fi supporters' requests go to the front of the queue.

## [1.3.0] - 2026-10-11

### Added
- **Disable SmartHiddenBar** in the right-click menu: nothing is hidden at all (always-hidden apps included), as if the app had quit, until you pick **Enable SmartHiddenBar**. While disabled the icon is dimmed, any click opens the menu, and the state survives a relaunch.

## [1.2.1] - 2026-10-07

### Fixed
- A menu bar app launched while SmartHiddenBar runs shows up without the whole bar flashing (the 1.1.3 "release once" step is gone; the next allow-list places the new item within about a second).

### Changed
- An app that stays off the bar although SmartHiddenBar allows it is logged once as "kept off the bar by macOS": System Settings → Menu Bar → "Allow in the Menu Bar" is off for it.

## [1.2.0] - 2026-10-06

### Added
- Adjustable icon size in the icon bar: Settings → Hidden items → "Icon size in icon bar" (16-48 pt, default 24; was a fixed 18).
- Hover an icon to see its app name.

### Changed
- Right-click on an icon opens its menu, same as a left click (over Accessibility, third-party menu bar items only offer a press).

## [1.1.3] - 2026-10-05

### Fixed
- Launch no longer stops at "Move SmartHiddenBar to /Applications" when another copy of the app (a build folder, Downloads) wins the LaunchServices lookup: the duplicate is unregistered and the /Applications copy starts.
- A menu bar app launched while hiding is active now appears.
- Settings → Always hidden list refreshes when menu bar apps launch or quit; uninstalled apps drop off it.

## [1.1.2] - 2026-10-03

### Changed
- Custom About window (no clipping); compact Settings About.

## [1.1.1] - 2026-10-03

### Added
- About section with Ko-fi/GitHub links; About and Support items in the right-click menu.

## [1.1.0] - 2026-10-02

### Added
- **Click mode per display**: show → icon bar → hide (default on the built-in display), show / hide (default on external displays), or icon bar only. Clicks act at once; double click is gone.
- **Always hidden**: apps that stay off the bar even while items are shown, reachable from the icon bar. Optionally, new menu bar apps go straight onto the list.
- Auto-rehide when the pointer leaves the menu bar.
- Hover or click empty menu bar space to show / hide (both optional, Settings → General).
- Notification Center works while hiding: clicking the clock lifts hiding until Notification Center closes.

### Changed
- Faster hiding: applies at once from the last scan; the menu bar scan runs in parallel.

### Fixed
- Quit in the right-click menu was disabled.
- Clicking the icon while the icon bar was open reopened the bar instead of hiding.

### Notes
- After updating, re-grant Accessibility (the app is ad-hoc signed).

## [1.0.0] - 2026-10-02

First public release.

### Added
- One click hides every menu bar item left of SmartHiddenBar's icon (⌘-drag to choose).
- Icon bar with everything off the bar: ⌥-click, double-click, or ⌃⌥B (recordable).
- Right-click menu: Show/Hide items, Apps (every third-party menu bar app; use its menu without unhiding it), Settings…, Quit.
- Optional real menu bar icons (Screen Recording), auto-rehide, launch at login, five recordable shortcuts.

### Notes
- Requires macOS 27. Ad-hoc signed, not notarized. Must run from `/Applications`. Grant Accessibility on first launch.

[Unreleased]: https://github.com/roypadina/SmartHiddenBar/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/roypadina/SmartHiddenBar/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/roypadina/SmartHiddenBar/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/roypadina/SmartHiddenBar/compare/v1.1.3...v1.2.0
[1.1.3]: https://github.com/roypadina/SmartHiddenBar/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/roypadina/SmartHiddenBar/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/roypadina/SmartHiddenBar/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/roypadina/SmartHiddenBar/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/roypadina/SmartHiddenBar/releases/tag/v1.0.0
