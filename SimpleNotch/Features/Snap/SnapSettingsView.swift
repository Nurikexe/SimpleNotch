//
//  SnapSettingsView.swift
//  SimpleNotch
//

import Defaults
import KeyboardShortcuts
import SwiftUI

struct SnapSettingsView: View {
    @Default(.snapGap) private var gap
    @State private var isTrusted = AccessibilityPermission.shared.isTrusted

    var body: some View {
        Form {
            Section {
                HStack {
                    Slider(value: $gap, in: 0 ... 20, step: 1) {
                        Text("Gap between windows")
                    }
                    Text("\(Int(gap)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                        .contentTransition(.numericText(value: gap))
                        .animation(Motion.respecting(Motion.snappy), value: gap)
                }
            } header: {
                Text("Layouts")
            } footer: {
                Text("Drag a window towards the notch to open the Snap grid, then drop it on a layout.")
            }

            Section {
                ForEach(SnapLayout.allCases) { layout in
                    KeyboardShortcuts.Recorder(layout.title, name: layout.shortcutName)
                }
            } header: {
                Text("Keyboard shortcuts")
            } footer: {
                Text("Shortcuts act on the focused window. Right two-thirds has no shortcut by default because ⌃⌥T opens Translate.")
            }

            Section {
                HStack(spacing: 8) {
                    Image(systemName: isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(isTrusted ? .green : .orange)
                        .contentTransition(.symbolEffect(.replace))
                    if isTrusted {
                        Text("Accessibility access granted")
                    } else {
                        Text("Accessibility access is needed to move windows")
                    }
                    Spacer()
                    if !isTrusted {
                        Button("Grant Access") {
                            AccessibilityPermission.shared.requestAccessibilityAuthorization()
                        }
                        .transition(.softPop)
                    }
                }
            } header: {
                Text("Permissions")
            }
        }
        .formStyle(.grouped)
        .task {
            // Poll only while this page is visible, so a grant made in System
            // Settings shows up without reopening the window.
            while !Task.isCancelled {
                let trusted = AccessibilityPermission.shared.isTrusted
                if trusted != isTrusted {
                    withMotion(Motion.snappy) { isTrusted = trusted }
                }
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }
}
