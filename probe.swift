// One-off probe: dumps the Sound menu's AX tree with raw roles/identifiers.
// Run from a terminal that has Accessibility permission.
import Cocoa
import ApplicationServices

func attr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success else { return nil }
    return v
}
func str(_ el: AXUIElement, _ name: String) -> String { attr(el, name) as? String ?? "" }
func intVal(_ el: AXUIElement) -> String {
    guard let v = attr(el, kAXValueAttribute) else { return "-" }
    return "\(v)"
}
func kids(_ el: AXUIElement) -> [AXUIElement] { (attr(el, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }

func dump(_ el: AXUIElement, _ depth: Int) {
    let pad = String(repeating: "  ", count: depth)
    print("\(pad)role=\(str(el, kAXRoleAttribute)) sub=\(str(el, kAXSubroleAttribute)) id=\(str(el, "AXIdentifier")) roleDesc=\(str(el, kAXRoleDescriptionAttribute)) val=\(intVal(el))")
    if depth < 7 { for k in kids(el) { dump(k, depth + 1) } }
}

guard let cc = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first else {
    print("ControlCenter not running"); exit(1)
}
let app = AXUIElementCreateApplication(cc.processIdentifier)

// find the Sound menu extra by identifier
var mbOpt = attr(app, "AXExtrasMenuBar") as! AXUIElement?
if mbOpt == nil { mbOpt = kids(app).first(where: { str($0, kAXRoleAttribute) == "AXMenuBar" }) }
guard let mb = mbOpt else { print("no menu bar"); exit(1) }
guard let sound = kids(mb).first(where: { str($0, "AXIdentifier") == "com.apple.menuextra.sound" }) else {
    print("no sound menu extra; items:")
    for k in kids(mb) { print("  id=\(str(k, "AXIdentifier")) desc=\(str(k, kAXDescriptionAttribute))") }
    exit(1)
}
print("pressing sound menu extra...")
AXUIElementPerformAction(sound, kAXPressAction as CFString)

var windows: [AXUIElement] = []
for _ in 0..<25 {
    usleep(200_000)
    windows = (attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
    if !windows.isEmpty { break }
}
guard let win = windows.first else { print("no window appeared"); exit(1) }
dump(win, 0)

// close it again
AXUIElementPerformAction(sound, kAXPressAction as CFString)
