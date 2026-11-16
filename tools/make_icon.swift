// Renders the 1024×1024 app icons: a big frosted-glass heart over soft opal colour blobs.
// Three variants for iOS 18 appearances: light, dark and tinted (grayscale, the system colours it).
// Usage: swift tools/make_icon.swift Aegyo/Assets.xcassets/AppIcon.appiconset
import AppKit

let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let size = 1024
let S = CGFloat(size)

enum Mode { case light, dark, tinted }

func heartPath(cx: CGFloat, cy: CGFloat, s: CGFloat) -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: cx, y: cy - s * 0.95))
    p.curve(to: NSPoint(x: cx - s, y: cy + s * 0.35),
            controlPoint1: NSPoint(x: cx - s * 0.55, y: cy - s * 0.55),
            controlPoint2: NSPoint(x: cx - s, y: cy - s * 0.15))
    p.curve(to: NSPoint(x: cx, y: cy + s * 0.6),
            controlPoint1: NSPoint(x: cx - s, y: cy + s * 0.95),
            controlPoint2: NSPoint(x: cx - s * 0.2, y: cy + s * 1.0))
    p.curve(to: NSPoint(x: cx + s, y: cy + s * 0.35),
            controlPoint1: NSPoint(x: cx + s * 0.2, y: cy + s * 1.0),
            controlPoint2: NSPoint(x: cx + s, y: cy + s * 0.95))
    p.curve(to: NSPoint(x: cx, y: cy - s * 0.95),
            controlPoint1: NSPoint(x: cx + s, y: cy - s * 0.15),
            controlPoint2: NSPoint(x: cx + s * 0.55, y: cy - s * 0.55))
    p.close()
    return p
}

/// Soft glowing blob (radial gradient fading to clear).
func blob(_ c: CGContext, x: CGFloat, y: CGFloat, r: CGFloat, color: NSColor, alpha: CGFloat) {
    let cs = CGColorSpaceCreateDeviceRGB()
    let g = CGGradient(colorsSpace: cs, colors: [color.withAlphaComponent(alpha).cgColor, color.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
    c.drawRadialGradient(g, startCenter: CGPoint(x: x, y: y), startRadius: 0, endCenter: CGPoint(x: x, y: y), endRadius: r, options: [])
}

func render(_ mode: Mode, to path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gc
    let c = gc.cgContext
    let rect = NSRect(x: 0, y: 0, width: S, height: S)

    // Palette
    let pink = NSColor(red: 1.00, green: 0.42, blue: 0.62, alpha: 1)
    let rose = NSColor(red: 0.96, green: 0.20, blue: 0.45, alpha: 1)
    let violet = NSColor(red: 0.62, green: 0.45, blue: 1.00, alpha: 1)
    let mint = NSColor(red: 0.55, green: 0.98, blue: 0.86, alpha: 1)
    let peach = NSColor(red: 1.00, green: 0.72, blue: 0.60, alpha: 1)

    // 1. Background
    switch mode {
    case .light:
        NSGradient(colors: [NSColor(red: 1.0, green: 0.93, blue: 0.90, alpha: 1),
                            NSColor(red: 1.0, green: 0.80, blue: 0.87, alpha: 1),
                            NSColor(red: 0.88, green: 0.84, blue: 1.0, alpha: 1)])!.draw(in: rect, angle: -60)
    case .dark, .tinted:
        NSGradient(colors: [NSColor(red: 0.09, green: 0.07, blue: 0.13, alpha: 1),
                            NSColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1)])!.draw(in: rect, angle: -90)
    }

    // 2. Colour blobs behind the glass (opal fire)
    let bg: [(CGFloat, CGFloat, CGFloat, NSColor, CGFloat)] = mode == .light
        ? [(250, 760, 420, peach, 0.55), (800, 720, 380, violet, 0.4), (520, 260, 460, rose, 0.4), (180, 300, 340, mint, 0.35), (860, 260, 300, pink, 0.45)]
        : [(250, 760, 420, violet, 0.75), (800, 720, 380, rose, 0.8), (520, 280, 460, pink, 0.65), (180, 280, 340, mint, 0.45), (870, 270, 300, peach, 0.45)]
    for b in bg { blob(c, x: b.0, y: b.1, r: b.2, color: b.3, alpha: b.4) }

    // 3. The heart (big: spans ~80% of the icon)
    let s: CGFloat = 400
    let heart = heartPath(cx: 512, cy: 470, s: s)

    // drop shadow / glow beneath the glass
    c.saveGState()
    let sh = NSShadow()
    sh.shadowColor = mode == .light ? NSColor(red: 0.55, green: 0.08, blue: 0.32, alpha: 0.45) : pink.withAlphaComponent(0.55)
    sh.shadowBlurRadius = 70
    sh.shadowOffset = NSSize(width: 0, height: -34)
    sh.set()
    (mode == .light ? NSColor.white.withAlphaComponent(0.10) : NSColor.black.withAlphaComponent(0.28)).setFill()
    heart.fill()
    c.restoreGState()

    // tinted glass body: deep violet to rose, so the colour lives inside the heart
    c.saveGState()
    heart.addClip()
    let body = mode == .light
        ? NSGradient(colors: [NSColor(red: 0.78, green: 0.62, blue: 1.0, alpha: 0.55), NSColor(red: 1.0, green: 0.45, blue: 0.65, alpha: 0.6), NSColor(red: 0.95, green: 0.22, blue: 0.48, alpha: 0.7)])!
        : NSGradient(colors: [NSColor(red: 0.40, green: 0.22, blue: 0.70, alpha: 0.85), NSColor(red: 0.72, green: 0.18, blue: 0.48, alpha: 0.85), NSColor(red: 0.85, green: 0.12, blue: 0.38, alpha: 0.9)])!
    body.draw(in: heart.bounds, angle: -70)
    c.restoreGState()

    // refraction: the blobs again, magnified and shifted, clipped to the heart
    c.saveGState()
    heart.addClip()
    c.translateBy(x: 512, y: 470); c.scaleBy(x: 1.18, y: 1.18); c.translateBy(x: -512 - 26, y: -470 + 18)
    for b in bg { blob(c, x: b.0, y: b.1, r: b.2 * 1.05, color: b.3, alpha: min(1, b.4 * 0.7)) }
    blob(c, x: 560, y: 380, r: 380, color: rose, alpha: 0.35)
    blob(c, x: 330, y: 560, r: 260, color: violet, alpha: 0.5)
    blob(c, x: 700, y: 330, r: 240, color: mint, alpha: 0.4)
    c.restoreGState()

    // frosted body: vertical white gradient, denser at the top
    c.saveGState()
    heart.addClip()
    let frost = mode == .light
        ? NSGradient(colors: [NSColor.white.withAlphaComponent(0.16), NSColor.white.withAlphaComponent(0.05), NSColor.white.withAlphaComponent(0.0)])!
        : NSGradient(colors: [NSColor.white.withAlphaComponent(0.08), NSColor.white.withAlphaComponent(0.02), NSColor.white.withAlphaComponent(0.0)])!
    frost.draw(in: heart.bounds, angle: -90)
    // inner glow along the bottom edge (light bouncing inside the glass)
    let cs = CGColorSpaceCreateDeviceRGB()
    let ig = CGGradient(colorsSpace: cs, colors: [pink.withAlphaComponent(0).cgColor, pink.withAlphaComponent(mode == .light ? 0.35 : 0.5).cgColor] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(ig, start: CGPoint(x: 512, y: 470), end: CGPoint(x: 512, y: 470 - s * 0.95), options: [])
    // inner rim: a slightly smaller stroke in white, blurred by drawing it a few times
    for (i, a) in [(26.0, 0.03), (16.0, 0.05), (8.0, 0.08)] {
        let inner = heartPath(cx: 512, cy: 470, s: s - CGFloat(i) * 0.9)
        inner.lineWidth = CGFloat(i)
        NSColor.white.withAlphaComponent(CGFloat(a)).setStroke()
        inner.stroke()
    }
    c.restoreGState()

    // glass thickness: a soft dark band just inside the edge
    c.saveGState()
    heart.addClip()
    for (w, a) in [(70.0, 0.05), (40.0, 0.07), (18.0, 0.10)] {
        let e = heartPath(cx: 512, cy: 470, s: s)
        e.lineWidth = CGFloat(w)
        (mode == .light ? NSColor(red: 0.5, green: 0.1, blue: 0.35, alpha: CGFloat(a)) : NSColor.black.withAlphaComponent(CGFloat(a * 2.2))).setStroke()
        e.stroke()
    }
    c.restoreGState()

    // glossy reflection streak across the top of the glass
    c.saveGState()
    heart.addClip()
    let streak = NSBezierPath()
    streak.move(to: NSPoint(x: 140, y: 560))
    streak.curve(to: NSPoint(x: 880, y: 600), controlPoint1: NSPoint(x: 380, y: 470), controlPoint2: NSPoint(x: 700, y: 470))
    streak.line(to: NSPoint(x: 880, y: 1000)); streak.line(to: NSPoint(x: 140, y: 1000)); streak.close()
    streak.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(mode == .light ? 0.30 : 0.22), NSColor.white.withAlphaComponent(0.03)])!.draw(in: NSRect(x: 100, y: 470, width: 820, height: 400), angle: 90)
    c.restoreGState()

    // specular: a soft highlight on the upper-left lobe and a thin crescent on the upper-right
    c.saveGState()
    heart.addClip()
    let hl = CGGradient(colorsSpace: cs, colors: [NSColor.white.withAlphaComponent(0.6).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
    c.saveGState()
    c.translateBy(x: 345, y: 650); c.scaleBy(x: 1.0, y: 0.6)
    c.drawRadialGradient(hl, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 120, options: [])
    c.restoreGState()
    let hl2 = CGGradient(colorsSpace: cs, colors: [NSColor.white.withAlphaComponent(0.35).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
    c.saveGState()
    c.translateBy(x: 700, y: 680); c.scaleBy(x: 1.0, y: 0.5)
    c.drawRadialGradient(hl2, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 130, options: [])
    c.restoreGState()
    c.restoreGState()

    // outer rim: bright edge that catches the light, brighter at the top
    let rim = heartPath(cx: 512, cy: 470, s: s)
    c.saveGState()
    rim.lineWidth = 9
    c.setLineWidth(9)
    c.addPath(rim.cgPath)
    c.replacePathWithStrokedPath()
    c.clip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(mode == .light ? 0.95 : 0.9), NSColor.white.withAlphaComponent(0.25)])!.draw(in: heart.bounds.insetBy(dx: -10, dy: -10), angle: -90)
    c.restoreGState()

    // a few tiny glints
    for (x, y, r) in [(300.0, 690.0, 9.0), (735.0, 715.0, 6.0), (560.0, 250.0, 5.0), (430.0, 400.0, 4.0)] {
        blob(c, x: CGFloat(x), y: CGFloat(y), r: CGFloat(r) * 3, color: .white, alpha: 0.9)
    }

    NSGraphicsContext.restoreGraphicsState()

    var data = rep.representation(using: .png, properties: [:])!
    if mode == .tinted {
        // grayscale: the system applies the tint colour
        let ci = CIImage(data: data)!
        let mono = ci.applyingFilter("CIPhotoEffectMono")
        let out = NSBitmapImageRep(ciImage: mono)
        data = out.representation(using: .png, properties: [:])!
    }
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var pts = [NSPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            switch element(at: i, associatedPoints: &pts) {
            case .moveTo: path.move(to: pts[0])
            case .lineTo: path.addLine(to: pts[0])
            case .curveTo, .cubicCurveTo: path.addCurve(to: pts[2], control1: pts[0], control2: pts[1])
            case .quadraticCurveTo: path.addQuadCurve(to: pts[1], control: pts[0])
            case .closePath: path.closeSubpath()
            @unknown default: break
            }
        }
        return path
    }
}

render(.light, to: "\(dir)/icon.png")
render(.dark, to: "\(dir)/icon-dark.png")
render(.tinted, to: "\(dir)/icon-tinted.png")
