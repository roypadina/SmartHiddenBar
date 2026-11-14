import AppKit

// Self-check for the pure hide logic and the Ko-fi card's ask rules (no app, no Accessibility needed):
//   swiftc -target arm64-apple-macos27.0 AX.swift SupportPromptState.swift tests/main.swift -o build/selfcheck && build/selfcheck

/// Our item's frame as the bar currently lays it out; the walks below re-lay it out while they run, like MenuBarAgent.
final class Bar: @unchecked Sendable {
    private let lock = NSLock()
    private var frame: CGRect?
    init(_ x: CGFloat?) { frame = x.map(at) }
    func own() -> CGRect? { lock.withLock { frame } }
    func move(_ x: CGFloat?) { lock.withLock { frame = x.map(at) } }
}
func at(_ x: CGFloat) -> CGRect { CGRect(x: x, y: 0, width: 22, height: 24) }

// Issue #7 follow-up (1.3.4 log 15:50:06): the cached hide had just made macOS drop iStat Menus' items right of us, so our
// item moved 2929 → 3289 while the walk still held a neighbour's pre-shift x: it read left of us and was hidden too.
var bar = Bar(2929)
precondition(settledRead({ bar.move(3289); return "walk" }, bar.own) == nil, "our item moved during the walk: re-read")

// Live repro 2026-10-30 (PFLIP, width flipping every 0.4 s): wide and back within one walk, so before == after, yet the
// walk read the other apps in the other layout (iStat, left of us, flipped allowed/denied).
bar = Bar(3717)
precondition(settledRead({ bar.move(3897); usleep(100_000); bar.move(3717); return "walk" }, bar.own) == nil,
             "our item moved and came back during the walk: re-read")

// Same live repro, sampled build: our item stayed put through the whole walk, yet iStat and Slack still came back in the
// previous layout — other apps' AX frames trail a re-layout. A move shortly before the walk must count too.
bar = Bar(1156)
DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { bar.move(1336) }
precondition(settledRead({ "walk" }, bar.own) == nil, "our item moved just before the walk: other apps may still lag")

bar = Bar(2929)
let still = settledRead({ usleep(50_000); return "walk" }, bar.own)
precondition(still?.0 == "walk" && still?.1 == at(2929), "still: use the walk and our frame from the same read")
precondition(settledRead({ "walk" }, Bar(nil).own)?.0 == "walk", "own item not found throughout: pass on, applyHide releases")
bar = Bar(2929)
precondition(settledRead({ bar.move(nil); return "walk" }, bar.own) == nil, "own item vanished mid-walk: re-read")

// MenuBarAgent shows an allowed bundle only when it runs from inside /Applications and LaunchServices resolves its id to
// that same copy (probe matrix 2026-10-30: top-level and nested-in-/Applications shown, ~/Library/Application Support not).
let u = { (p: String) in URL(fileURLWithPath: p) }
let top = u("/Applications/SHBP Top.app"), nested = u("/Applications/iStat Menus.app/Contents/Resources/iStat Menus Menubar.app")
let support = u("/Users/x/Library/Application Support/iStat Menus 7/iStat Menus Menubar.app")
precondition(menuBarCanShow(running: top, resolved: top), "top-level /Applications app")
precondition(menuBarCanShow(running: nested, resolved: nested), "helper nested in an /Applications app")
precondition(!menuBarCanShow(running: support, resolved: support), "runs from Application Support")
precondition(!menuBarCanShow(running: nested, resolved: support), "LaunchServices picks another copy")
precondition(!menuBarCanShow(running: nested, resolved: nil), "id unknown to LaunchServices")
precondition(!menuBarCanShow(running: u("/Applications-old/X.app"), resolved: u("/Applications-old/X.app")), "prefix, not a folder")

// Settings › "Apps on both sides of the icon": the allow-list is per bundle, so an app with items left and right of us
// (iStat Menus) is shown whole (default) or hidden whole.
let seenRight: Set = ["com.bjango.istatmenus.status", "HamedElfayome.Claude-Usage"]
let seenLeft: Set = ["com.bjango.istatmenus.status", "ru.keepcoder.Telegram"]
precondition(rightOfUs(seenRight, seenLeft, splitHides: false) == seenRight, "split app shown: default, as before")
precondition(rightOfUs(seenRight, seenLeft, splitHides: true) == ["HamedElfayome.Claude-Usage"], "split app hidden")

// Relaunch repro 2026-11-04: Agents Monitor quit and relaunched while hiding never showed up in the walk (an item created
// while its app is off the list is not placed, so AX never lists it): known apps are allowed though absent from the walk.
let known: Set = ["com.roy.agentsmonitor", "com.padina.vaultbar"]
precondition(visibleBundles(hidden: true, right: ["com.roy.meetalert"], left: [], parked: [], known: known,
                            denied: ["com.padina.vaultbar"]) == ["com.roy.meetalert", "com.roy.agentsmonitor"],
             "hidden: relaunched known app allowed ahead, one seen left of us still denied")
precondition(visibleBundles(hidden: false, right: [], left: [], parked: [], known: known, denied: ["com.padina.vaultbar"])
             == known, "shown: every known app, denied ones too")

// Ko-fi support card: MeetAlert's ask rules, counted in tidy-ups (reveal → use → auto-hide).
let day = SupportPromptState.day, install = Date(timeIntervalSince1970: 1_794_528_000)  // 2026-11-13
func mayAsk(_ s: SupportPromptState, day d: Double, tidyUps: Int = 50, version: String = "1.7.0") -> Bool {
    s.mayAsk(now: install.addingTimeInterval(d * day), installDate: install, tidyUps: tidyUps, appVersion: version)
}
var ask = SupportPromptState()
precondition(!mayAsk(ask, day: 6.9), "first ask: not before 7 days")
precondition(!mayAsk(ask, day: 60, tidyUps: 40) && !mayAsk(ask, day: 60, tidyUps: 0), "never at 40 tidy-ups or fewer")
precondition(mayAsk(ask, day: 7, tidyUps: 41), "7 days and more than 40 tidy-ups")
ask.record(.snooze, now: install.addingTimeInterval(10 * day), appVersion: "1.7.0")
precondition(!mayAsk(ask, day: 23.9) && mayAsk(ask, day: 24), "snooze: 14 days")
ask = SupportPromptState()
ask.record(.support, now: install.addingTimeInterval(10 * day), appVersion: "1.7.0")
precondition(!mayAsk(ask, day: 189) && mayAsk(ask, day: 190), "a tip: 180 days quiet")
ask = SupportPromptState()
ask.record(.never, now: install.addingTimeInterval(10 * day), appVersion: "1.7.0")
precondition(!mayAsk(ask, day: 300, version: "1.9.0"), "never: a feature release must not undo it")
precondition(!mayAsk(ask, day: 50, version: "2.0.0"), "never: a major release within 90 days must not undo it")
precondition(mayAsk(ask, day: 100, version: "2.0.0"), "never: next major and 90 days")
ask = SupportPromptState()
for d in [10.0, 40, 70] { ask.recordShown(install.addingTimeInterval(d * day)) }
precondition(!mayAsk(ask, day: 300) && mayAsk(ask, day: 376), "at most 3 asks per rolling 365 days")
precondition((try? JSONDecoder().decode(SupportPromptState.self, from: Data("{}".utf8))) == SupportPromptState(), "empty state decodes")
let partial = try! JSONDecoder().decode(SupportPromptState.self, from: Data(#"{"snoozedUntil":0,"futureKey":1}"#.utf8))
precondition(partial.snoozedUntil == Date(timeIntervalSinceReferenceDate: 0) && partial.shownAt.isEmpty,
             "old or partial state: known keys survive missing and unknown ones")

print("selfcheck: ok")
