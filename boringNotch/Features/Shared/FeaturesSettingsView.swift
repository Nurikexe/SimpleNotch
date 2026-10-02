//
//  FeaturesSettingsView.swift
//  SimpleNotch
//
//  One switch per Tab and background feature. Turning one off hides it and
//  stops its background work.
//

import Defaults
import SwiftUI

struct FeaturesSettingsView: View {
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .tabHomeEnabled) { Label("Home", systemImage: "house.fill") }
                Defaults.Toggle(key: .boringShelf) { Label("Shelf", systemImage: "tray.fill") }
                Defaults.Toggle(key: .tabClipboardEnabled) { Label("Clipboard", systemImage: "doc.on.clipboard.fill") }
                Defaults.Toggle(key: .tabFocusEnabled) { Label("Focus", systemImage: "timer") }
                Defaults.Toggle(key: .tabTranslateEnabled) { Label("Translate", systemImage: "character.bubble.fill") }
                Defaults.Toggle(key: .tabBirthdaysEnabled) { Label("Birthdays", systemImage: "gift.fill") }
            } header: {
                Text("Tabs")
            } footer: {
                Text("A Tab that is off disappears from the notch and stops all its background work.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            Section {
                Defaults.Toggle(key: .windowSnappingEnabled) { Label("Window snapping", systemImage: "rectangle.split.2x1.fill") }
                Defaults.Toggle(key: .downloadIndicatorEnabled) { Label("Download indicator", systemImage: "arrow.down.circle.fill") }
            } header: {
                Text("Background features")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Features")
    }
}
