# AirPodsToggle

Toggle AirPods between **Noise Cancellation** and **Transparency** with a global hotkey (default **⌥⌘A**) or from a menu bar icon, on macOS.

macOS has no public API for AirPods listening modes, so AirPodsToggle does what a human would do: it opens the Sound menu in the menu bar and clicks the mode for you, via the macOS accessibility API. That's why it needs the Accessibility permission, and why the Sound menu flashes briefly on each toggle.

## Requirements

- macOS 26 (Tahoe) or newer
- AirPods with noise control: AirPods Pro, AirPods Max, or AirPods 4 with ANC

## Install (download, don't build)

1. Go to [**Releases**](../../releases/latest) and download `AirPodsToggle.zip` from the latest release.
2. Unzip and drag `AirPodsToggle.app` into your Applications folder, then double-click it.
3. macOS will refuse to open it ("Apple could not verify…") — expected, the app isn't notarized. Go to **System Settings → Privacy & Security**, scroll down, click **Open Anyway**, and confirm. Needed once per version.
4. Grant Accessibility when prompted: **System Settings → Privacy & Security → Accessibility → enable AirPodsToggle**.
5. If asked, let the app make the Sound icon always visible in the menu bar — it needs that menu to exist.

To start it automatically: **System Settings → General → Login Items → add AirPodsToggle**.

## Use

- Press **⌥⌘A** to toggle Noise Cancellation / Transparency.
- The menu bar icon shows the mode: **slashed waveform = Noise Cancellation** (outside sound blocked), **open waveform = Transparency**, **dimmed = unknown** (or Off/Adaptive). The icon reflects the last mode the app set — if the mode is changed elsewhere (AirPods stem squeeze, Control Center), it catches up on the next toggle.
- Click the menu bar icon to toggle from a menu, change the shortcut (**Change Shortcut…**), see the About info, or quit.
- A ⚠️ flash means the toggle failed — usually the AirPods aren't connected.

## Build from source

```sh
./build.sh      # universal build → installs to ~/Applications
./package.sh    # build + zip for distribution → dist/AirPodsToggle.zip
./make_icon.sh  # regenerate AppIcon.icns from make_icon.swift
```

No Xcode project, no dependencies — one `swiftc` invocation per architecture. Note: the app is ad-hoc signed, so after every rebuild macOS drops the Accessibility grant; re-enable it in System Settings.

## How the automation works

The accessibility selectors are locale-independent and verified on macOS 26:

- Sound menu extra: `AXIdentifier == com.apple.menuextra.sound` (must be always-visible; the app offers to set this on first run)
- Headphone row: first `AXDisclosureTriangle` with an id prefixed `sound-device-`
- Mode toggles: the `AXCheckBox` run after the first `AXHeading` carrying the device id — order is Off, Transparency, [Adaptive,] Noise Cancellation, so **Transparency = 2nd, Noise Cancellation = last** (also correct for 3-mode AirPods Max)

The one thing the app does outside the accessibility tree: if the Sound icon is not set to always show in the menu bar, it offers to fix that. On consent it writes the Control Center preference for the Sound menu extra and restarts the Control Center process (`killall ControlCenter`) so the change takes effect. Nothing happens without clicking the button in that dialog.

The app makes no network requests and stores only the chosen shortcut, in its own `UserDefaults`.

`probe.swift` dumps the live accessibility tree of the Sound menu — run it after a macOS update if the app stops working:

```sh
swiftc -O probe.swift -o probe && ./probe
```

## Maintainer notes

- Version lives in one place: the `Info.plist` heredoc in `build.sh`. The About panel reads it at runtime.
- To cut a release: bump the version, run `./package.sh`, create a GitHub release with `dist/AirPodsToggle.zip` attached.

---

## Reporting issues

Bugs and feature requests go to [GitHub Issues](../../issues). For anything security-related, see [SECURITY.md](SECURITY.md).

## License

MIT — see [LICENSE](LICENSE). Created by Christer Bang, Oslo · 2026. The app is not notarized and comes with no warranty.
