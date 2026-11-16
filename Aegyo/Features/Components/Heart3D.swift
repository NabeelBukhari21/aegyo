import CoreMotion
import SceneKit
import SwiftUI

/// Doki: a real 3D heart. Glossy clear-coat skin with a colour shimmer at its edges,
/// a lub-dub heartbeat that races when you tap it, tilt parallax from the phone's gyro,
/// and drag-to-spin with inertia.
struct Heart3DView: UIViewRepresentable {
    var tint: UIColor = UIColor(red: 1.0, green: 0.42, blue: 0.6, alpha: 1)
    /// Increment to make the heart thump (tap).
    var thump: Int = 0
    var bpm: Double = 66
    var interactive = true
    /// Start as a stone heart that cracks open to reveal the opal (once per app launch).
    var reveal = false

    /// The stone reveal plays once per launch.
    static var didReveal = false

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = true
        view.scene = context.coordinator.makeScene(tint: tint)
        view.delegate = context.coordinator
        view.isPlaying = true
        context.coordinator.pauseInBackground(view)
        if interactive {
            let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
            pan.cancelsTouchesInView = false
            view.addGestureRecognizer(pan)
        }
        context.coordinator.bpm = bpm
        context.coordinator.revealEnabled = reveal && !Self.didReveal
        if context.coordinator.revealEnabled { Self.didReveal = true } else { context.coordinator.skipReveal() }
        context.coordinator.startMotion()
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let c = context.coordinator
        if c.lastThump != thump {
            c.lastThump = thump
            c.thumpNow()
        }
        c.bpm = bpm
        c.setTint(tint)
        if !reveal && c.revealEnabled { c.skipReveal() }
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        coordinator.motion.stopDeviceMotionUpdates()
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        let heart = SCNNode()
        let pivot = SCNNode()
        let motion = CMMotionManager()
        var material = SCNMaterial()
        var lastThump = 0
        var bpm: Double = 66

        // animation state (render thread)
        private var excitement: Double = 0        // 0…1, raises heart rate after taps
        private var impulse: Double = 0           // squash from a tap
        private var impulseVel: Double = 0
        private var spinVel: Double = 0
        private var yaw: Double = 0
        private var tiltX: Double = 0, tiltY: Double = 0
        private var beatPhase: Double = 0
        private var lastTime: TimeInterval = 0
        private var currentTint: UIColor?

        // stone reveal
        var revealEnabled = false
        let shell = SCNNode()
        let shellMaterial = SCNMaterial()
        private var revealStart: TimeInterval?
        private var burstDone = false
        private var flare: Double = 0
        private var ticks = 0

        func makeScene(tint: UIColor) -> SCNScene {
            let scene = SCNScene()
            scene.background.contents = UIColor.clear
            scene.lightingEnvironment.contents = Self.studioEnvironment()
            scene.lightingEnvironment.intensity = 1.5

            let geo = Self.baseGeometry.copy() as! SCNGeometry
            material.lightingModel = .physicallyBased
            material.diffuse.contents = tint
            material.roughness.contents = 0.3
            material.metalness.contents = 0.05
            material.clearCoat.contents = 1.0
            material.clearCoatRoughness.contents = 0.04
            material.isDoubleSided = true
            material.shaderModifiers = [.surface: Self.opalShader]
            material.setValue(NSNumber(value: 0), forKey: "flare")
            geo.materials = [material]
            currentTint = tint

            heart.geometry = geo

            // the stone shell around the opal
            let shellGeo = geo.copy() as! SCNGeometry
            shellMaterial.lightingModel = .lambert
            shellMaterial.diffuse.contents = UIColor(white: 0.3, alpha: 1)
            shellMaterial.specular.contents = UIColor(white: 0.08, alpha: 1)
            shellMaterial.isDoubleSided = true
            shellMaterial.shaderModifiers = [.surface: Self.rockShader]
            shellMaterial.setValue(NSNumber(value: 0), forKey: "reveal")
            shellMaterial.setValue(NSNumber(value: 0), forKey: "crack")
            shellGeo.materials = [shellMaterial]
            shell.geometry = shellGeo
            shell.scale = SCNVector3(1.07, 1.07, 1.2)
            shell.isHidden = true
            heart.addChildNode(shell)
            heart.eulerAngles.x = -0.12
            pivot.addChildNode(heart)
            scene.rootNode.addChildNode(pivot)

            let cam = SCNCamera()
            cam.fieldOfView = 28
            cam.wantsHDR = true
            cam.bloomIntensity = 0.3
            cam.bloomThreshold = 0.92
            cam.bloomBlurRadius = 18
            cam.wantsExposureAdaptation = false
            cam.exposureOffset = -0.2
            cam.vignettingIntensity = 0
            let camNode = SCNNode()
            camNode.camera = cam
            camNode.position = SCNVector3(0, 0, 4.4)
            scene.rootNode.addChildNode(camNode)

            func light(_ type: SCNLight.LightType, _ color: UIColor, _ intensity: CGFloat, _ pos: SCNVector3) {
                let l = SCNLight(); l.type = type; l.color = color; l.intensity = intensity
                let n = SCNNode(); n.light = l; n.position = pos
                n.look(at: SCNVector3Zero)
                scene.rootNode.addChildNode(n)
            }
            light(.directional, UIColor(white: 1, alpha: 1), 650, SCNVector3(-2, 3, 4))
            light(.omni, UIColor(red: 0.75, green: 0.5, blue: 1, alpha: 1), 450, SCNVector3(3, -1, -2))   // violet rim
            light(.omni, UIColor(red: 0.4, green: 1, blue: 0.9, alpha: 1), 500, SCNVector3(-3, -2, -1))   // mint rim
            light(.ambient, UIColor(white: 0.25, alpha: 1), 300, SCNVector3Zero)
            return scene
        }

        func setTint(_ tint: UIColor) {
            guard tint != currentTint else { return }
            currentTint = tint
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.8
            material.diffuse.contents = tint
            SCNTransaction.commit()
        }

        func thumpNow() {
            impulseVel += 9
            excitement = min(1, excitement + 0.35)
            spinVel += 2.4
        }

        func skipReveal() {
            revealEnabled = false
            shell.isHidden = true
            burstDone = true
            heart.removeAllParticleSystems()
        }

        private func burst() {
            burstDone = true
            flare = 1
            impulseVel += 12
            spinVel += 3
            let shards = SCNParticleSystem()
            shards.loops = false
            shards.birthRate = 520
            shards.emissionDuration = 0.08
            shards.emitterShape = shell.geometry
            shards.birthLocation = .surface
            shards.birthDirection = .surfaceNormal
            shards.particleLifeSpan = 1.3
            shards.particleLifeSpanVariation = 0.4
            shards.particleVelocity = 1.7
            shards.particleVelocityVariation = 1.0
            shards.spreadingAngle = 40
            shards.particleSize = 0.028
            shards.particleSizeVariation = 0.018
            shards.particleImage = Self.shardImage
            shards.particleColor = UIColor(white: 0.32, alpha: 1)
            shards.particleColorVariation = SCNVector4(0, 0, 0.25, 0)
            shards.acceleration = SCNVector3(0, -4.5, 0)
            shards.particleAngularVelocity = 500
            shards.particleAngularVelocityVariation = 400
            shards.isLightingEnabled = false
            shards.blendMode = .alpha
            shards.dampingFactor = 0.6

            let sparks = SCNParticleSystem()
            sparks.loops = false
            sparks.birthRate = 380
            sparks.emissionDuration = 0.12
            sparks.emitterShape = shell.geometry
            sparks.birthLocation = .surface
            sparks.birthDirection = .surfaceNormal
            sparks.particleLifeSpan = 0.9
            sparks.particleVelocity = 3.4
            sparks.particleVelocityVariation = 2
            sparks.particleSize = 0.03
            sparks.particleImage = Self.sparkImage
            sparks.particleColor = UIColor(red: 0.6, green: 1, blue: 0.95, alpha: 1)
            sparks.particleColorVariation = SCNVector4(1, 0.3, 0, 0)
            sparks.blendMode = .additive
            sparks.isLightingEnabled = false
            sparks.dampingFactor = 1.4
            let fade = SCNParticlePropertyController(animation: {
                let a = CAKeyframeAnimation(); a.values = [1, 1, 0]; a.keyTimes = [0, 0.6, 1]; return a
            }())
            sparks.propertyControllers = [.opacity: fade]

            heart.addParticleSystem(shards)
            heart.addParticleSystem(sparks)
            DispatchQueue.main.async {
                Haptics.gemPress()
                Haptics.rumble(duration: 0.35)
            }
        }

        func startMotion() {
            guard motion.isDeviceMotionAvailable else { return }
            motion.deviceMotionUpdateInterval = 1 / 60
            motion.startDeviceMotionUpdates()
        }

        @objc func pan(_ g: UIPanGestureRecognizer) {
            let v = g.velocity(in: g.view)
            switch g.state {
            case .changed: spinVel = Double(v.x) / 90
            case .ended: spinVel = Double(v.x) / 120
            default: break
            }
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            let dt = lastTime == 0 ? 1 / 60 : min(1 / 20, time - lastTime)
            lastTime = time

            // heartbeat: rate rises with excitement, then calms down
            excitement = max(0, excitement - dt * 0.12)
            let rate = (bpm + 50 * excitement) / 60
            beatPhase = (beatPhase + dt * rate).truncatingRemainder(dividingBy: 1)
            func bump(_ c: Double, _ w: Double, _ a: Double) -> Double { a * exp(-pow((beatPhase - c) / w, 2)) }
            let beat = bump(0.10, 0.045, 0.085) + bump(0.30, 0.05, 0.05)

            // tap squash: damped spring
            impulseVel += (-impulse * 160 - impulseVel * 12) * dt
            impulse += impulseVel * dt

            let sx = 1 + beat * 1.0 + impulse * 0.05
            let sy = 1 + beat * 0.7 - impulse * 0.06
            heart.scale = SCNVector3(sx, sy, 1 + beat * 1.1 + impulse * 0.04)

            // stone → crack → burst → opal
            var jitter: Float = 0
            if revealEnabled {
                if revealStart == nil { revealStart = time + 1.3; shell.isHidden = false }
                let rt = time - (revealStart ?? time)
                let crack = max(0, min(1, rt / 1.05))
                if rt < 0 { shellMaterial.setValue(NSNumber(value: 0), forKey: "reveal") }
                shellMaterial.setValue(NSNumber(value: crack), forKey: "crack")
                let tickAt = [0.1, 0.38, 0.62, 0.84, 1.0]
                if ticks < tickAt.count, rt >= tickAt[ticks] {
                    ticks += 1
                    DispatchQueue.main.async { Haptics.press() }
                }
                if rt > 0, !burstDone { jitter = Float(sin(time * 70) * 0.012 * crack) }
                if rt >= 1.15, !burstDone { burst() }
                let r = max(0, min(1, (rt - 1.15) / 0.38))
                shellMaterial.setValue(NSNumber(value: pow(r, 0.7)), forKey: "reveal")
                if rt > 1.7 { shell.isHidden = true; revealEnabled = false }
            }
            flare = max(0, flare - dt * 0.8)
            material.setValue(NSNumber(value: flare), forKey: "flare")

            // a slow, continuous turn (like a gem on display), plus drag inertia
            spinVel *= pow(0.12, dt)
            yaw += (0.32 + spinVel) * dt
            let sway = 0.0

            // gyro parallax
            if let att = motion.deviceMotion?.attitude {
                tiltX += (att.pitch * 0.35 - 0.25 - tiltX) * min(1, dt * 4)
                tiltY += (att.roll * 0.35 - tiltY) * min(1, dt * 4)
            }
            pivot.eulerAngles = SCNVector3(Float(-0.05 + tiltX * 0.5), Float(yaw + sway + tiltY * 0.6), 0)
            pivot.position = SCNVector3(jitter, Float(sin(time * 1.1) * 0.05), 0)
        }

        /// Opal: a milky body whose "fire" patches flash and shift colour as it turns,
        /// a rainbow rim, twinkling glints and a sharp highlight. `flare` brightens it after the reveal.
        static let opalShader = """
        #pragma arguments
        float flare;
        #pragma body
        #define OH(p) fract(sin(dot((p), float3(127.1, 311.7, 74.7))) * 43758.5453)
        float3 n = normalize(_surface.normal);
        float3 v = normalize(_surface.view);
        float3 op = (scn_node.inverseModelViewTransform * float4(_surface.position, 1.0)).xyz;
        float3 q = op * 5.0;
        float3 ip = floor(q);
        float3 fp = fract(q);
        float d1 = 8.0;
        float cellId = 0.0;
        for (int z = -1; z <= 1; z++) { for (int y = -1; y <= 1; y++) { for (int x = -1; x <= 1; x++) {
            float3 g = float3(float(x), float(y), float(z));
            float3 c = ip + g;
            float3 r = g + float3(OH(c), OH(c + 11.1), OH(c + 27.3)) - fp;
            float d = dot(r, r);
            if (d < d1) { d1 = d; cellId = OH(c + 5.7); }
        } } }
        float ndv = saturate(dot(n, v));
        float shift = cellId + (1.0 - ndv) * 1.3 + dot(n, float3(0.4, 0.7, 0.2)) * 0.8 + scn_frame.time * 0.04;
        float3 fire = 0.5 + 0.5 * cos(6.28318 * (shift + float3(0.0, 0.33, 0.67)));
        float flash = smoothstep(0.35, 0.95, 0.5 + 0.5 * sin(cellId * 37.0 + ndv * 7.0 + dot(n, float3(1.0, 0.5, 0.2)) * 4.0));
        float cell = smoothstep(0.85, 0.1, sqrt(d1));
        float3 base = _surface.diffuse.rgb;
        _surface.diffuse.rgb = mix(base, fire, 0.5 * flash * (0.35 + 0.65 * cell));
        _surface.emission.rgb += fire * flash * cell * 0.34 + base * 0.04;
        float f = pow(1.0 - ndv, 2.6);
        _surface.emission.rgb += (0.5 + 0.5 * cos(6.28318 * (f * 1.4 + scn_frame.time * 0.05 + float3(0.0, 0.33, 0.67)))) * f * 0.4;
        float3 gq = floor(op * 70.0);
        float gl = step(0.986, OH(gq)) * pow(0.5 + 0.5 * sin(scn_frame.time * 3.0 + OH(gq + 3.0) * 30.0), 10.0);
        _surface.emission.rgb += float3(gl * 1.8);
        float3 rr = reflect(-v, n);
        float spec = pow(saturate(dot(rr, normalize(float3(-0.45, 0.65, 0.62)))), 70.0);
        _surface.emission.rgb += float3(spec * 1.3);
        _surface.emission.rgb *= (1.0 + flare * 1.5);
        """

        /// Stone shell: chunky faceted rock. `crack` lights the seams between chunks with opal fire;
        /// `reveal` makes chunks vanish one by one (the burst particles carry them away).
        static let rockShader = """
        #pragma arguments
        float reveal;
        float crack;
        #pragma body
        #define RH(p) fract(sin(dot((p), float3(127.1, 311.7, 74.7))) * 43758.5453)
        float3 op = (scn_node.inverseModelViewTransform * float4(_surface.position, 1.0)).xyz;
        float3 q = op * 3.4;
        float3 ip = floor(q);
        float3 fp = fract(q);
        float d1 = 8.0;
        float d2 = 8.0;
        float3 cid = float3(0.0);
        for (int z = -1; z <= 1; z++) { for (int y = -1; y <= 1; y++) { for (int x = -1; x <= 1; x++) {
            float3 g = float3(float(x), float(y), float(z));
            float3 c = ip + g;
            float3 r = g + float3(RH(c), RH(c + 11.1), RH(c + 27.3)) - fp;
            float d = dot(r, r);
            if (d < d1) { d2 = d1; d1 = d; cid = c; } else if (d < d2) { d2 = d; }
        } } }
        float chunk = RH(cid + 5.7);
        if (chunk < reveal) { discard_fragment(); }
        float edge = sqrt(d2) - sqrt(d1);
        float3 tilt = float3(RH(cid + 1.3), RH(cid + 2.9), RH(cid + 4.1)) - 0.5;
        _surface.normal = normalize(_surface.normal + tilt * 0.9);
        float grain = RH(floor(op * 90.0));
        float shade = 0.5 + 0.35 * RH(cid + 8.8) + 0.12 * grain;
        _surface.diffuse.rgb = float3(0.20, 0.195, 0.21) * shade;
        float seam = smoothstep(0.05, 0.0, edge) * crack;
        float3 fire = 0.5 + 0.5 * cos(6.28318 * (chunk * 2.0 + scn_frame.time * 0.3 + float3(0.0, 0.33, 0.67)));
        _surface.emission.rgb = mix(float3(0.6, 1.0, 0.95), fire, 0.45) * seam * 2.2 + float3(0.6, 1.0, 0.95) * crack * crack * 0.06;
        """

        static let shardImage: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { ctx in
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 6, y: 4)); p.addLine(to: CGPoint(x: 28, y: 10)); p.addLine(to: CGPoint(x: 22, y: 28)); p.addLine(to: CGPoint(x: 3, y: 20)); p.close()
            UIColor.white.setFill(); p.fill()
        }

        static let sparkImage: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { ctx in
            let g = CGGradient(colorsSpace: nil, colors: [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
            ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 16, y: 16), startRadius: 0, endCenter: CGPoint(x: 16, y: 16), endRadius: 16, options: [])
        }

        /// Built once per launch and shared by every heart on screen.
        static let baseGeometry: SCNGeometry = heartGeometry()

        private var observers: [NSObjectProtocol] = []

        /// Stop drawing entirely while the app is in the background.
        func pauseInBackground(_ view: SCNView) {
            let nc = NotificationCenter.default
            observers.append(nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak view] _ in
                view?.isPlaying = false; view?.rendersContinuously = false
            })
            observers.append(nc.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak view] _ in
                view?.isPlaying = true; view?.rendersContinuously = true
            })
        }

        deinit { observers.forEach(NotificationCenter.default.removeObserver) }

        /// A real 3D heart: the classic implicit heart surface
        /// (x² + 9/4·y² + z² − 1)³ − x²z³ − 9/80·y²z³ = 0, ray-cast from the centre onto a sphere grid so the
        /// mesh has no seams, with normals from the analytic gradient so the shading is perfectly smooth.
        /// Full, rounded lobes, a deep cleft and a soft tip, puffed a little in depth so it reads as a plush gem.
        static func heartGeometry() -> SCNGeometry {
            let lat = 120, lon = 200
            let plump: Float = 0.92          // depth multiplier (1 = the mathematical heart)
            let squash: Float = 0.9          // vertical multiplier: a little wider than tall reads cuter
            let targetWidth: Float = 1.92    // object-space width, matches the old mesh so the camera framing holds

            // f < 0 inside. Implicit space: x right, y depth, z up.
            func f(_ p: SIMD3<Float>) -> Float {
                let a = p.x * p.x + 2.25 * p.y * p.y + p.z * p.z - 1
                return a * a * a - p.x * p.x * p.z * p.z * p.z - 0.1125 * p.y * p.y * p.z * p.z * p.z
            }
            func grad(_ p: SIMD3<Float>) -> SIMD3<Float> {
                let a = p.x * p.x + 2.25 * p.y * p.y + p.z * p.z - 1
                let a2 = 3 * a * a
                let z2 = p.z * p.z, z3 = z2 * p.z
                return SIMD3(a2 * 2 * p.x - 2 * p.x * z3,
                             a2 * 4.5 * p.y - 0.225 * p.y * z3,
                             a2 * 2 * p.z - 3 * p.x * p.x * z2 - 0.3375 * p.y * p.y * z2)
            }
            // The heart is star-shaped around a point a little below centre: every ray from there crosses once.
            let origin = SIMD3<Float>(0, 0, -0.08)
            func hit(_ d: SIMD3<Float>) -> Float {
                var r: Float = 0.05
                while r < 2.5, f(origin + d * r) < 0 { r += 0.04 }
                var lo = r - 0.04, hi = r
                for _ in 0..<22 {
                    let mid = (lo + hi) / 2
                    if f(origin + d * mid) < 0 { lo = mid } else { hi = mid }
                }
                return (lo + hi) / 2
            }

            // Sphere grid: pole at the cleft (top) and at the tip (bottom), so rings follow the lobes.
            var imp: [SIMD3<Float>] = []
            var nrm: [SIMD3<Float>] = []
            imp.reserveCapacity((lat + 1) * lon); nrm.reserveCapacity((lat + 1) * lon)
            for i in 0...lat {
                let phi = Float(i) / Float(lat) * .pi
                for j in 0..<lon {
                    let th = Float(j) / Float(lon) * 2 * .pi
                    let d = SIMD3(sin(phi) * cos(th), sin(phi) * sin(th) / plump, cos(phi))
                    let dn = simd_normalize(d)
                    let p = origin + dn * hit(dn)
                    imp.append(p)
                    nrm.append(grad(p))
                }
            }

            // Implicit → object space: SceneKit y is up, z is depth. Centre and scale.
            var minX: Float = .infinity, maxX: Float = -.infinity, minY: Float = .infinity, maxY: Float = -.infinity
            for p in imp { minX = min(minX, p.x); maxX = max(maxX, p.x); minY = min(minY, p.z); maxY = max(maxY, p.z) }
            let s = targetWidth / (maxX - minX)
            let cy = (minY + maxY) / 2
            let verts: [SIMD3<Float>] = imp.map { SIMD3($0.x * s, ($0.z - cy) * s * squash, $0.y * s * plump) }
            // normals transform by the inverse transpose of the (diagonal) scale
            let normals: [SIMD3<Float>] = nrm.map { simd_normalize(SIMD3($0.x / s, $0.z / (s * squash), $0.y / (s * plump))) }

            func idx(_ i: Int, _ j: Int) -> Int32 { Int32(i * lon + (j % lon)) }
            var indices: [Int32] = []
            indices.reserveCapacity(lat * lon * 6)
            for i in 0..<lat {
                for j in 0..<lon {
                    // outward winding (counter-clockwise seen from outside)
                    if i > 0 { indices += [idx(i, j), idx(i, j + 1), idx(i + 1, j)] }
                    if i < lat - 1 { indices += [idx(i + 1, j), idx(i, j + 1), idx(i + 1, j + 1)] }
                }
            }

            let vSrc = SCNGeometrySource(vertices: verts.map { SCNVector3($0.x, $0.y, $0.z) })
            let nSrc = SCNGeometrySource(normals: normals.map { SCNVector3($0.x, $0.y, $0.z) })
            let el = SCNGeometryElement(indices: indices, primitiveType: .triangles)
            return SCNGeometry(sources: [vSrc, nSrc], elements: [el])
        }

        /// A soft studio: dark room, a big bright softbox up-left and a warm strip below.
        static func studioEnvironment() -> UIImage {
            let size = CGSize(width: 512, height: 256)
            return UIGraphicsImageRenderer(size: size).image { ctx in
                let c = ctx.cgContext
                UIColor(white: 0.04, alpha: 1).setFill()
                c.fill(CGRect(origin: .zero, size: size))
                func blob(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: UIColor) {
                    let g = CGGradient(colorsSpace: nil, colors: [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
                    c.drawRadialGradient(g, startCenter: CGPoint(x: x, y: y), startRadius: 0, endCenter: CGPoint(x: x, y: y), endRadius: r, options: [])
                }
                blob(180, 70, 90, UIColor(white: 1, alpha: 1))
                blob(330, 90, 60, UIColor(red: 0.7, green: 0.55, blue: 1, alpha: 0.8))
                blob(256, 210, 120, UIColor(red: 1, green: 0.55, blue: 0.5, alpha: 0.3))
                blob(60, 140, 50, UIColor(red: 0.5, green: 1, blue: 0.9, alpha: 0.5))
            }
        }
    }
}

/// The heart's name. Change it here and it updates everywhere.
enum Doki {
    /// Set in Settings → Doki's name.
    static var name: String { Prefs.dokiName }
}

extension GemTier {
    /// Base colour of the 3D heart for each tier.
    var heartTint: UIColor {
        switch self {
        case .opal: UIColor(red: 1.0, green: 0.42, blue: 0.6, alpha: 1)
        case .roseOpal: UIColor(red: 1, green: 0.7, blue: 0.78, alpha: 1)
        case .moonstone: UIColor(red: 0.8, green: 0.85, blue: 1, alpha: 1)
        case .aurora: UIColor(red: 0.5, green: 0.95, blue: 0.85, alpha: 1)
        case .diamond: UIColor(red: 0.92, green: 0.95, blue: 1, alpha: 1)
        }
    }
}
