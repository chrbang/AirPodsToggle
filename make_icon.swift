// Generates icon_1024.png — run via `swift make_icon.swift`, then make_icon.sh
// turns it into AppIcon.icns.
import AppKit

let px = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS-style squircle: 824pt centered in the 1024 canvas
let rect = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
NSGradient(colors: [
    NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.13, alpha: 1),
    NSColor(calibratedRed: 0.17, green: 0.28, blue: 0.42, alpha: 1),
])!.draw(in: squircle, angle: 90)

// soft "transparency" arcs behind the glyph
NSColor(calibratedWhite: 1.0, alpha: 0.10).setStroke()
for (r, w) in [(300.0, 26.0), (380.0, 20.0)] {
    let arc = NSBezierPath()
    arc.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: r, startAngle: -50, endAngle: 50)
    arc.lineWidth = w
    arc.lineCapStyle = .round
    arc.stroke()
}

// AirPods glyph, tinted white
var symbol: NSImage?
for name in ["airpods.pro", "airpodspro", "airpods", "ear"] {
    if let s = NSImage(systemSymbolName: name, accessibilityDescription: nil) { symbol = s; break }
}
if let base = symbol,
   let sym = base.withSymbolConfiguration(.init(pointSize: 420, weight: .medium)) {
    let tinted = NSImage(size: sym.size, flipped: false) { r in
        sym.draw(in: r)
        NSColor.white.set()
        r.fill(using: .sourceAtop)
        return true
    }
    let targetW: CGFloat = 470
    let scale = targetW / tinted.size.width
    let targetH = tinted.size.height * scale
    tinted.draw(in: NSRect(x: (1024 - targetW) / 2, y: (1024 - targetH) / 2, width: targetW, height: targetH),
                from: .zero, operation: .sourceOver, fraction: 1.0)
} else {
    print("no symbol found"); exit(1)
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: "icon_1024.png"))
print("wrote icon_1024.png")
