import SwiftUI

/// Little jelly characters, one per mood. They breathe, blink, wobble and react when tapped.
struct MoodCharacter: View {
    let mood: Mood
    var size: CGFloat = 72
    /// Increment to make it jump and squish.
    var react: Int = 0
    var idle = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40, paused: !idle || reduceMotion)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let m = motion(t)
            ZStack {
                // ground shadow
                Ellipse().fill(.black.opacity(0.35))
                    .frame(width: size * 0.62 * (1 - m.lift * 0.4), height: size * 0.1)
                    .blur(radius: 3)
                    .offset(y: size * 0.48)
                ZStack {
                    body(t)
                    face(t)
                    extras(t)
                }
                .scaleEffect(x: m.sx, y: m.sy, anchor: .bottom)
                .rotationEffect(.degrees(m.rot))
                .offset(x: m.dx, y: -m.lift * size * 0.35)
            }
            .frame(width: size * 1.4, height: size * 1.4)
            .drawingGroup()
            .frame(width: size, height: size)
        }
        .keyframeAnimator(initialValue: Squish(), trigger: react) { v, k in
            v.scaleEffect(x: k.sx, y: k.sy, anchor: .bottom).offset(y: k.y).rotationEffect(.degrees(k.r))
        } keyframes: { _ in
            KeyframeTrack(\.sx) { SpringKeyframe(1.28, duration: 0.1); SpringKeyframe(0.86, duration: 0.18); SpringKeyframe(1.1, duration: 0.14); SpringKeyframe(1, duration: 0.4, spring: .bouncy) }
            KeyframeTrack(\.sy) { SpringKeyframe(0.72, duration: 0.1); SpringKeyframe(1.22, duration: 0.18); SpringKeyframe(0.9, duration: 0.14); SpringKeyframe(1, duration: 0.4, spring: .bouncy) }
            KeyframeTrack(\.y) { LinearKeyframe(0, duration: 0.1); CubicKeyframe(-size * 0.45, duration: 0.2); CubicKeyframe(0, duration: 0.18); SpringKeyframe(0, duration: 0.3) }
            KeyframeTrack(\.r) { LinearKeyframe(0, duration: 0.12); CubicKeyframe(-12, duration: 0.14); CubicKeyframe(10, duration: 0.14); SpringKeyframe(0, duration: 0.4, spring: .bouncy) }
        }
        .accessibilityLabel(mood.name)
    }

    private struct Squish { var sx: CGFloat = 1; var sy: CGFloat = 1; var y: CGFloat = 0; var r: Double = 0 }

    // MARK: Personality (idle motion)

    private struct M { var sx: CGFloat = 1; var sy: CGFloat = 1; var lift: CGFloat = 0; var rot: Double = 0; var dx: CGFloat = 0 }

    private func motion(_ t: Double) -> M {
        var m = M()
        let breathe = CGFloat(sin(t * 2.2)) * 0.03
        m.sx = 1 + breathe; m.sy = 1 - breathe
        switch mood {
        case .happy:
            let b = CGFloat(max(0, sin(t * 4.2)))
            m.lift = b * 0.25; m.sy += -0.06 * (1 - b); m.sx += 0.06 * (1 - b)
        case .excited:
            let b = CGFloat(abs(sin(t * 6)))
            m.lift = b * 0.45; m.rot = sin(t * 6) * 6
        case .loving:
            m.rot = sin(t * 1.6) * 7; m.lift = CGFloat(0.08 + 0.06 * sin(t * 1.6))
        case .sleepy:
            let s = CGFloat(sin(t * 0.9)) * 0.05
            m.sx = 1 + s; m.sy = 1 - s; m.rot = sin(t * 0.45) * 8
        case .cozy:
            m.rot = sin(t * 1.1) * 4
        case .busy:
            m.dx = CGFloat(sin(t * 7)) * size * 0.05; m.rot = sin(t * 7) * 3
        case .stressed:
            m.dx = CGFloat(sin(t * 38)) * size * 0.018; m.sx += CGFloat(sin(t * 9)) * 0.02
        case .sad:
            m.sy -= 0.05; m.sx += 0.04; m.rot = sin(t * 0.7) * 3
        }
        return m
    }

    // MARK: Body

    private var colors: (light: Color, base: Color, dark: Color) {
        func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
        switch mood {
        case .happy: return (c(1, 0.95, 0.6), c(1, 0.78, 0.25), c(0.9, 0.5, 0.1))
        case .loving: return (c(1, 0.75, 0.82), c(1, 0.38, 0.55), c(0.8, 0.12, 0.35))
        case .sleepy: return (c(0.86, 0.82, 1), c(0.6, 0.55, 0.95), c(0.35, 0.3, 0.7))
        case .cozy: return (c(1, 0.86, 0.72), c(0.96, 0.62, 0.45), c(0.72, 0.38, 0.25))
        case .excited: return (c(1, 0.78, 0.6), c(1, 0.42, 0.35), c(0.85, 0.15, 0.3))
        case .busy: return (c(0.7, 1, 0.94), c(0.25, 0.8, 0.72), c(0.08, 0.5, 0.48))
        case .stressed: return (c(0.92, 1, 0.66), c(0.72, 0.9, 0.3), c(0.42, 0.62, 0.1))
        case .sad: return (c(0.72, 0.86, 1), c(0.38, 0.6, 0.95), c(0.16, 0.32, 0.7))
        }
    }

    private func body(_ t: Double) -> some View {
        let wob: CGFloat = mood == .stressed ? 0.045 : 0.025
        return ZStack {
            BlobShape(time: t, wobble: wob)
                .fill(RadialGradient(colors: [colors.light, colors.base, colors.dark], center: UnitPoint(x: 0.35, y: 0.28), startRadius: 0, endRadius: size * 0.75))
            BlobShape(time: t, wobble: wob)
                .stroke(.white.opacity(0.25), lineWidth: 1)
            // gloss
            Ellipse().fill(.white.opacity(0.7))
                .frame(width: size * 0.26, height: size * 0.13)
                .rotationEffect(.degrees(-25))
                .offset(x: -size * 0.17, y: -size * 0.24)
                .blur(radius: 1.5)
            Circle().fill(.white.opacity(0.85)).frame(width: size * 0.05).offset(x: -size * 0.02, y: -size * 0.3)
            // rim light
            BlobShape(time: t, wobble: wob)
                .stroke(LinearGradient(colors: [.clear, .white.opacity(0.35)], startPoint: .top, endPoint: .bottom), lineWidth: size * 0.04)
                .blur(radius: 2)
                .mask(BlobShape(time: t, wobble: wob))
        }
        .frame(width: size * 0.9, height: size * 0.86)
        .shadow(color: colors.base.opacity(0.45), radius: size * 0.12, y: size * 0.04)
    }

    // MARK: Face

    private func face(_ t: Double) -> some View {
        let blink = (t.truncatingRemainder(dividingBy: 3.4)) > 3.25
        let ink = Color(red: 0.13, green: 0.07, blue: 0.12)
        let eyeX = size * 0.15, eyeY = -size * 0.04
        return ZStack {
            // cheeks
            if mood != .stressed && mood != .busy {
                ForEach([-1.0, 1.0], id: \.self) { s in
                    Ellipse().fill(Color(red: 1, green: 0.4, blue: 0.5).opacity(0.45))
                        .frame(width: size * 0.12, height: size * 0.06).blur(radius: 1)
                        .offset(x: CGFloat(s) * size * 0.24, y: size * 0.07)
                }
            }
            switch mood {
            case .happy:
                ForEach([-1.0, 1.0], id: \.self) { s in
                    Arc(up: true).stroke(ink, style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
                        .frame(width: size * 0.11, height: size * 0.06).offset(x: CGFloat(s) * eyeX, y: eyeY)
                }
                Arc(up: false).fill(ink).frame(width: size * 0.2, height: size * 0.12).offset(y: size * 0.12)
                    .overlay(Ellipse().fill(Color(red: 1, green: 0.45, blue: 0.5)).frame(width: size * 0.09, height: size * 0.04).offset(y: size * 0.15))
            case .loving:
                ForEach([-1.0, 1.0], id: \.self) { s in
                    HeartShape().fill(Color(red: 0.9, green: 0.1, blue: 0.3))
                        .frame(width: size * 0.13, height: size * 0.12)
                        .scaleEffect(1 + 0.12 * CGFloat(max(0, sin(t * 5))))
                        .offset(x: CGFloat(s) * eyeX, y: eyeY)
                }
                Arc(up: false).stroke(ink, style: StrokeStyle(lineWidth: size * 0.03, lineCap: .round)).frame(width: size * 0.12, height: size * 0.05).offset(y: size * 0.12)
            case .sleepy, .cozy:
                ForEach([-1.0, 1.0], id: \.self) { s in
                    Arc(up: mood == .cozy).stroke(ink, style: StrokeStyle(lineWidth: size * 0.03, lineCap: .round))
                        .frame(width: size * 0.11, height: size * 0.045).offset(x: CGFloat(s) * eyeX, y: eyeY + size * 0.01)
                }
                if mood == .sleepy {
                    Ellipse().fill(ink).frame(width: size * 0.06, height: size * (0.05 + 0.02 * CGFloat(sin(t * 0.9)))).offset(y: size * 0.13)
                } else {
                    Arc(up: false).stroke(ink, style: StrokeStyle(lineWidth: size * 0.03, lineCap: .round)).frame(width: size * 0.1, height: size * 0.045).offset(y: size * 0.12)
                }
            case .excited:
                ForEach([-1.0, 1.0], id: \.self) { s in
                    eye(ink, w: 0.13, h: blink ? 0.015 : 0.15).offset(x: CGFloat(s) * eyeX, y: eyeY)
                }
                Arc(up: false).fill(ink).frame(width: size * 0.22, height: size * 0.15).offset(y: size * 0.13)
            case .busy:
                let look = CGFloat(sin(t * 2.4)) * size * 0.025
                ForEach([-1.0, 1.0], id: \.self) { s in
                    ZStack {
                        Ellipse().fill(.white).frame(width: size * 0.12, height: size * (blink ? 0.015 : 0.12))
                        Circle().fill(ink).frame(width: size * 0.06).offset(x: look).opacity(blink ? 0 : 1)
                    }
                    .offset(x: CGFloat(s) * eyeX, y: eyeY)
                }
                Capsule().fill(ink).frame(width: size * 0.1, height: size * 0.025).offset(y: size * 0.13)
            case .stressed:
                ForEach([-1.0, 1.0], id: \.self) { s in
                    eye(ink, w: 0.07, h: blink ? 0.01 : 0.07).offset(x: CGFloat(s) * eyeX, y: eyeY)
                }
                Wave(time: t).stroke(ink, style: StrokeStyle(lineWidth: size * 0.028, lineCap: .round)).frame(width: size * 0.2, height: size * 0.05).offset(y: size * 0.13)
            case .sad:
                ForEach([-1.0, 1.0], id: \.self) { s in
                    eye(ink, w: 0.1, h: blink ? 0.012 : 0.11).offset(x: CGFloat(s) * eyeX, y: eyeY + size * 0.02)
                    Capsule().fill(ink).frame(width: size * 0.09, height: size * 0.02)
                        .rotationEffect(.degrees(Double(s) * 18)).offset(x: CGFloat(s) * eyeX, y: eyeY - size * 0.08)
                }
                Arc(up: true).stroke(ink, style: StrokeStyle(lineWidth: size * 0.03, lineCap: .round)).frame(width: size * 0.12, height: size * 0.05).offset(y: size * 0.15)
            }
        }
    }

    private func eye(_ ink: Color, w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Ellipse().fill(ink).frame(width: size * w, height: size * h)
            Circle().fill(.white).frame(width: size * w * 0.38).offset(x: -size * w * 0.18, y: -size * h * 0.2).opacity(h > 0.03 ? 1 : 0)
        }
    }

    // MARK: Extras (Zzz, hearts, steam, sparkles, sweat, tears)

    @ViewBuilder private func extras(_ t: Double) -> some View {
        switch mood {
        case .sleepy:
            ForEach(0..<3, id: \.self) { i in
                let p = (t / 2.6 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                Text("z").font(.system(size: size * (0.12 + 0.08 * p), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(1 - p))
                    .offset(x: size * (0.28 + 0.12 * p), y: -size * (0.25 + 0.35 * p))
            }
        case .loving:
            ForEach(0..<3, id: \.self) { i in
                let p = (t / 2.2 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                HeartShape().fill(Color(red: 1, green: 0.35, blue: 0.55))
                    .frame(width: size * 0.1, height: size * 0.09)
                    .offset(x: size * CGFloat(-0.3 + 0.3 * Double(i) + 0.05 * sin(t * 3 + Double(i))), y: -size * (0.35 + 0.35 * p))
                    .opacity(1 - p)
            }
        case .cozy:
            ForEach(0..<2, id: \.self) { i in
                let p = (t / 2.8 + Double(i) / 2).truncatingRemainder(dividingBy: 1)
                Wave(time: t + Double(i)).stroke(.white.opacity(0.6 * (1 - p)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .frame(width: size * 0.06, height: size * 0.2)
                    .rotationEffect(.degrees(90))
                    .offset(x: CGFloat(i == 0 ? -1 : 1) * size * 0.1, y: -size * (0.42 + 0.2 * p))
            }
        case .excited:
            ForEach(0..<4, id: \.self) { i in
                let a = Double(i) / 4 * 2 * .pi + t
                Image(systemName: "sparkle").font(.system(size: size * 0.12))
                    .foregroundStyle(Color(red: 1, green: 0.9, blue: 0.5))
                    .offset(x: cos(a) * size * 0.55, y: sin(a) * size * 0.45)
                    .opacity(0.5 + 0.5 * sin(t * 6 + Double(i)))
            }
        case .stressed:
            let p = (t / 1.6).truncatingRemainder(dividingBy: 1)
            Drop().fill(Color(red: 0.6, green: 0.85, blue: 1))
                .frame(width: size * 0.08, height: size * 0.12)
                .offset(x: size * 0.3, y: -size * 0.2 + size * 0.2 * p)
                .opacity(1 - p)
        case .sad:
            let p = (t / 2.4).truncatingRemainder(dividingBy: 1)
            Drop().fill(Color(red: 0.65, green: 0.88, blue: 1))
                .frame(width: size * 0.06, height: size * 0.09)
                .offset(x: -size * 0.15, y: size * 0.04 + size * 0.35 * p)
                .opacity(p < 0.85 ? 1 : (1 - p) * 6)
        case .busy:
            Image(systemName: "gearshape.fill").font(.system(size: size * 0.16))
                .foregroundStyle(.white.opacity(0.8))
                .rotationEffect(.degrees(t * 120))
                .offset(x: size * 0.34, y: -size * 0.34)
        case .happy:
            EmptyView()
        }
    }
}

// MARK: - Shapes

struct BlobShape: Shape {
    var time: Double
    var wobble: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY + r.height * 0.04)
        let n = 64
        for i in 0...n {
            let a = Double(i) / Double(n) * 2 * .pi
            let w = 1 + wobble * CGFloat(sin(3 * a + time * 1.7) + 0.6 * sin(5 * a - time * 1.3))
            // slightly flat-bottomed jelly
            let flat: CGFloat = sin(a) > 0 ? 1 - 0.08 * CGFloat(sin(a)) : 1
            let pt = CGPoint(x: c.x + r.width / 2 * w * CGFloat(cos(a)), y: c.y + r.height / 2 * w * flat * CGFloat(sin(a)))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}

private struct Arc: Shape {
    var up: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        if up {
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY - r.height))
        } else {
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY + r.height))
        }
        return p
    }
}

private struct Wave: Shape {
    var time: Double
    func path(in r: CGRect) -> Path {
        var p = Path()
        for i in 0...20 {
            let x = r.minX + r.width * CGFloat(i) / 20
            let y = r.midY + r.height / 2 * CGFloat(sin(Double(i) / 20 * 3 * .pi + time * 4))
            i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
        }
        return p
    }
}

private struct Drop: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY - r.width / 2), control: CGPoint(x: r.maxX, y: r.midY))
        p.addArc(center: CGPoint(x: r.midX, y: r.maxY - r.width / 2), radius: r.width / 2, startAngle: .zero, endAngle: .degrees(180), clockwise: false)
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: CGPoint(x: r.minX, y: r.midY))
        return p
    }
}
