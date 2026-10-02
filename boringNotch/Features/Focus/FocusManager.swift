//
//  FocusManager.swift
//  SimpleNotch
//
//  Runs the Pomodoro and the Timer. Only one FocusRun is live at a time. No
//  per-second timer: the UI reads the clock every frame while visible, and a
//  single sleeping task wakes this manager when the interval ends.
//

import AppKit
import Combine
import Defaults
import SwiftUI

/// One-shot Tomato reactions, replayed when `id` changes.
struct TomatoPulse: Equatable {
    enum Kind { case none, drop, yawn, wake, celebrate }
    var kind: Kind = .none
    var id = UUID()
}

@MainActor
final class FocusManager: ObservableObject, NotchFeature {
    static let shared = FocusManager()
    var enabledKey: Defaults.Key<Bool> { .tabFocusEnabled }

    enum WingsPriority { case none, low, high }

    @Published private(set) var run: FocusRun? {
        didSet { Defaults[.focusRun] = run }
    }
    /// The mode the Focus tab shows; may differ from the live run's mode.
    @Published var shownMode: FocusRun.Mode = .pomodoro
    /// Starting `shownMode` would replace the live run: ask first.
    @Published var confirmingSwitch = false
    @Published private(set) var pulse = TomatoPulse()
    @Published private(set) var todayTally = 0

    private var endTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var started = false

    private init() {}

    // MARK: - What the notch shows

    /// A Pomodoro interval or Timer is running, paused, waiting or flashing.
    var isActive: Bool { started && run != nil }

    /// Focus sessions and Timers win the Wings; during a running break music
    /// takes them back and only the Progress line stays.
    var wingsPriority: WingsPriority {
        guard started, let run else { return .none }
        if run.mode == .pomodoro && run.isBreak && run.state == .running { return .low }
        return .high
    }

    var showsProgressLine: Bool {
        guard started, let run else { return false }
        return run.state == .running || run.state == .paused
    }

    var tint: Color { Self.tint(for: run?.phase ?? .focus, mode: run?.mode ?? shownMode) }

    static func tint(for phase: FocusRun.Phase, mode: FocusRun.Mode) -> Color {
        if mode == .timer { return Color(red: 0.48, green: 0.72, blue: 1.0) }
        switch phase {
        case .focus: return Color(red: 1.0, green: 0.36, blue: 0.30)
        case .shortBreak: return Color(red: 0.30, green: 0.85, blue: 0.60)
        case .longBreak: return Color(red: 0.32, green: 0.78, blue: 0.95)
        }
    }

    // MARK: - Lifecycle

    func start() {
        guard !started else { return }
        started = true
        refreshTally()
        run = Defaults[.focusRun]
        if let run { shownMode = run.mode }
        reconcile()

        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reconcile() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshTally() }
        })
    }

    func stop() {
        guard started else { return }
        started = false
        endTask?.cancel()
        endTask = nil
        observers.forEach {
            NSWorkspace.shared.notificationCenter.removeObserver($0)
            NotificationCenter.default.removeObserver($0)
        }
        observers.removeAll()
        objectWillChange.send()
    }

    // MARK: - Pomodoro

    func startPomodoro() {
        guard replaceIfAllowed(with: .pomodoro) else { return }
        withMotion(Motion.bouncy) {
            run = FocusRun(mode: .pomodoro, phase: .focus, duration: Self.length(of: .focus), endDate: nil)
            beginInterval()
        }
        pulse = TomatoPulse(kind: .drop)
    }

    /// Starts the interval a waiting Pomodoro is ready for.
    func startNext() {
        guard var run, run.state == .waiting else { return }
        run.endedAt = nil
        self.run = run
        withMotion(Motion.bouncy) { beginInterval() }
        pulse = TomatoPulse(kind: run.isBreak ? .celebrate : .drop)
    }

    /// Ends the current interval early. A skipped Focus session does not count.
    func skip() {
        guard let run, run.mode == .pomodoro else { return }
        withMotion(Motion.smooth) { advancePomodoro(countSession: false, late: false, announce: false, from: run) }
    }

    // MARK: - Timer

    var timerSetting: TimeInterval {
        get { Defaults[.timerLastDuration] }
        set {
            Defaults[.timerLastDuration] = min(max(60, newValue), 24 * 3600)
            objectWillChange.send()
        }
    }

    func startTimer() {
        guard replaceIfAllowed(with: .timer) else { return }
        withMotion(Motion.bouncy) {
            run = FocusRun(mode: .timer, duration: timerSetting)
            beginInterval()
        }
    }

    func addMinute() {
        guard var run, run.mode == .timer, run.state == .running || run.state == .paused else { return }
        run.duration += 60
        if run.state == .running {
            run.endDate = run.endDate?.addingTimeInterval(60)
        } else {
            run.remainingWhenStopped = (run.remainingWhenStopped ?? 0) + 60
        }
        withMotion(Motion.smooth) { self.run = run }
        schedule()
    }

    // MARK: - Shared controls

    func pause() {
        guard var run, run.state == .running else { return }
        run.remainingWhenStopped = run.remaining(at: .now)
        run.endDate = nil
        run.state = .paused
        withMotion(Motion.smooth) { self.run = run }
        endTask?.cancel()
        pulse = TomatoPulse(kind: .yawn)
    }

    func resume() {
        guard var run, run.state == .paused else { return }
        run.endDate = Date.now.addingTimeInterval(run.remainingWhenStopped ?? run.duration)
        run.remainingWhenStopped = nil
        run.state = .running
        withMotion(Motion.bouncy) { self.run = run }
        schedule()
        pulse = TomatoPulse(kind: .wake)
    }

    func togglePause() {
        run?.state == .running ? pause() : resume()
    }

    /// Stops and forgets the live run (also dismisses a flashing Timer).
    func reset() {
        endTask?.cancel()
        withMotion(Motion.smooth) { run = nil }
        confirmingSwitch = false
        if let announcement = BoringViewCoordinator.shared.announcement,
           announcement.kind == .timer || announcement.kind == .focus {
            BoringViewCoordinator.shared.dismissAnnouncement(id: announcement.id)
        }
    }

    /// The user confirmed stopping the live run to start the other mode.
    func confirmSwitch() {
        confirmingSwitch = false
        reset()
        shownMode == .pomodoro ? startPomodoro() : startTimer()
    }

    // MARK: - Internals

    private static func length(of phase: FocusRun.Phase) -> TimeInterval {
        let minutes: Int
        switch phase {
        case .focus: minutes = Defaults[.pomodoroFocusMinutes]
        case .shortBreak: minutes = Defaults[.pomodoroShortBreakMinutes]
        case .longBreak: minutes = Defaults[.pomodoroLongBreakMinutes]
        }
        return TimeInterval(max(1, minutes) * 60)
    }

    /// False (and asks for confirmation) when another mode is live.
    private func replaceIfAllowed(with mode: FocusRun.Mode) -> Bool {
        if let run, run.mode != mode, run.state != .finished {
            withMotion(Motion.snappy) { confirmingSwitch = true }
            return false
        }
        if run != nil { reset() }
        return true
    }

    private func beginInterval() {
        guard var run else { return }
        let length = run.remainingWhenStopped ?? run.duration
        run.state = .running
        run.endDate = Date.now.addingTimeInterval(length)
        run.remainingWhenStopped = nil
        self.run = run
        schedule()
    }

    private func schedule() {
        endTask?.cancel()
        guard let end = run?.endDate, run?.state == .running else { return }
        let delay = max(0, end.timeIntervalSinceNow)
        endTask = Task { [weak self] in
            // ContinuousClock keeps counting through sleep; `reconcile` also runs on wake.
            try? await Task.sleep(for: .seconds(delay), clock: .continuous)
            guard !Task.isCancelled else { return }
            self?.reconcile()
        }
    }

    /// Brings the run up to date with the real clock.
    private func reconcile() {
        guard started, let run, run.state == .running, let end = run.endDate else { return }
        guard end <= .now else { schedule(); return }
        // More than a minute late means the Mac slept or the app was closed.
        let late = Date.now.timeIntervalSince(end) > 60
        complete(run, endedAt: end, late: late)
    }

    private func complete(_ run: FocusRun, endedAt: Date, late: Bool) {
        switch run.mode {
        case .timer:
            var finished = run
            finished.state = .finished
            finished.endDate = nil
            finished.endedAt = late ? endedAt : nil
            withMotion(Motion.bouncy) { self.run = finished }
            if !late {
                chime()
                BoringViewCoordinator.shared.announce(NotchAnnouncement(
                    kind: .timer,
                    title: String(localized: "Time's up"),
                    subtitle: String(localized: "\(Int(run.duration / 60)) min timer"),
                    symbol: "timer",
                    tint: Self.tint(for: .focus, mode: .timer),
                    opensTab: .focus,
                    duration: nil
                ))
            }
        case .pomodoro:
            withMotion(Motion.bouncy) {
                advancePomodoro(countSession: run.phase == .focus, late: late, announce: !late, from: run, endedAt: endedAt)
            }
        }
    }

    private func advancePomodoro(countSession: Bool, late: Bool, announce: Bool, from run: FocusRun, endedAt: Date? = nil) {
        endTask?.cancel()
        var next = run
        next.endedAt = late ? endedAt : nil
        next.endDate = nil
        let autoStart: Bool

        if run.phase == .focus {
            if countSession {
                next.completedInCycle += 1
                addTally(on: endedAt ?? .now)
            }
            let longDue = next.completedInCycle >= max(1, Defaults[.pomodoroSessionsBeforeLongBreak])
            next.phase = longDue ? .longBreak : .shortBreak
            autoStart = Defaults[.pomodoroAutoStartBreaks]
        } else {
            if run.phase == .longBreak { next.completedInCycle = 0 }
            next.phase = .focus
            autoStart = Defaults[.pomodoroAutoStartFocus]
        }
        next.duration = Self.length(of: next.phase)
        next.remainingWhenStopped = next.duration
        next.state = .waiting
        self.run = next

        if autoStart && !late {
            beginInterval()
        }

        guard announce else { return }
        chime()
        let minutes = Int(next.duration / 60)
        if run.phase == .focus {
            pulse = TomatoPulse(kind: .celebrate)
            BoringViewCoordinator.shared.announce(NotchAnnouncement(
                kind: .focus,
                title: String(localized: "Focus session done"),
                subtitle: next.phase == .longBreak
                    ? String(localized: "Long break: \(minutes) min")
                    : String(localized: "Short break: \(minutes) min"),
                emoji: "🍅",
                tint: Self.tint(for: next.phase, mode: .pomodoro),
                celebrates: true,
                opensTab: .focus,
                duration: 5
            ))
        } else {
            BoringViewCoordinator.shared.announce(NotchAnnouncement(
                kind: .focus,
                title: String(localized: "Break's over"),
                subtitle: String(localized: "Ready for \(minutes) min of focus?"),
                emoji: "🍅",
                tint: Self.tint(for: .focus, mode: .pomodoro),
                opensTab: .focus,
                duration: 5
            ))
        }
    }

    private func chime() {
        guard Defaults[.focusChime] else { return }
        NSSound(named: "Glass")?.play()
    }

    // MARK: - Daily tally

    private func refreshTally() {
        if let day = Defaults[.focusTallyDate], Calendar.current.isDateInToday(day) {
            todayTally = Defaults[.focusTallyCount]
        } else {
            todayTally = 0
        }
    }

    private func addTally(on date: Date) {
        guard Calendar.current.isDateInToday(date) else { return }
        refreshTally()
        Defaults[.focusTallyDate] = .now
        Defaults[.focusTallyCount] = todayTally + 1
        withMotion(Motion.bouncy) { todayTally += 1 }
    }
}
