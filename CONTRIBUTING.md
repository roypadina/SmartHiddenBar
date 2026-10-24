# Contributing to SmartHiddenBar

Thanks for your interest! Bug reports, feature ideas, docs and code are all welcome.

## Ground rules

- **`main` is protected.** No direct pushes; changes land via Pull Request and are
  reviewed/merged by the maintainer ([@roypadina](https://github.com/roypadina)).
- Be respectful — see the [Code of Conduct](CODE_OF_CONDUCT.md).
- Keep changes focused. One logical change per PR, smallest diff that solves it.

## Getting started

```bash
git clone https://github.com/roypadina/SmartHiddenBar.git
cd SmartHiddenBar
./build.sh        # builds build/SmartHiddenBar.app and installs it to /Applications
```

Requirements: **macOS 27**, Xcode command line tools (`swiftc`). The app must run from
`/Applications` (see the README); `build.sh` refuses to replace a running copy, so quit it first.

`./build.sh` signs with a stable local code-signing identity (the name is set in `build.sh`; edit it to yours, or set `SHB_SIGN_IDENTITY`) if present and
falls back to ad-hoc otherwise. Ad-hoc changes the code hash every build, so you must
re-grant Accessibility after each rebuild
(`tccutil reset Accessibility com.roypadina.SmartHiddenBar`, then grant again).
Create your own self-signed code-signing certificate and edit `ID` in `build.sh` to avoid that.

## Layout

Plain Swift files in the repo root, compiled together by `swiftc`: `main.swift` (status item,
clicks, icon bar, menu mirroring), `Hiding.swift` (private allow-list), `AX.swift`
(Accessibility inventory), `Icons.swift`, `Settings.swift`. There is no test suite; describe
how you verified your change in the PR.

## Workflow

1. **Fork** and branch: `git checkout -b feat/my-thing`.
2. Make your change; build with `./build.sh` and try it on a real menu bar.
3. Match the surrounding style; no drive-by refactors.
4. Open a **Pull Request** against `main`. CI must be green and the maintainer must approve.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org): `feat: ...`, `fix: ...`, `docs: ...`.

## Feature requests and bugs

- **Feature requests:** [open one](https://github.com/roypadina/SmartHiddenBar/issues/new?template=feature_request.yml) and say what you're trying to do; that matters more than the exact feature. Search the [open requests](https://github.com/roypadina/SmartHiddenBar/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement) first and 👍 an existing one if it's there.
- **Bugs:** use the [bug report](https://github.com/roypadina/SmartHiddenBar/issues/new?template=bug_report.yml). Include your macOS build and attach `~/Library/Logs/SmartHiddenBar.log`.
- **Ko-fi supporters:** add your Ko-fi name to the request and it goes to the front of my queue. It's a thank-you, not a purchase: no promise on what ships or when.
- **Bigger changes:** open an issue before the PR so we agree on the shape first. Small, focused PRs can come straight in.
- Replies are best effort, evenings and weekends. I read everything.
