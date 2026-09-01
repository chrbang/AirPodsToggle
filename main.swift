// AirPodsToggle — menu bar app that toggles AirPods between
// Noise Cancellation and Transparency via the Sound menu's accessibility tree.
//
// Hotkey: ⌥⌘A (configurable). Verified on macOS 26 (Tahoe).
//
// Selector strategy (locale-independent):
//   * Sound menu extra:  AXIdentifier == "com.apple.menuextra.sound"
//   * Headphone row:     AXDisclosureTriangle with id prefix "sound-device-"
//   * Mode toggles:      AXCheckBoxes with the device id, after the first
//                        AXHeading with that id, until the next heading.
//                        Order is Off, Transparency, [Adaptive,] Noise Cancellation
//                        → Transparency = 2nd, Noise Cancellation = last.

import Cocoa
import Carbon.HIToolbox
import ApplicationServices

// MARK: - AX helpers

func axAttr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success else { return nil }
    return v
}
func axRole(_ el: AXUIElement) -> String { axAttr(el, kAXRoleAttribute) as? String ?? "" }
func axId(_ el: AXUIElement) -> String { axAttr(el, "AXIdentifier") as? String ?? "" }
func axIntValue(_ el: AXUIElement) -> Int { (axAttr(el, kAXValueAttribute) as? NSNumber)?.intValue ?? -1 }
func axKids(_ el: AXUIElement) -> [AXUIElement] { (axAttr(el, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
func axPress(_ el: AXUIElement) { AXUIElementPerformAction(el, kAXPressAction as CFString) }

func findFirst(_ el: AXUIElement, depth: Int = 0, where match: (AXUIElement) -> Bool) -> AXUIElement? {
    if match(el) { return el }
    guard depth < 8 else { return nil }
    for k in axKids(el) {
        if let hit = findFirst(k, depth: depth + 1, where: match) { return hit }
    }
    return nil
}

enum ToggleError: Error, CustomStringConvertible {
    case notTrusted, noControlCenter, noSoundExtra, noWindow, noHeadphones, noToggles

    var description: String {
        switch self {
        case .notTrusted: return "Accessibility permission missing"
        case .noControlCenter: return "Control Center is not running"
        case .noSoundExtra: return "Sound icon not found in the menu bar"
        case .noWindow: return "Sound menu did not open"
        case .noHeadphones: return "No AirPods in the Sound menu — are they connected?"
        case .noToggles: return "Noise-control buttons not found"
        }
    }
}

// MARK: - The toggle

struct SoundMenu {
    let app: AXUIElement
    let extraItem: AXUIElement

    static func locate() throws -> SoundMenu {
        guard let cc = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.controlcenter").first else { throw ToggleError.noControlCenter }
        let app = AXUIElementCreateApplication(cc.processIdentifier)
        var menuBar = axAttr(app, "AXExtrasMenuBar").map { $0 as! AXUIElement }
        if menuBar == nil {
            menuBar = axKids(app).first(where: { axRole($0) == "AXMenuBar" })
        }
        guard let mb = menuBar,
              let sound = axKids(mb).first(where: { axId($0) == "com.apple.menuextra.sound" })
        else { throw ToggleError.noSoundExtra }
        return SoundMenu(app: app, extraItem: sound)
    }

    func open() throws -> AXUIElement {
        for attempt in 0..<2 {
            axPress(extraItem)
            for _ in 0..<20 {
                usleep(200_000)
                if let win = (axAttr(app, kAXWindowsAttribute) as? [AXUIElement])?.first { return win }
            }
            // a stale open menu makes the first press close it; retry once
            if attempt == 0 { usleep(300_000) }
        }
        throw ToggleError.noWindow
    }

    func close() { axPress(extraItem) }

    enum Mode {
        case noiseCancellation, transparency, offOrAdaptive
    }

    /// Opens the menu, locates the noise-control toggles, runs `body`, closes.
    private func withToggles<T>(_ body: ([AXUIElement]) throws -> T) throws -> T {
        let win = try open()
        defer { close() }

        guard let scrollArea = findFirst(win, where: { axRole($0) == "AXScrollArea" })
        else { throw ToggleError.noToggles }

        guard let disclosure = axKids(scrollArea).first(where: {
            axRole($0) == "AXDisclosureTriangle" && axId($0).hasPrefix("sound-device-")
        }) else { throw ToggleError.noHeadphones }
        let deviceId = axId(disclosure)

        if axIntValue(disclosure) == 0 {
            axPress(disclosure)
            usleep(500_000)
        }

        var seenHeading = false
        var toggles: [AXUIElement] = []
        for el in axKids(scrollArea) where axId(el) == deviceId {
            if axRole(el) == "AXHeading" {
                if seenHeading { break }
                seenHeading = true
            } else if seenHeading && axRole(el) == "AXCheckBox" {
                toggles.append(el)
            }
        }
        // 4 modes on AirPods Pro / AirPods 4 ANC, 3 on AirPods Max
        guard toggles.count >= 3 else { throw ToggleError.noToggles }
        return try body(toggles)
    }

    private static func mode(of toggles: [AXUIElement]) -> Mode {
        if axIntValue(toggles.last!) == 1 { return .noiseCancellation }
        if axIntValue(toggles[1]) == 1 { return .transparency }
        return .offOrAdaptive
    }

    /// Toggles NC ↔ Transparency; returns the mode switched to.
    func toggleNoiseMode() throws -> Mode {
        try withToggles { toggles in
            if Self.mode(of: toggles) == .noiseCancellation {
                axPress(toggles[1])
                usleep(300_000)
                return .transparency
            } else {
                axPress(toggles.last!)
                usleep(300_000)
                return .noiseCancellation
            }
        }
    }
}

// MARK: - App

/// The user-configurable toggle shortcut, persisted in UserDefaults.
struct Shortcut {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var keyChar: String       // for the menu item's key equivalent
    var display: String       // e.g. "⌥⌘A"

    static let `default` = Shortcut(keyCode: UInt32(kVK_ANSI_A),
                                    carbonModifiers: UInt32(cmdKey | optionKey),
                                    keyChar: "a", display: "⌥⌘A")

    static func load() -> Shortcut {
        let d = UserDefaults.standard
        guard d.object(forKey: "keyCode") != nil else { return .default }
        return Shortcut(keyCode: UInt32(d.integer(forKey: "keyCode")),
                        carbonModifiers: UInt32(d.integer(forKey: "carbonModifiers")),
                        keyChar: d.string(forKey: "keyChar") ?? "",
                        display: d.string(forKey: "display") ?? "")
    }

    func save() {
        let d = UserDefaults.standard
        d.set(Int(keyCode), forKey: "keyCode")
        d.set(Int(carbonModifiers), forKey: "carbonModifiers")
        d.set(keyChar, forKey: "keyChar")
        d.set(display, forKey: "display")
    }

    var menuModifierMask: NSEvent.ModifierFlags {
        var f: NSEvent.ModifierFlags = []
        if carbonModifiers & UInt32(cmdKey) != 0 { f.insert(.command) }
        if carbonModifiers & UInt32(optionKey) != 0 { f.insert(.option) }
        if carbonModifiers & UInt32(controlKey) != 0 { f.insert(.control) }
        if carbonModifiers & UInt32(shiftKey) != 0 { f.insert(.shift) }
        return f
    }

    static func from(event: NSEvent) -> Shortcut {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }

        var symbols = ""
        if flags.contains(.control) { symbols += "⌃" }
        if flags.contains(.option) { symbols += "⌥" }
        if flags.contains(.shift) { symbols += "⇧" }
        if flags.contains(.command) { symbols += "⌘" }

        let keyChar = event.charactersIgnoringModifiers ?? ""
        let keyName: String
        switch Int(event.keyCode) {
        case kVK_Space: keyName = "Space"
        case kVK_Return: keyName = "↩"
        case kVK_Tab: keyName = "⇥"
        case kVK_LeftArrow: keyName = "←"
        case kVK_RightArrow: keyName = "→"
        case kVK_UpArrow: keyName = "↑"
        case kVK_DownArrow: keyName = "↓"
        case kVK_F1...kVK_F12 where keyChar.unicodeScalars.first?.value ?? 0 >= 0xF704:
            keyName = "F\(Int(keyChar.unicodeScalars.first!.value) - 0xF704 + 1)"
        default: keyName = keyChar.uppercased()
        }
        return Shortcut(keyCode: UInt32(event.keyCode), carbonModifiers: carbon,
                        keyChar: keyChar.lowercased(), display: symbols + keyName)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKeyRef: EventHotKeyRef?
    private var toggleMenuItem: NSMenuItem!
    private var shortcut = Shortcut.load()
    private var recorderWindow: NSWindow?
    private var keyMonitor: Any?
    private let queue = DispatchQueue(label: "toggle", qos: .userInitiated)

    /// Last mode the app set; nil until the first toggle.
    private var currentMode: SoundMenu.Mode?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About AirPodsToggle", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        toggleMenuItem = NSMenuItem(title: "Toggle Noise Mode", action: #selector(toggleFromMenu), keyEquivalent: "")
        menu.addItem(toggleMenuItem)
        menu.addItem(NSMenuItem(title: "Change Shortcut…", action: #selector(changeShortcut), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit AirPodsToggle", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        updateMenuKeyEquivalent()

        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)

        installHotKeyHandler()
        registerHotKey()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.ensureSoundIconVisible()
        }
    }

    /// The app drives the Sound menu, so the Sound icon must always be in the
    /// menu bar. The macOS default is "show when active" — offer to fix that.
    private func ensureSoundIconVisible() {
        let domain = "com.apple.controlcenter" as CFString
        let key = "Sound" as CFString
        let current = CFPreferencesCopyValue(key, domain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost) as? Int
        guard current != 18 else { return } // 18 = "Always Show in Menu Bar"

        let alert = NSAlert()
        alert.messageText = "Show the Sound icon in the menu bar?"
        alert.informativeText = """
        AirPodsToggle works through the Sound menu, so the Sound icon must \
        always be visible in the menu bar — by default macOS only shows it \
        while audio is playing.

        This can also be changed later in System Settings → Control Center → Sound.
        """
        alert.addButton(withTitle: "Always Show Sound Icon")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            CFPreferencesSetValue(key, 18 as CFNumber, domain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
            CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            p.arguments = ["ControlCenter"]
            try? p.run()
        }
    }

    private func updateMenuKeyEquivalent() {
        toggleMenuItem.keyEquivalent = shortcut.keyChar
        toggleMenuItem.keyEquivalentModifierMask = shortcut.menuModifierMask
    }

    // MARK: Shortcut recording

    @objc func changeShortcut() {
        if recorderWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 110),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "AirPodsToggle"
            w.isReleasedWhenClosed = false
            w.center()
            let label = NSTextField(wrappingLabelWithString:
                "Press the new toggle shortcut now.\nInclude ⌘, ⌥ or ⌃. Press Esc to cancel.")
            label.alignment = .center
            label.frame = NSRect(x: 20, y: 25, width: 320, height: 60)
            label.autoresizingMask = [.width]
            w.contentView?.addSubview(label)
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                                   object: w, queue: .main) { [weak self] _ in
                self?.stopRecording()
            }
            recorderWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        recorderWindow?.makeKeyAndOrderFront(nil)

        if keyMonitor == nil {
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.recorderWindow?.isKeyWindow == true else { return event }
                if Int(event.keyCode) == kVK_Escape {
                    self.recorderWindow?.close()
                    return nil
                }
                let flags = event.modifierFlags.intersection([.command, .option, .control])
                guard !flags.isEmpty else { return nil } // require a real modifier
                let new = Shortcut.from(event: event)
                self.apply(shortcut: new)
                self.recorderWindow?.close()
                return nil
            }
        }
    }

    private func stopRecording() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    private func apply(shortcut new: Shortcut) {
        shortcut = new
        new.save()
        registerHotKey()
        updateMenuKeyEquivalent()
        flash(new.display)
    }

    @objc func showAbout() {
        let credits = NSMutableAttributedString()
        func add(_ text: String, bold: Bool = false) {
            credits.append(NSAttributedString(string: text, attributes: [
                .font: bold ? NSFont.boldSystemFont(ofSize: 11) : NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.labelColor,
            ]))
        }
        add("Toggle AirPods between Noise Cancellation and Transparency — with a global hotkey (default ⌥⌘A) or from the menu bar icon.\n\n")
        add("How it works\n", bold: true)
        add("macOS has no public API for AirPods listening modes, so AirPodsToggle does what a human would do: it opens the Sound menu in the menu bar and clicks the mode for you, using macOS accessibility. That's why the app needs the Accessibility permission, and why the Sound menu flashes briefly on each toggle.\n\n")
        add("Menu bar icon\n", bold: true)
        add("Slashed waveform = Noise Cancellation (outside sound blocked). Open waveform = Transparency. Dimmed = mode unknown. The icon shows the last mode the app set, so it can lag if the mode is changed elsewhere (e.g. squeezing the AirPods stem) until the next toggle.\n\n")
        add("Requirements\n", bold: true)
        add("macOS 26 (Tahoe) or newer, and AirPods with noise control — AirPods Pro, AirPods Max, or AirPods 4 with ANC.\n\n")
        add("Created by Christer Bang, Oslo · 2026")

        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    @objc func toggleFromMenu() { toggle() }

    /// Menu bar icon = current mode: open waveform (Transparency),
    /// slashed waveform (Noise Cancellation), dimmed (unknown / Off / Adaptive).
    private func updateIcon() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let button = self.statusItem.button else { return }
            let symbol: String
            let dimmed: Bool
            let tip: String
            switch self.currentMode {
            case .noiseCancellation:
                symbol = "waveform.slash"; dimmed = false; tip = "AirPods: Noise Cancellation"
            case .transparency:
                symbol = "waveform"; dimmed = false; tip = "AirPods: Transparency"
            case .offOrAdaptive:
                symbol = "waveform"; dimmed = true; tip = "AirPods: Off or Adaptive"
            case nil:
                symbol = "waveform"; dimmed = true; tip = "AirPods mode unknown — toggle to update"
            }
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
            button.appearsDisabled = dimmed
            button.toolTip = tip
        }
    }

    private func ensureTrusted() -> Bool {
        if AXIsProcessTrusted() { return true }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        return false
    }

    func toggle() {
        guard ensureTrusted() else { return }
        queue.async { [weak self] in
            do {
                let mode = try SoundMenu.locate().toggleNoiseMode()
                self?.currentMode = mode
            } catch {
                NSLog("AirPodsToggle failed: \(error)")
                self?.currentMode = nil
                self?.flash("⚠️")
            }
            self?.updateIcon()
        }
    }

    /// Briefly show the new mode next to the menu bar icon.
    private func flash(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.button?.title = " \(text)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self?.statusItem.button?.title = ""
            }
        }
    }

    private func installHotKeyHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, _, userData -> OSStatus in
            guard let userData else { return noErr }
            Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue().toggle()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    private func registerHotKey() {
        if let old = hotKeyRef {
            UnregisterEventHotKey(old)
            hotKeyRef = nil
        }
        let hotKeyID = EventHotKeyID(signature: OSType(0x4150_5447) /* 'APTG' */, id: 1)
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers,
                                         hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("AirPodsToggle: hotkey registration failed (\(status)) — combo may be taken")
            flash("⚠️")
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
