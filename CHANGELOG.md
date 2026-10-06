# Changelog

All notable changes to SmartHiddenBar are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/roypadina/SmartHiddenBar/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/roypadina/SmartHiddenBar/compare/v1.1.3...v1.2.0
[1.1.3]: https://github.com/roypadina/SmartHiddenBar/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/roypadina/SmartHiddenBar/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/roypadina/SmartHiddenBar/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/roypadina/SmartHiddenBar/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/roypadina/SmartHiddenBar/releases/tag/v1.0.0
