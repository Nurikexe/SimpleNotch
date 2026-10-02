//
//  BirthdaysSettingsView.swift
//  SimpleNotch
//

import Defaults
import SwiftUI

struct BirthdaysSettingsView: View {
    @Default(.birthdayReminderDays) private var reminderDays
    @ObservedObject private var store = BirthdayStore.shared

    var body: some View {
        Form {
            Section {
                Picker("Reminder", selection: $reminderDays) {
                    Text("Off").tag(0)
                    Text("1 day before").tag(1)
                    Text("3 days before").tag(3)
                    Text("7 days before").tag(7)
                }
            } footer: {
                Text("On the day itself the notch always celebrates. The reminder is a smaller heads-up before it.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Saved birthdays") {
                    Text("\(store.birthdays.count)")
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(Motion.respecting(Motion.snappy), value: store.birthdays.count)
                }
            } footer: {
                Text("Add, edit or remove birthdays from the Birthdays tab in the notch. Right-click a birthday to edit or delete it.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
