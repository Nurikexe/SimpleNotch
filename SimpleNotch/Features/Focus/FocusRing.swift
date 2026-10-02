//
//  FocusRing.swift
//  SimpleNotch
//
//  Progress drawn from the real clock every frame (TimelineView) so rings and
//  the Progress line glide instead of ticking. The timeline pauses whenever
//  nothing is running, keeping idle CPU at zero.
//

import SwiftUI

/// Re-renders `content` every display frame while `run` is running.
struct FocusClock<Content: View>: View {
    let run: FocusRun?
    @ViewBuilder var content: (Date) -> Content

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: run?.state != .running)) { context in
            content(context.date)
        }
    }
}

struct FocusRing: View {
    var progress: Double
    var tint: Color
    var lineWidth: CGFloat
    /// Dimmed while paused.
    var dimmed = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.0001, progress))
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.65), tint],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * max(0.01, progress))
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(dimmed ? 0 : 0.45), radius: lineWidth * 0.8)
        }
        .opacity(dimmed ? 0.45 : 1)
        .saturation(dimmed ? 0.4 : 1)
        .animation(Motion.respecting(Motion.smooth), value: dimmed)
    }
}

/// A ring that flashes until the finished Timer is dismissed.
struct FlashingRing: View {
    var tint: Color
    var lineWidth: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        FocusRing(progress: 1, tint: tint, lineWidth: lineWidth)
            .phaseAnimator(reduceMotion ? [1.0] : [1.0, 0.25]) { ring, level in
                ring.opacity(level).scaleEffect(0.96 + 0.04 * level)
            } animation: { _ in .smooth(duration: 0.55) }
    }
}

// MARK: - Closed notch

struct FocusWingsView: View {
    static let wingWidth: CGFloat = 46
    @ObservedObject private var focus = FocusManager.shared

    var body: some View {
        NotchWings(wingWidth: Self.wingWidth) {
            leading
        } trailing: {
            trailing
        }
    }

    @ViewBuilder
    private var leading: some View {
        if let run = focus.run {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                ZStack {
                    if run.state == .finished {
                        FlashingRing(tint: focus.tint, lineWidth: 2.2)
                    } else {
                        FocusClock(run: run) { now in
                            FocusRing(progress: run.progress(at: now), tint: focus.tint, lineWidth: 2.2, dimmed: run.state == .paused)
                        }
                    }
                    if run.mode == .pomodoro {
                        TomatoView(mood: FocusTabView.mood(for: run), pulse: focus.pulse, size: side * 0.78)
                    }
                }
                .frame(width: side, height: side)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.leading, 2)
            .transition(.softPop)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if let run = focus.run {
            Group {
                switch run.state {
                case .waiting:
                    Image(systemName: run.isBreak ? "cup.and.saucer.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(focus.tint)
                        .symbolEffect(.pulse, options: .repeating)
                case .finished:
                    Text("00:00")
                        .foregroundStyle(focus.tint)
                default:
                    FocusClock(run: run) { now in
                        Text(FocusFormat.clock(run.remaining(at: now)))
                            .contentTransition(.numericText(countsDown: true))
                            .animation(Motion.respecting(Motion.snappy), value: Int(run.remaining(at: now).rounded(.up)))
                            .foregroundStyle(run.state == .paused ? .gray : .white)
                    }
                }
            }
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .lineLimit(1)
            .fixedSize()
            .transition(.softPop)
        }
    }
}

/// Thin progress along the bottom edge of the closed notch.
struct FocusProgressLine: View {
    @ObservedObject private var focus = FocusManager.shared

    var body: some View {
        if let run = focus.run {
            FocusClock(run: run) { now in
                GeometryReader { geo in
                    let inset: CGFloat = 12
                    let width = max(0, geo.size.width - inset * 2)
                    ZStack(alignment: .leading) {
                        Capsule().fill(focus.tint.opacity(0.18))
                        Capsule()
                            .fill(focus.tint)
                            .frame(width: width * run.progress(at: now))
                            .shadow(color: focus.tint.opacity(0.7), radius: 2)
                    }
                    .frame(width: width, height: 2)
                    .opacity(run.state == .paused ? 0.45 : 1)
                    .position(x: geo.size.width / 2, y: geo.size.height - 2)
                }
            }
            .allowsHitTesting(false)
        }
    }
}
