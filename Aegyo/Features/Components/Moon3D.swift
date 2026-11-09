import SceneKit
import SwiftUI

/// A real 3D moon: cratered surface, lit by the Sun exactly as tonight's phase, slowly turning.
/// Drag to spin it; tap callback for sending a "moon kiss".
struct Moon3DView: UIViewRepresentable {
    var phase: Double = Astro.moonPhase()
    var spinBoost: Int = 0

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.backgroundColor = .clear
        v.isOpaque = false
        v.antialiasingMode = .multisampling4X
        v.preferredFramesPerSecond = 60
        v.rendersContinuously = true
        v.scene = context.coordinator.scene(phase: phase)
        v.delegate = context.coordinator
        v.isPlaying = true
        let nc = NotificationCenter.default
        context.coordinator.observers = [
            nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak v] _ in v?.isPlaying = false; v?.rendersContinuously = false },
            nc.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak v] _ in v?.isPlaying = true; v?.rendersContinuously = true },
        ]
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.cancelsTouchesInView = false
        v.addGestureRecognizer(pan)
        return v
    }

    func updateUIView(_ v: SCNView, context: Context) {
        if context.coordinator.lastBoost != spinBoost {
            context.coordinator.lastBoost = spinBoost
            context.coordinator.spin += 3
        }
        context.coordinator.setPhase(phase)
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        let moon = SCNNode()
        let sun = SCNNode()
        var spin: Double = 0
        var lastBoost = 0
        var observers: [NSObjectProtocol] = []
        deinit { observers.forEach(NotificationCenter.default.removeObserver) }
        private var yaw: Double = 0
        private var last: TimeInterval = 0
        private var currentPhase = -1.0

        static let texture: UIImage = makeTexture()

        func scene(phase: Double) -> SCNScene {
            let s = SCNScene()
            s.background.contents = UIColor.clear
            let sphere = SCNSphere(radius: 1)
            sphere.segmentCount = 160
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = Self.texture
            m.roughness.contents = 0.95
            m.metalness.contents = 0.0
            sphere.materials = [m]
            moon.geometry = sphere
            moon.eulerAngles.z = 0.12
            s.rootNode.addChildNode(moon)

            let l = SCNLight()
            l.type = .directional
            l.intensity = 2600
            l.color = UIColor(red: 1, green: 0.97, blue: 0.92, alpha: 1)
            sun.light = l
            s.rootNode.addChildNode(sun)

            let earthshine = SCNLight()
            earthshine.type = .ambient
            earthshine.intensity = 70
            earthshine.color = UIColor(red: 0.55, green: 0.62, blue: 0.9, alpha: 1)
            let en = SCNNode(); en.light = earthshine
            s.rootNode.addChildNode(en)

            let cam = SCNCamera()
            cam.fieldOfView = 30
            cam.wantsHDR = true
            cam.bloomIntensity = 0.25
            cam.bloomThreshold = 0.9
            cam.bloomBlurRadius = 20
            let cn = SCNNode(); cn.camera = cam; cn.position = SCNVector3(0, 0, 4.2)
            s.rootNode.addChildNode(cn)
            setPhase(phase)
            return s
        }

        /// Places the Sun so the lit portion matches the real phase (waxing = lit on the right).
        func setPhase(_ p: Double) {
            guard abs(p - currentPhase) > 0.0005 else { return }
            currentPhase = p
            let a = 2 * .pi * p
            sun.position = SCNVector3(Float(sin(a) * 10), 0.6, Float(-cos(a) * 10))
            sun.look(at: SCNVector3Zero)
        }

        @objc func pan(_ g: UIPanGestureRecognizer) {
            let v = g.velocity(in: g.view)
            if g.state == .changed || g.state == .ended { spin = Double(v.x) / 160 }
        }

        func renderer(_ r: SCNSceneRenderer, updateAtTime t: TimeInterval) {
            let dt = last == 0 ? 1 / 60 : min(1 / 20, t - last)
            last = t
            spin *= pow(0.25, dt)
            yaw += (0.06 + spin) * dt
            moon.eulerAngles.y = Float(yaw)
            moon.position.y = Float(sin(t * 0.6) * 0.04)
        }

        /// Procedural lunar surface: grey regolith, dark maria, thousands of craters.
        static func makeTexture() -> UIImage {
            let W = 1024, H = 512
            var seed: UInt64 = 0x5EED_1234
            func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 11) / Double(1 << 53) }
            return UIGraphicsImageRenderer(size: CGSize(width: W, height: H)).image { ctx in
                let c = ctx.cgContext
                UIColor(white: 0.66, alpha: 1).setFill()
                c.fill(CGRect(x: 0, y: 0, width: W, height: H))
                func soft(_ x: Double, _ y: Double, _ r: Double, _ color: UIColor) {
                    let g = CGGradient(colorsSpace: nil, colors: [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
                    for dx in [-Double(W), 0, Double(W)] {
                        c.drawRadialGradient(g, startCenter: CGPoint(x: x + dx, y: y), startRadius: 0, endCenter: CGPoint(x: x + dx, y: y), endRadius: r, options: [])
                    }
                }
                // maria (dark seas)
                for _ in 0..<26 { soft(rnd() * Double(W), 120 + rnd() * 260, 40 + rnd() * 110, UIColor(white: 0.28, alpha: 0.45)) }
                // highlands
                for _ in 0..<30 { soft(rnd() * Double(W), rnd() * Double(H), 30 + rnd() * 90, UIColor(white: 0.85, alpha: 0.18)) }
                // grain
                for _ in 0..<14000 {
                    let v = rnd()
                    UIColor(white: v > 0.5 ? 0.85 : 0.35, alpha: 0.08).setFill()
                    c.fill(CGRect(x: rnd() * Double(W), y: rnd() * Double(H), width: 2, height: 2))
                }
                // craters: dark floor, bright rim on one side, shadow on the other
                for i in 0..<520 {
                    let r = i < 18 ? 10 + rnd() * 22 : 1.5 + pow(rnd(), 3) * 12
                    let x = rnd() * Double(W), y = 20 + rnd() * Double(H - 40)
                    soft(x, y, r * 1.0, UIColor(white: 0.32, alpha: 0.35))
                    c.setStrokeColor(UIColor(white: 0.92, alpha: 0.35).cgColor)
                    c.setLineWidth(max(0.8, r * 0.18))
                    c.addArc(center: CGPoint(x: x, y: y), radius: r, startAngle: .pi * 0.9, endAngle: .pi * 1.9, clockwise: false)
                    c.strokePath()
                    c.setStrokeColor(UIColor(white: 0.18, alpha: 0.3).cgColor)
                    c.addArc(center: CGPoint(x: x, y: y), radius: r * 0.9, startAngle: .pi * 1.9, endAngle: .pi * 0.9, clockwise: false)
                    c.strokePath()
                }
                // a bright ray crater (like Tycho)
                let tx = Double(W) * 0.55, ty = Double(H) * 0.72
                c.setStrokeColor(UIColor(white: 1, alpha: 0.12).cgColor)
                c.setLineWidth(2)
                for k in 0..<22 {
                    let a = Double(k) / 22 * 2 * .pi
                    c.move(to: CGPoint(x: tx, y: ty))
                    c.addLine(to: CGPoint(x: tx + cos(a) * (60 + rnd() * 120), y: ty + sin(a) * (40 + rnd() * 80)))
                }
                c.strokePath()
                soft(tx, ty, 14, UIColor(white: 1, alpha: 0.6))
            }
        }
    }
}

/// Twinkling star field (Canvas), with optional slow parallax drift.
struct StarField: View {
    var density = 90
    var drift = true
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { g, size in
                var seed: UInt64 = 42
                func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1; return Double(seed >> 40) / Double(1 << 24) }
                for _ in 0..<density {
                    let x = (rnd() * size.width + (drift ? t * 2 * rnd() : 0)).truncatingRemainder(dividingBy: size.width)
                    let y = rnd() * size.height
                    let r = 0.4 + rnd() * 1.2
                    let tw = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * (0.8 + rnd() * 2) + rnd() * 6))
                    g.opacity = tw
                    g.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(.white))
                }
                // an occasional shooting star
                let cycle = t.truncatingRemainder(dividingBy: 9)
                if cycle < 0.9 {
                    let p = cycle / 0.9
                    let sx = size.width * (0.2 + 0.6 * p), sy = size.height * (0.1 + 0.25 * p)
                    var path = Path()
                    path.move(to: CGPoint(x: sx, y: sy))
                    path.addLine(to: CGPoint(x: sx - 60, y: sy - 25))
                    g.opacity = sin(.pi * p)
                    g.stroke(path, with: .linearGradient(Gradient(colors: [.white, .clear]), startPoint: CGPoint(x: sx, y: sy), endPoint: CGPoint(x: sx - 60, y: sy - 25)), lineWidth: 1.4)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
