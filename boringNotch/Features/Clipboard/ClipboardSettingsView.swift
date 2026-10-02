//
//  ClipboardSettingsView.swift
//  SimpleNotch
//

import KeyboardShortcuts
import SwiftUI

struct ClipboardSettingsView: View {
    @ObservedObject private var manager = ClipboardManager.shared
    @State private var confirmingClear = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Clips") {
                    Text("\(manager.recentClips.count) of \(ClipboardManager.historyLimit)")
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(Motion.respecting(Motion.snappy), value: manager.recentClips.count)
                }
                Button("Clear history", role: .destructive) {
                    confirmingClear = true
                }
                .disabled(manager.recentClips.isEmpty)
            } header: {
                Text("History")
            } footer: {
                Text("The Clipboard history keeps your last 50 clips across restarts. Pinned clips are kept in addition and are never cleared.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                KeyboardShortcuts.Recorder("Open clipboard", name: .openClipboard)
            } header: {
                Text("Shortcut")
            } footer: {
                Text("While the Clipboard is open from the keyboard, type to search, use ↑ and ↓ to choose, Return to paste and ⌥Return to copy only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Label("Ignore concealed items", systemImage: "lock.shield")
            } footer: {
                Text("Content that password managers and other apps mark as concealed or transient is never saved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .accentColor(.effectiveAccent)
        .navigationTitle("Clipboard")
        .onAppear { manager.loadIfNeeded() }
        .confirmationDialog("Clear clipboard history?", isPresented: $confirmingClear) {
            Button("Clear history", role: .destructive) {
                manager.clearHistory()
            }
        } message: {
            Text("Pinned clips are kept.")
        }
    }
}
