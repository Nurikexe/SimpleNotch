//
//  FocusTabView.swift
//  SimpleNotch
//
//  The Focus tab: Pomodoro with the Tomato, or a calm Timer ring.
//

import AppKit
import Defaults
import SwiftUI

struct FocusTabView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var focus = FocusManager.shared
    @Namespace private var modeNamespace

    /// The run this view shows: the live one if it matches the shown mode.
    private var shownRun: FocusRun? {
        guard let run = focus.run, run.mode == focus.shownMode else { return nil }
        return run
    }

    private var tint: Color {
        FocusManager.tint(for: shownRun?.phase ?? .focus, mode: focus.shownMode)
    }

    static func mood(for run: FocusRun?) -> TomatoMood {
        guard let run else { return .idle }
        switch run.state {
        case .paused: return .sleeping
        case .waiting: return run.isBreak ? .happy : .waiting
        case .finished: return .happy
        case .running:
            switch run.phase {
            case .focus: return .working
            case .shortBreak: return .chilling
            case .longBreak: return .sipping
            }
        }
    }

    var body: some View {
        HStack(spacing: 22) {
            dial
                .frame(width: 112, height: 112)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    modeSwitcher
                    Spacer(minLength: 0)
                    if focus.shownMode == .pomodoro {
                        TallyRow(count: focus.todayTally)
                    }
                }
                statusLine
                if focus.shownMode == .pomodoro {
                    TimeReadout(run: shownRun, idleSeconds: TimeInterval(Defaults[.pomodoroFocusMinutes] * 60), tint: tint)
                } else {
                    TimerReadout(run: shownRun, tint: tint)
                }
                controls
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if focus.confirmingSwitch {
                SwitchConfirmation(target: focus.shownMode)
                    .transition(.notchContent)
            }
        }
        .animation(Motion.respecting(Motion.smooth), value: focus.shownMode)
        .animation(Motion.respecting(Motion.smooth), value: shownRun?.state)
        .animation(Motion.respecting(Motion.smooth), value: shownRun?.phase)
        .animation(Motion.respecting(Motion.snappy), value: focus.confirmingSwitch)
    }

    // MARK: Dial

    @ViewBuilder
    private var dial: some View {
        ZStack {
            if focus.shownMode == .pomodoro {
                ring(lineWidth: 7)
                TomatoView(mood: Self.mood(for: shownRun), pulse: focus.pulse, size: 70)
                    .offset(y: 2)
                if focus.pulse.kind == .celebrate {
                    ConfettiBurst(colors: [Color(red: 1, green: 0.95, blue: 0.75), .yellow, Color(red: 0.4, green: 0.8, blue: 0.35), .white])
                        .frame(width: 220, height: 160)
                        .id(focus.pulse.id)
                }
            } else {
                TimerDial(run: shownRun, tint: tint)
            }
        }
        .transition(.notchContent)
        .id(focus.shownMode)
    }

    @ViewBuilder
    private func ring(lineWidth: CGFloat) -> some View {
        if let run = shownRun {
            FocusClock(run: run) { now in
                FocusRing(progress: run.progress(at: now), tint: tint, lineWidth: lineWidth, dimmed: run.state == .paused)
            }
        } else {
            FocusRing(progress: 0, tint: tint, lineWidth: lineWidth)
        }
    }

    // MARK: Header

    private var modeSwitcher: some View {
        HStack(spacing: 2) {
            modeButton(.pomodoro, title: "Pomodoro")
            modeButton(.timer, title: "Timer")
        }
        .padding(2)
        .background(Capsule().fill(.white.opacity(0.07)))
    }

    private func modeButton(_ mode: FocusRun.Mode, title: LocalizedStringKey) -> some View {
        let selected = focus.shownMode == mode
        return Button {
            withMotion(Motion.snappy) {
                focus.shownMode = mode
                focus.confirmingSwitch = false
            }
        } label: {
            HStack(spacing: 4) {
                if focus.run?.mode == mode {
                    // The mode with a live run carries a dot.
                    Circle().fill(FocusManager.tint(for: focus.run?.phase ?? .focus, mode: mode))
                        .frame(width: 5, height: 5)
                        .transition(.softPop)
                }
                Text(title)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(selected ? .white : .gray)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                if selected {
                    Capsule().fill(.white.opacity(0.14))
                        .matchedGeometryEffect(id: "mode", in: modeNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusLine: some View {
        Group {
            if let endedAt = shownRun?.endedAt {
                Text("Ended \(endedAt, style: .relative) ago")
            } else if let run = shownRun {
                switch (run.mode, run.state, run.phase) {
                case (.timer, .finished, _): Text("Time's up")
                case (_, .paused, _): Text("Paused")
                case (.timer, _, _): Text("Timer")
                case (_, .waiting, .focus): Text("Break's over. Ready to focus?")
                case (_, .waiting, .shortBreak): Text("Nice work! Short break next")
                case (_, .waiting, .longBreak): Text("Great work! Long break next")
                case (_, _, .focus):
                    Text("Focus · session \(run.completedInCycle + 1) of \(Defaults[.pomodoroSessionsBeforeLongBreak])")
                case (_, _, .shortBreak): Text("Short break")
                case (_, _, .longBreak): Text("Long break")
                }
            } else {
                Text(focus.shownMode == .pomodoro ? "Ready when you are" : "Drag the ring or pick a time")
            }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.gray)
        .lineLimit(1)
        .contentTransition(.opacity)
    }

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 8) {
            if focus.shownMode == .timer && shownRun == nil {
                TimerPresets()
                    .transition(.notchContent)
                Spacer(minLength: 0)
                ControlButton(symbol: "play.fill", tint: tint, prominent: true, help: "Start") { focus.startTimer() }
            } else if let run = shownRun {
                switch run.state {
                case .running, .paused:
                    ControlButton(symbol: run.state == .running ? "pause.fill" : "play.fill", tint: tint, prominent: true, help: run.state == .running ? "Pause" : "Resume") {
                        focus.togglePause()
                    }
                    if run.mode == .pomodoro {
                        ControlButton(symbol: "forward.end.fill", tint: tint, help: "Skip") { focus.skip() }
                    } else {
                        ControlButton(text: "+1", tint: tint, help: "Add a minute") { focus.addMinute() }
                    }
                    ControlButton(symbol: "stop.fill", tint: tint, help: "Stop") { focus.reset() }
                case .waiting:
                    PulsingStartButton(title: run.isBreak ? "Start break" : "Start focus", tint: tint) { focus.startNext() }
                    ControlButton(symbol: "stop.fill", tint: tint, help: "Stop") { focus.reset() }
                case .finished:
                    PulsingStartButton(title: "Dismiss", tint: tint) { focus.reset() }
                    ControlButton(symbol: "arrow.clockwise", tint: tint, help: "Restart") {
                        focus.reset()
                        focus.startTimer()
                    }
                }
            } else {
                PulsingStartButton(title: "Start focus", tint: tint, pulses: false) { focus.startPomodoro() }
            }
        }
        .frame(height: 30)
    }
}

// MARK: - Pieces

private struct TimeReadout: View {
    let run: FocusRun?
    let idleSeconds: TimeInterval
    let tint: Color

    var body: some View {
        Group {
            if let run {
                FocusClock(run: run) { now in
                    digits(run.remaining(at: now))
                }
            } else {
                digits(idleSeconds)
            }
        }
        .foregroundStyle(run?.state == .paused ? .gray : .white)
    }

    private func digits(_ seconds: TimeInterval) -> some View {
        Text(FocusFormat.clock(seconds))
            .font(.system(size: 38, weight: .semibold, design: .rounded).monospacedDigit())
            .contentTransition(.numericText(countsDown: true))
            .animation(Motion.snappy, value: Int(seconds.rounded(.up)))
    }
}

/// Timer digits; click them to type an exact time.
private struct TimerReadout: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var focus = FocusManager.shared
    let run: FocusRun?
    let tint: Color

    @State private var editing = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        if editing {
            TextField("mm:ss", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 38, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(tint)
                .focused($fieldFocused)
                .frame(width: 170, height: 46, alignment: .leading)
                .onSubmit(commit)
                .onExitCommand(perform: endEditing)
                .onChange(of: fieldFocused) { _, focused in if !focused { commit() } }
                .transition(.opacity)
        } else {
            TimeReadout(run: run, idleSeconds: focus.timerSetting, tint: tint)
                .onTapGesture { if run == nil { beginEditing() } }
                .help(run == nil ? Text("Click to type a time") : Text(""))
        }
    }

    private func beginEditing() {
        draft = ""
        vm.pinnedOpen = true
        vm.beginKeyboardSession()
        withMotion(Motion.snappy) { editing = true }
        DispatchQueue.main.async { fieldFocused = true }
    }

    private func commit() {
        guard editing else { return }
        if let seconds = FocusFormat.parse(draft) {
            withMotion(Motion.smooth) { focus.timerSetting = seconds }
        }
        endEditing()
    }

    private func endEditing() {
        withMotion(Motion.snappy) { editing = false }
        vm.endKeyboardSession()
    }
}

/// The calm Timer ring. While idle, drag around it or scroll over it to set
/// minutes (one-minute steps, 60 per turn).
private struct TimerDial: View {
    @ObservedObject private var focus = FocusManager.shared
    let run: FocusRun?
    let tint: Color

    @State private var lastMinutes = 0
    @State private var hovering = false
    @State private var scrollMonitor: Any?
    @State private var scrollAccumulator: CGFloat = 0

    var body: some View {
        ZStack {
            if let run {
                if run.state == .finished {
                    FlashingRing(tint: tint, lineWidth: 7)
                } else {
                    FocusClock(run: run) { now in
                        FocusRing(progress: run.progress(at: now), tint: tint, lineWidth: 7, dimmed: run.state == .paused)
                    }
                }
            } else {
                FocusRing(progress: min(1, focus.timerSetting / 3600), tint: tint, lineWidth: 7)
                    .animation(Motion.interactive, value: focus.timerSetting)
                    .scaleEffect(hovering ? 1.03 : 1)
                    .animation(Motion.snappy, value: hovering)
            }
            centerSymbol
        }
        .contentShape(Circle())
        .gesture(dragToSet, isEnabled: run == nil)
        .onHover { inside in
            hovering = inside && run == nil
            inside && run == nil ? installScroll() : removeScroll()
        }
        .onDisappear(perform: removeScroll)
    }

    @ViewBuilder
    private var centerSymbol: some View {
        let symbol: String = switch run?.state {
        case .finished: "bell.fill"
        case .paused: "pause.fill"
        case .running: "hourglass"
        default: "timer"
        }
        Image(systemName: symbol)
            .font(.system(size: 26, weight: .medium))
            .foregroundStyle(tint.opacity(run?.state == .paused ? 0.5 : 0.9))
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.wiggle, options: .repeating, isActive: run?.state == .finished)
    }

    private var dragToSet: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = CGPoint(x: 56, y: 56)
                let dx = value.location.x - center.x, dy = value.location.y - center.y
                var angle = atan2(dx, -dy)
                if angle < 0 { angle += 2 * .pi }
                var minutes = Int((angle / (2 * .pi) * 60).rounded())
                // Don't wrap past 12 o'clock in either direction.
                if lastMinutes > 45 && minutes < 15 { minutes = 60 }
                if lastMinutes < 15 && lastMinutes > 0 && minutes > 45 { minutes = 1 }
                minutes = min(60, max(1, minutes))
                lastMinutes = minutes
                if TimeInterval(minutes * 60) != focus.timerSetting {
                    focus.timerSetting = TimeInterval(minutes * 60)
                }
            }
            .onEnded { _ in lastMinutes = 0 }
    }

    private func installScroll() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 8
            scrollAccumulator += delta
            let step: CGFloat = 8
            while abs(scrollAccumulator) >= step {
                let direction: TimeInterval = scrollAccumulator > 0 ? 60 : -60
                scrollAccumulator -= scrollAccumulator > 0 ? step : -step
                focus.timerSetting = max(60, focus.timerSetting + direction)
            }
            return nil
        }
    }

    private func removeScroll() {
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
        scrollMonitor = nil
        scrollAccumulator = 0
    }
}

private struct TimerPresets: View {
    @ObservedObject private var focus = FocusManager.shared
    private let minutes = [1, 5, 10, 15, 30, 60]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(minutes, id: \.self) { m in
                let selected = Int(focus.timerSetting) == m * 60
                Button {
                    withMotion(Motion.smooth) { focus.timerSetting = TimeInterval(m * 60) }
                } label: {
                    Text(m == 60 ? "1h" : "\(m)m")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(selected ? .black : .white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(selected ? Color.white : Color.white.opacity(0.08)))
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .animation(Motion.snappy, value: selected)
            }
        }
    }
}

private struct TallyRow: View {
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<min(count, 8), id: \.self) { _ in
                MiniTomato()
                    .transition(.softPop)
            }
            if count > 8 {
                Text("+\(count - 8)")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.gray)
                    .contentTransition(.numericText())
            }
        }
        .help(Text("Focus sessions today: \(count)"))
        .animation(Motion.respecting(Motion.bouncy), value: count)
    }
}

private struct MiniTomato: View {
    var body: some View {
        ZStack(alignment: .top) {
            Circle()
                .fill(RadialGradient(colors: [Color(red: 1, green: 0.38, blue: 0.3), Color(red: 0.8, green: 0.16, blue: 0.13)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 7))
                .frame(width: 10, height: 9)
                .offset(y: 2)
            Capsule()
                .fill(Color(red: 0.3, green: 0.68, blue: 0.28))
                .frame(width: 6, height: 2.5)
        }
        .frame(width: 10, height: 11)
    }
}

private struct ControlButton: View {
    var symbol: String?
    var text: String?
    let tint: Color
    var prominent = false
    let help: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .bold))
                        .contentTransition(.symbolEffect(.replace))
                } else if let text {
                    Text(text)
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                }
            }
            .foregroundStyle(prominent ? .black : .white)
            .frame(width: 30, height: 30)
            .background(Circle().fill(prominent ? tint : Color.white.opacity(0.1)))
            .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .help(help)
        .transition(.softPop)
    }
}

/// "Start focus": pulses gently when the Pomodoro is waiting for the user.
private struct PulsingStartButton: View {
    let title: LocalizedStringKey
    let tint: Color
    var pulses = true
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(Capsule().fill(tint))
                .phaseAnimator(pulses && !reduceMotion ? [false, true] : [false]) { label, up in
                    label
                        .scaleEffect(up ? 1.05 : 1)
                        .shadow(color: tint.opacity(up ? 0.6 : 0), radius: up ? 8 : 0)
                } animation: { _ in .smooth(duration: 0.9) }
                .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .transition(.softPop)
    }
}

private struct SwitchConfirmation: View {
    @ObservedObject private var focus = FocusManager.shared
    let target: FocusRun.Mode

    var body: some View {
        HStack(spacing: 10) {
            Text(target == .pomodoro ? "Stop the running Timer and start a Pomodoro?" : "Stop the running Pomodoro and start a Timer?")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
            Button("Stop and start") { focus.confirmSwitch() }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
            Button("Cancel") { withMotion(Motion.snappy) { focus.confirmingSwitch = false } }
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color(white: 0.12)).shadow(color: .black.opacity(0.5), radius: 8))
        .padding(.bottom, 4)
    }
}

/// Springy press feedback for custom buttons.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}
