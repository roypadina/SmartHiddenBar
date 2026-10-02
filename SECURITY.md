# Security Policy

## Reporting a Vulnerability

SmartHiddenBar runs un-sandboxed with Accessibility (and optionally Screen Recording)
permission and calls a private macOS API, so security reports are taken seriously.
Please **do not** open a public issue for security problems.

Instead, use GitHub's private vulnerability reporting
(**Security → Report a vulnerability**) or email **roypadina@gmail.com**.

You'll get an acknowledgement within a few days. Once a fix is available it will be released
and the report disclosed, with credit unless you prefer otherwise.

## Scope

SmartHiddenBar runs entirely on-device and makes no network connections. Relevant areas:
the Accessibility menu replay (pressing items in other apps' menus), the optional Screen
Recording icon capture, and the private MenuBarClientCore allow-list call.
