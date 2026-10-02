//
//  FocusRun.swift
//  SimpleNotch
//
//  The state of the one Pomodoro or Timer that may be live at a time. It is
//  measured against the real clock (an end date, never a tick count), so it
//  stays right across sleep and restarts.
//

import Defaults
import Foundation

struct FocusRun: Codable, Equatable, Defaults.Serializable {
    enum Mode: String, Codable { case pomodoro, timer }
    enum Phase: String, Codable { case focus, shortBreak, longBreak }
    enum State: String, Codable {
        case running
        case paused
        /// Pomodoro: the next interval is ready and waits for a click.
        case waiting
        /// Timer: it has ended and the ring flashes until dismissed.
        case finished
    }

    var mode: Mode
    var phase: Phase = .focus
    var state: State = .running
    /// Length of the current interval.
    var duration: TimeInterval
    /// When the current interval ends; set only while running.
    var endDate: Date?
    /// Time left when paused (or the full length while waiting).
    var remainingWhenStopped: TimeInterval?
    /// Focus sessions completed since the last Long break.
    var completedInCycle = 0
    /// Set when the previous interval ended while the Mac slept or the app was
    /// closed, so the UI can say "ended N min ago".
    var endedAt: Date?

    var isBreak: Bool { phase != .focus }

    func remaining(at now: Date) -> TimeInterval {
        switch state {
        case .running: max(0, (endDate ?? now).timeIntervalSince(now))
        case .paused, .waiting: remainingWhenStopped ?? duration
        case .finished: 0
        }
    }

    /// 0 at the start of the interval, 1 at its end.
    func progress(at now: Date) -> Double {
        guard duration > 0 else { return 0 }
        if state == .waiting { return 0 }
        return min(1, max(0, 1 - remaining(at: now) / duration))
    }
}

enum FocusFormat {
    /// "18:42", or "1:05:00" past an hour. Rounds up so a fresh 25:00 never shows 24:59.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    /// Parses "5", "5:30" or "1:05:00" into seconds.
    static func parse(_ text: String) -> TimeInterval? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":").map { Int($0) }
        guard !parts.isEmpty, parts.count <= 3, parts.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        let values = parts.compactMap { $0 }
        let seconds: Int
        switch values.count {
        case 1: seconds = values[0] * 60
        case 2: seconds = values[0] * 60 + values[1]
        default: seconds = values[0] * 3600 + values[1] * 60 + values[2]
        }
        return seconds > 0 ? TimeInterval(min(seconds, 24 * 3600)) : nil
    }
}

extension Defaults.Keys {
    static let pomodoroFocusMinutes = Key<Int>("pomodoroFocusMinutes", default: 25)
    static let pomodoroShortBreakMinutes = Key<Int>("pomodoroShortBreakMinutes", default: 5)
    static let pomodoroLongBreakMinutes = Key<Int>("pomodoroLongBreakMinutes", default: 15)
    static let pomodoroSessionsBeforeLongBreak = Key<Int>("pomodoroSessionsBeforeLongBreak", default: 4)
    static let pomodoroAutoStartBreaks = Key<Bool>("pomodoroAutoStartBreaks", default: true)
    static let pomodoroAutoStartFocus = Key<Bool>("pomodoroAutoStartFocus", default: false)
    static let focusChime = Key<Bool>("focusChime", default: true)
    static let timerLastDuration = Key<Double>("timerLastDuration", default: 5 * 60)

    static let focusRun = Key<FocusRun?>("focusRun", default: nil)
    static let focusTallyDate = Key<Date?>("focusTallyDate", default: nil)
    static let focusTallyCount = Key<Int>("focusTallyCount", default: 0)
}
