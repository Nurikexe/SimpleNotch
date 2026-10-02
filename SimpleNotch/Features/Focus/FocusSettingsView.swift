//
//  FocusSettingsView.swift
//  SimpleNotch
//

import Defaults
import SwiftUI

struct FocusSettingsView: View {
    @Default(.pomodoroFocusMinutes) private var focusMinutes
    @Default(.pomodoroShortBreakMinutes) private var shortBreakMinutes
    @Default(.pomodoroLongBreakMinutes) private var longBreakMinutes
    @Default(.pomodoroSessionsBeforeLongBreak) private var sessions

    var body: some View {
        Form {
            Section {
                Stepper(value: $focusMinutes, in: 1...120) {
                    row("Focus session", "\(focusMinutes) min")
                }
                Stepper(value: $shortBreakMinutes, in: 1...60) {
                    row("Short break", "\(shortBreakMinutes) min")
                }
                Stepper(value: $longBreakMinutes, in: 1...90) {
                    row("Long break", "\(longBreakMinutes) min")
                }
                Stepper(value: $sessions, in: 1...12) {
                    row("Long break after", "\(sessions) sessions")
                }
                Button("Restore 25 / 5 / 15") {
                    focusMinutes = 25
                    shortBreakMinutes = 5
                    longBreakMinutes = 15
                    sessions = 4
                }
            } header: {
                Text("Pomodoro")
            } footer: {
                Text("Changes apply from the next interval.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                Defaults.Toggle(key: .pomodoroAutoStartBreaks) {
                    Text("Start breaks automatically")
                }
                Defaults.Toggle(key: .pomodoroAutoStartFocus) {
                    Text("Start focus sessions automatically")
                }
                Defaults.Toggle(key: .focusChime) {
                    Text("Play a chime when an interval ends")
                }
            } header: {
                Text("Behaviour")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Focus")
    }

    private func row(_ title: LocalizedStringKey, _ value: LocalizedStringKey) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
