# Security

AirPodsToggle asks for the macOS Accessibility permission and ships without notarization, so it is fair to want to know what it does with that access.

## What the app does

- Reads and clicks items in the Sound menu of Control Center through the macOS accessibility API. That is the only way to change AirPods listening modes without a private API.
- Registers one global hotkey and stores the chosen shortcut in its own `UserDefaults`.
- On explicit consent, sets the Control Center preference that keeps the Sound icon visible and restarts the Control Center process to apply it.

## What the app does not do

- No network access of any kind.
- No reading of other apps' windows or content beyond the Sound menu.
- No files written outside its own preferences.

The full source is in this repository and builds with a single `swiftc` invocation per architecture (see `build.sh`), so the shipped binary can be reproduced and compared.

## Reporting a vulnerability

Open a [GitHub issue](../../issues/new). If the problem should not be public yet, use GitHub's private vulnerability reporting on the Security tab of this repository. Reports are handled on a best-effort basis; this is a personal project with no security team behind it.
