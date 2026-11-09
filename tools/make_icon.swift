// Renders the 1024×1024 app icon: pastel gradient with a soft white heart.
// Usage: swift tools/make_icon.swift Aegyo/Assets.xcassets/AppIcon.appiconset/icon.png
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let rect = NSRect(x: 0, y: 0, width: size, height: size)

let gradient = NSGradient(colors: [
    NSColor(red: 1.00, green: 0.80, blue: 0.74, alpha: 1),
    NSColor(red: 1.00, green: 0.50, blue: 0.66, alpha: 1),
    NSColor(red: 0.72, green: 0.60, blue: 1.00, alpha: 1),
])!
gradient.draw(in: rect, angle: -60)

// Heart path
let heart = NSBezierPath()
let cx: CGFloat = 512, cy: CGFloat = 470, s: CGFloat = 300
heart.move(to: NSPoint(x: cx, y: cy - s * 0.95))
heart.curve(to: NSPoint(x: cx - s, y: cy + s * 0.35),
            controlPoint1: NSPoint(x: cx - s * 0.55, y: cy - s * 0.55),
            controlPoint2: NSPoint(x: cx - s, y: cy - s * 0.15))
heart.curve(to: NSPoint(x: cx, y: cy + s * 0.6),
            controlPoint1: NSPoint(x: cx - s, y: cy + s * 0.95),
            controlPoint2: NSPoint(x: cx - s * 0.2, y: cy + s * 1.0))
heart.curve(to: NSPoint(x: cx + s, y: cy + s * 0.35),
            controlPoint1: NSPoint(x: cx + s * 0.2, y: cy + s * 1.0),
            controlPoint2: NSPoint(x: cx + s, y: cy + s * 0.95))
heart.curve(to: NSPoint(x: cx, y: cy - s * 0.95),
            controlPoint1: NSPoint(x: cx + s, y: cy - s * 0.15),
            controlPoint2: NSPoint(x: cx + s * 0.55, y: cy - s * 0.55))
heart.close()

let shadow = NSShadow()
shadow.shadowColor = NSColor(red: 0.6, green: 0.1, blue: 0.3, alpha: 0.35)
shadow.shadowBlurRadius = 60
shadow.shadowOffset = NSSize(width: 0, height: -30)
shadow.set()
NSColor.white.withAlphaComponent(0.95).setFill()
heart.fill()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
