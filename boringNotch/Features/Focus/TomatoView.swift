//
//  TomatoView.swift
//  SimpleNotch
//
//  The Tomato: the Pomodoro's cartoon mascot, drawn entirely in SwiftUI so it
//  scales from a 20 pt Wing to the Focus tab and every movement is a spring.
//  `mood` is the steady state; `pulse` replays one-shot reactions.
//

import SwiftUI

enum TomatoMood: Equatable {
    /// Nothing running: sitting, smiling.
    case idle
    /// Focus session: breathing and blinking.
    case working
    /// Paused: asleep, "z z".
    case sleeping
    /// Short break: sunglasses.
    case chilling
    /// Long break: sipping a drink.
    case sipping
    /// Waiting for the user to start Focus: tapping a foot.
    case waiting
    /// Interval complete.
    case happy
}

/// Values a one-shot reaction animates.
private struct TomatoMotion {
    var offsetY: CGFloat = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var rotation: Double = 0
    var leafLift: Double = 0
    var mouthOpen: CGFloat = 0
    var opacity: Double = 1
}

private struct Frame<V> {
    var value: V
    var duration: TimeInterval
}

struct TomatoView: View {
    var mood: TomatoMood
    var pulse = TomatoPulse()
    var size: CGFloat = 64
    /// Small sizes (the Wings) drop details that would turn to mush.
    private var detailed: Bool { size >= 36 }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        KeyframeAnimator(initialValue: TomatoMotion(), trigger: pulse.id) { motion in
            TomatoFigure(mood: mood, motion: motion, size: size, detailed: detailed)
                .scaleEffect(x: motion.scaleX, y: motion.scaleY, anchor: .bottom)
                .rotationEffect(.degrees(motion.rotation), anchor: .bottom)
                .offset(y: motion.offsetY * size / 64)
                .opacity(motion.opacity)
        } keyframes: { _ in
            let kind = reduceMotion ? .none : pulse.kind
            KeyframeTrack(\.offsetY) {
                for f in Self.offsets(kind) { SpringKeyframe(f.value, duration: f.duration) }
            }
            KeyframeTrack(\.scaleX) {
                for f in Self.scaleX(kind) { SpringKeyframe(f.value, duration: f.duration) }
            }
            KeyframeTrack(\.scaleY) {
                for f in Self.scaleY(kind) { SpringKeyframe(f.value, duration: f.duration) }
            }
            KeyframeTrack(\.rotation) {
                for f in Self.rotation(kind) { SpringKeyframe(f.value, duration: f.duration) }
            }
            KeyframeTrack(\.leafLift) {
                for f in Self.leafLift(kind) { SpringKeyframe(f.value, duration: f.duration) }
            }
            KeyframeTrack(\.mouthOpen) {
                for f in Self.mouth(kind) { SpringKeyframe(f.value, duration: f.duration) }
            }
            KeyframeTrack(\.opacity) {
                for f in Self.opacity(kind) { SpringKeyframe(f.value, duration: f.duration) }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    // MARK: Reactions
    // Each reaction is a short list of spring keyframes per property. Unused
    // properties hold their rest value so tracks stay aligned.

    private static func offsets(_ kind: TomatoPulse.Kind) -> [Frame<CGFloat>] {
        switch kind {
        case .drop: [.init(value: -70, duration: 0.001), .init(value: 0, duration: 0.32), .init(value: -8, duration: 0.18), .init(value: 0, duration: 0.3)]
        case .celebrate: [.init(value: -16, duration: 0.2), .init(value: 0, duration: 0.2), .init(value: -10, duration: 0.18), .init(value: 0, duration: 0.3)]
        case .wake: [.init(value: -6, duration: 0.15), .init(value: 0, duration: 0.3)]
        case .yawn, .none: [.init(value: 0, duration: 0.01)]
        }
    }

    private static func scaleX(_ kind: TomatoPulse.Kind) -> [Frame<CGFloat>] {
        switch kind {
        case .drop: [.init(value: 0.9, duration: 0.3), .init(value: 1.22, duration: 0.08), .init(value: 0.94, duration: 0.18), .init(value: 1, duration: 0.3)]
        case .celebrate: [.init(value: 0.92, duration: 0.2), .init(value: 1.12, duration: 0.12), .init(value: 1, duration: 0.4)]
        case .yawn: [.init(value: 0.94, duration: 0.5), .init(value: 1.04, duration: 0.4), .init(value: 1, duration: 0.5)]
        case .wake, .none: [.init(value: 1, duration: 0.01)]
        }
    }

    private static func scaleY(_ kind: TomatoPulse.Kind) -> [Frame<CGFloat>] {
        switch kind {
        case .drop: [.init(value: 1.12, duration: 0.3), .init(value: 0.76, duration: 0.08), .init(value: 1.06, duration: 0.18), .init(value: 1, duration: 0.3)]
        case .celebrate: [.init(value: 1.1, duration: 0.2), .init(value: 0.9, duration: 0.12), .init(value: 1, duration: 0.4)]
        case .yawn: [.init(value: 1.1, duration: 0.5), .init(value: 0.96, duration: 0.4), .init(value: 1, duration: 0.5)]
        case .wake, .none: [.init(value: 1, duration: 0.01)]
        }
    }

    private static func rotation(_ kind: TomatoPulse.Kind) -> [Frame<Double>] {
        switch kind {
        case .wake: [.init(value: -12, duration: 0.08), .init(value: 11, duration: 0.1), .init(value: -8, duration: 0.1), .init(value: 5, duration: 0.1), .init(value: 0, duration: 0.3)]
        case .celebrate: [.init(value: -6, duration: 0.2), .init(value: 6, duration: 0.2), .init(value: 0, duration: 0.3)]
        case .yawn: [.init(value: -4, duration: 0.6), .init(value: 0, duration: 0.6)]
        case .drop, .none: [.init(value: 0, duration: 0.01)]
        }
    }

    private static func leafLift(_ kind: TomatoPulse.Kind) -> [Frame<Double>] {
        switch kind {
        case .drop: [.init(value: -0.6, duration: 0.3), .init(value: 1, duration: 0.14), .init(value: 0, duration: 0.5)]
        case .celebrate: [.init(value: 1, duration: 0.2), .init(value: 0.3, duration: 0.2), .init(value: 0.9, duration: 0.18), .init(value: 0, duration: 0.4)]
        case .wake: [.init(value: 0.8, duration: 0.12), .init(value: 0, duration: 0.4)]
        case .yawn, .none: [.init(value: 0, duration: 0.01)]
        }
    }

    private static func mouth(_ kind: TomatoPulse.Kind) -> [Frame<CGFloat>] {
        switch kind {
        case .yawn: [.init(value: 1, duration: 0.5), .init(value: 1, duration: 0.4), .init(value: 0, duration: 0.5)]
        case .drop: [.init(value: 0, duration: 0.38), .init(value: 0.5, duration: 0.15), .init(value: 0, duration: 0.5)]
        case .celebrate, .wake, .none: [.init(value: 0, duration: 0.01)]
        }
    }

    private static func opacity(_ kind: TomatoPulse.Kind) -> [Frame<Double>] {
        switch kind {
        case .drop: [.init(value: 0, duration: 0.001), .init(value: 1, duration: 0.15)]
        default: [.init(value: 1, duration: 0.01)]
        }
    }
}

// MARK: - Figure

private struct TomatoFigure: View {
    let mood: TomatoMood
    let motion: TomatoMotion
    let size: CGFloat
    let detailed: Bool

    private static let red = Color(red: 0.98, green: 0.30, blue: 0.24)
    private static let deepRed = Color(red: 0.78, green: 0.14, blue: 0.12)
    private static let leaf = Color(red: 0.33, green: 0.72, blue: 0.30)
    private static let deepLeaf = Color(red: 0.18, green: 0.50, blue: 0.20)

    var body: some View {
        let s = size
        ZStack {
            if detailed && mood == .waiting { TappingFeet(size: s) }
            if detailed && mood != .waiting { Feet(size: s) }

            Breathing(active: mood == .working || mood == .sleeping || mood == .idle, slow: mood == .sleeping) {
                ZStack {
                    body(s)
                    Calyx(size: s, lift: motion.leafLift + (mood == .happy ? 0.5 : 0), sleepy: mood == .sleeping)
                        .offset(y: -s * 0.33)
                    Face(mood: mood, size: s, mouthOpen: motion.mouthOpen, detailed: detailed)
                        .offset(y: s * 0.06)
                    if mood == .chilling { Sunglasses(size: s).offset(y: s * 0.0).transition(.softPop) }
                }
                .rotationEffect(.degrees(mood == .sleeping ? -7 : 0), anchor: .bottom)
            }

            if mood == .sipping && detailed {
                Drink(size: s)
                    .offset(x: s * 0.36, y: s * 0.14)
                    .transition(.softPop)
            }
            if mood == .sleeping && detailed {
                SleepBubbles(size: s)
                    .offset(x: s * 0.36, y: -s * 0.34)
                    .transition(.opacity)
            }
        }
        .frame(width: s, height: s)
        .animation(Motion.respecting(Motion.bouncy), value: mood)
    }

    private func body(_ s: CGFloat) -> some View {
        TomatoBody(size: s, detailed: detailed)
            .frame(width: s * 0.86, height: s * 0.74)
            .offset(y: s * 0.07)
            .shadow(color: Self.deepRed.opacity(0.45), radius: s * 0.05, y: s * 0.025)
    }
}

/// The fruit, shaded for a soft pseudo-3D look: key light from the top left,
/// a shadowed lower-right edge, warm bounce light underneath, a hollow round
/// the stem and a two-part specular highlight. Flattened into one layer so the
/// breathing scale costs a single texture transform.
private struct TomatoBody: View {
    let size: CGFloat
    let detailed: Bool

    private static let light = Color(red: 1.0, green: 0.52, blue: 0.40)
    private static let red = Color(red: 0.95, green: 0.24, blue: 0.19)
    private static let deep = Color(red: 0.55, green: 0.06, blue: 0.07)

    var body: some View {
        let s = size
        let shape = TomatoBodyShape()
        ZStack {
            // Form: lit top left, falling off to a deep red rim.
            shape.fill(
                RadialGradient(
                    stops: [
                        .init(color: Self.light, location: 0),
                        .init(color: Self.red, location: 0.38),
                        .init(color: Self.deep, location: 0.95),
                    ],
                    center: UnitPoint(x: 0.35, y: 0.3),
                    startRadius: 0,
                    endRadius: s * 0.52
                )
                .shadow(.inner(color: Self.deep.opacity(detailed ? 0.9 : 0.6), radius: s * 0.09, x: -s * 0.04, y: -s * 0.06))
            )

            if detailed {
                Group {
                    // Warm light bounced up from below.
                    Ellipse()
                        .fill(Color(red: 1.0, green: 0.45, blue: 0.25).opacity(0.45))
                        .frame(width: s * 0.5, height: s * 0.12)
                        .offset(x: -s * 0.04, y: s * 0.3)
                        .blur(radius: s * 0.05)
                    // Soft ribs: broad, faint shading, never an outline.
                    ForEach([-0.17, 0.17], id: \.self) { x in
                        Capsule()
                            .fill(Self.deep.opacity(0.28))
                            .frame(width: s * 0.05, height: s * 0.5)
                            .rotationEffect(.degrees(x < 0 ? 8 : -8))
                            .offset(x: s * x, y: s * 0.06)
                            .blur(radius: s * 0.04)
                    }
                    // The hollow round the stem, shadowed by the leaves.
                    Ellipse()
                        .fill(Self.deep.opacity(0.7))
                        .frame(width: s * 0.3, height: s * 0.12)
                        .offset(y: -s * 0.3)
                        .blur(radius: s * 0.035)
                    // Broad sheen, then the sharp glint inside it.
                    Ellipse()
                        .fill(.white.opacity(0.22))
                        .frame(width: s * 0.3, height: s * 0.17)
                        .rotationEffect(.degrees(-30))
                        .offset(x: -s * 0.17, y: -s * 0.13)
                        .blur(radius: s * 0.03)
                }
                .mask(shape)
            }

            Ellipse()
                .fill(.white.opacity(detailed ? 0.8 : 0.45))
                .frame(width: s * 0.12, height: s * 0.055)
                .rotationEffect(.degrees(-30))
                .offset(x: -s * 0.2, y: -s * 0.17)
                .blur(radius: s * 0.006)
            if detailed {
                Circle()
                    .fill(.white.opacity(0.7))
                    .frame(width: s * 0.025)
                    .offset(x: -s * 0.1, y: -s * 0.22)
                    .blur(radius: s * 0.003)
            }
        }
        .drawingGroup()
    }
}

/// A tomato rather than a ball: dimpled at the stem, shouldered, and softly
/// two-lobed underneath.
private struct TomatoBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var p = Path()
        p.move(to: pt(0.5, 0.065))
        p.addCurve(to: pt(0.0, 0.5), control1: pt(0.27, -0.02), control2: pt(0.0, 0.2))
        p.addCurve(to: pt(0.32, 0.985), control1: pt(0.0, 0.8), control2: pt(0.15, 0.99))
        p.addCurve(to: pt(0.5, 0.96), control1: pt(0.41, 0.98), control2: pt(0.46, 0.965))
        p.addCurve(to: pt(0.68, 0.985), control1: pt(0.54, 0.965), control2: pt(0.59, 0.98))
        p.addCurve(to: pt(1.0, 0.5), control1: pt(0.85, 0.99), control2: pt(1.0, 0.8))
        p.addCurve(to: pt(0.5, 0.065), control1: pt(1.0, 0.2), control2: pt(0.73, -0.02))
        p.closeSubpath()
        return p
    }
}

/// Slow scale "breath" while the Tomato is alive. Runs only while visible.
private struct Breathing<Content: View>: View {
    let active: Bool
    var slow = false
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if active && !reduceMotion {
            content.phaseAnimator([false, true]) { view, inhale in
                view.scaleEffect(x: inhale ? 1.025 : 1, y: inhale ? 1.04 : 1, anchor: .bottom)
            } animation: { _ in
                .smooth(duration: slow ? 2.4 : 1.7)
            }
        } else {
            content
        }
    }
}

private struct Calyx: View {
    let size: CGFloat
    let lift: Double
    let sleepy: Bool

    var body: some View {
        let s = size
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                let angle = -90.0 + Double(i - 2) * 36
                LeafShape()
                    .fill(LinearGradient(colors: [Color(red: 0.50, green: 0.86, blue: 0.40), Color(red: 0.16, green: 0.48, blue: 0.20)], startPoint: .top, endPoint: .bottom))
                    .overlay {
                        // Midrib.
                        Capsule()
                            .fill(.white.opacity(0.25))
                            .frame(width: max(0.5, s * 0.008))
                            .padding(.vertical, s * 0.03)
                    }
                    .frame(width: s * 0.1, height: s * 0.22)
                    .offset(y: -s * 0.09)
                    // Leaves spring up with `lift` and droop while asleep.
                    .rotationEffect(.degrees(angle + 90 + (Double(i) - 2) * (lift * 10 - (sleepy ? 8 : 0))))
                    .scaleEffect(1 + lift * 0.15)
            }
            Capsule()
                .fill(Color(red: 0.24, green: 0.52, blue: 0.20))
                .frame(width: s * 0.05, height: s * 0.13)
                .rotationEffect(.degrees(12 + lift * 14))
                .offset(y: -s * 0.08 - lift * s * 0.03)
        }
        .frame(width: s * 0.4, height: s * 0.2)
        .shadow(color: .black.opacity(0.3), radius: s * 0.015, y: s * 0.015)
    }
}

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX * 1.1, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX - rect.width * 0.1, y: rect.midY))
        return p
    }
}

private struct Face: View {
    let mood: TomatoMood
    let size: CGFloat
    let mouthOpen: CGFloat
    let detailed: Bool

    var body: some View {
        let s = size
        VStack(spacing: s * 0.05) {
            HStack(spacing: s * 0.17) {
                TomatoEye(mood: mood, size: s)
                TomatoEye(mood: mood, size: s)
            }
            .opacity(mood == .chilling ? 0 : 1)
            ZStack {
                if detailed {
                    HStack(spacing: s * 0.34) {
                        Circle().fill(Color.pink.opacity(0.45))
                        Circle().fill(Color.pink.opacity(0.45))
                    }
                    .frame(height: s * 0.07)
                    .blur(radius: s * 0.012)
                    .offset(y: -s * 0.02)
                }
                Mouth(mood: mood, size: s, open: mouthOpen)
            }
        }
    }
}

private struct TomatoEye: View {
    let mood: TomatoMood
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let s = size
        Group {
            if mood == .sleeping {
                ArcShape(up: false)
                    .stroke(.black.opacity(0.8), style: StrokeStyle(lineWidth: max(1, s * 0.025), lineCap: .round))
                    .frame(width: s * 0.1, height: s * 0.04)
            } else if mood == .happy {
                ArcShape(up: true)
                    .stroke(.black.opacity(0.85), style: StrokeStyle(lineWidth: max(1, s * 0.03), lineCap: .round))
                    .frame(width: s * 0.1, height: s * 0.05)
            } else {
                openEye(s)
                    .phaseAnimator(reduceMotion ? [1.0] : [1.0, 1.0, 0.1, 1.0]) { eye, openness in
                        eye.scaleEffect(y: openness)
                    } animation: { openness in
                        // Hold open ~3.5 s, blink fast.
                        openness < 1 ? .snappy(duration: 0.09) : .snappy(duration: 1.75)
                    }
            }
        }
        .frame(width: s * 0.11, height: s * 0.12)
        .transition(.softPop)
    }

    private func openEye(_ s: CGFloat) -> some View {
        ZStack {
            Ellipse().fill(.black.opacity(0.88))
                .frame(width: s * 0.085, height: s * 0.11)
            Circle().fill(.white)
                .frame(width: s * 0.03)
                .offset(x: s * 0.015, y: -s * 0.025)
            Circle().fill(.white.opacity(0.6))
                .frame(width: s * 0.013)
                .offset(x: -s * 0.015, y: s * 0.025)
        }
    }
}

private struct ArcShape: Shape {
    var up: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: up ? rect.maxY : rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: up ? rect.maxY : rect.minY),
            control: CGPoint(x: rect.midX, y: up ? rect.minY - rect.height : rect.maxY + rect.height)
        )
        return p
    }
}

private struct Mouth: View {
    let mood: TomatoMood
    let size: CGFloat
    let open: CGFloat

    var body: some View {
        let s = size
        ZStack {
            // A yawn or "oh" morphs from the smile by animating `open`.
            if open > 0.05 {
                Ellipse()
                    .fill(Color(red: 0.35, green: 0.05, blue: 0.05))
                    .frame(width: s * (0.07 + 0.04 * open), height: s * 0.1 * open)
                    .transition(.softPop)
            } else {
                switch mood {
                case .happy, .chilling, .sipping:
                    // Big grin.
                    GrinShape()
                        .fill(Color(red: 0.35, green: 0.05, blue: 0.05))
                        .frame(width: s * 0.17, height: s * 0.08)
                case .sleeping:
                    Circle()
                        .fill(Color(red: 0.35, green: 0.05, blue: 0.05).opacity(0.8))
                        .frame(width: s * 0.035)
                case .waiting:
                    Capsule()
                        .fill(.black.opacity(0.75))
                        .frame(width: s * 0.09, height: max(1, s * 0.022))
                default:
                    ArcShape(up: false)
                        .stroke(.black.opacity(0.8), style: StrokeStyle(lineWidth: max(1, s * 0.025), lineCap: .round))
                        .frame(width: s * 0.12, height: s * 0.03)
                }
            }
        }
        .frame(height: s * 0.1)
        .animation(Motion.respecting(Motion.bouncy), value: open > 0.05)
    }
}

private struct GrinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 1.8))
        p.closeSubpath()
        return p
    }
}

private struct Sunglasses: View {
    let size: CGFloat
    var body: some View {
        let s = size
        HStack(spacing: s * 0.03) {
            lens(s)
            lens(s)
        }
        .overlay {
            Rectangle().fill(.black).frame(width: s * 0.36, height: max(1, s * 0.02)).offset(y: -s * 0.03)
        }
    }

    private func lens(_ s: CGFloat) -> some View {
        UnevenRoundedRectangle(topLeadingRadius: s * 0.02, bottomLeadingRadius: s * 0.07, bottomTrailingRadius: s * 0.07, topTrailingRadius: s * 0.02)
            .fill(LinearGradient(colors: [.black, Color(white: 0.25)], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .topLeading) {
                Capsule().fill(.white.opacity(0.35)).frame(width: s * 0.05, height: s * 0.015).rotationEffect(.degrees(-20)).offset(x: s * 0.02, y: s * 0.02)
            }
            .frame(width: s * 0.15, height: s * 0.1)
    }
}

private struct Drink: View {
    let size: CGFloat
    var body: some View {
        let s = size
        ZStack(alignment: .bottom) {
            // Straw.
            Capsule()
                .fill(Color(red: 1.0, green: 0.85, blue: 0.3))
                .frame(width: s * 0.025, height: s * 0.24)
                .rotationEffect(.degrees(-18))
                .offset(x: -s * 0.02, y: -s * 0.1)
            UnevenRoundedRectangle(topLeadingRadius: s * 0.01, bottomLeadingRadius: s * 0.04, bottomTrailingRadius: s * 0.04, topTrailingRadius: s * 0.01)
                .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.62, blue: 0.2), Color(red: 1.0, green: 0.42, blue: 0.3)], startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    Rectangle().fill(.white.opacity(0.3)).frame(height: s * 0.02)
                }
                .frame(width: s * 0.14, height: s * 0.2)
        }
    }
}

private struct Feet: View {
    let size: CGFloat
    var body: some View {
        let s = size
        HStack(spacing: s * 0.2) {
            foot(s)
            foot(s)
        }
        .offset(y: s * 0.42)
    }
}

private func foot(_ s: CGFloat) -> some View {
    Capsule()
        .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.68, blue: 0.30), Color(red: 0.16, green: 0.42, blue: 0.16)], startPoint: .top, endPoint: .bottom))
        .frame(width: s * 0.13, height: s * 0.06)
}

/// One foot taps while the Tomato waits for the user.
private struct TappingFeet: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let s = size
        HStack(spacing: s * 0.2) {
            foot(s)
            foot(s)
                .phaseAnimator(reduceMotion ? [0.0] : [0.0, -24.0]) { f, angle in
                    f.rotationEffect(.degrees(angle), anchor: .leading)
                } animation: { angle in
                    angle == 0 ? .snappy(duration: 0.16) : .snappy(duration: 0.22)
                }
        }
        .offset(y: s * 0.42)
    }
}

/// "z z" drifting up while paused.
private struct SleepBubbles: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let s = size
        ZStack {
            ForEach(0..<2, id: \.self) { i in
                Text("z")
                    .font(.system(size: s * (0.16 + CGFloat(i) * 0.05), weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .phaseAnimator(reduceMotion ? [0.5] : [0.0, 1.0]) { z, t in
                        z.offset(x: t * s * 0.08 + CGFloat(i) * s * 0.08, y: -t * s * 0.22 - CGFloat(i) * s * 0.1)
                            .opacity(t < 1 ? 1 : 0)
                            .scaleEffect(0.6 + t * 0.5)
                    } animation: { t in
                        t == 0 ? .linear(duration: 0.01).delay(Double(i) * 0.8) : .smooth(duration: 1.6)
                    }
            }
        }
    }
}
