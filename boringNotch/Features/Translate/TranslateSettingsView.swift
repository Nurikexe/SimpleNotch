//
//  TranslateSettingsView.swift
//  SimpleNotch
//

import Defaults
import KeyboardShortcuts
import SwiftUI
import Translation

struct TranslateSettingsView: View {
    @ObservedObject private var manager = TranslateManager.shared
    @State private var downloadConfig: TranslationSession.Configuration?
    @State private var accessibilityTrusted = AccessibilityPermission.shared.isTrusted

    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Translate selection:", name: .translateSelection)
                if !accessibilityTrusted {
                    HStack {
                        Text("Needs Accessibility access to copy the selected text.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Grant Access") {
                            AccessibilityPermission.shared.requestAccessibilityAuthorization()
                        }
                    }
                }
            } header: {
                Text("Shortcut")
            } footer: {
                Text("Select text in any app and press the shortcut to translate it in the notch.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                HStack {
                    Text("English and Russian")
                    Spacer()
                    packStatus
                }
                if manager.packStatus == .needsDownload {
                    Button("Download Languages") { requestDownload() }
                }
            } header: {
                Text("Offline languages")
            } footer: {
                Text("Translation runs entirely on this Mac once the languages are downloaded.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section {
                Defaults.Toggle(key: .translateClearOnClose) {
                    Text("Clear input when notch closes")
                }
            }
        }
        .formStyle(.grouped)
        .accentColor(.effectiveAccent)
        .navigationTitle("Translate")
        .languagePackDownloader($downloadConfig)
        .task {
            await manager.refreshPackStatus()
            startRequestedDownload()
        }
        .onChange(of: manager.downloadRequested) { _, _ in startRequestedDownload() }
        .onReceive(NotificationCenter.default.publisher(for: .accessibilityAuthorizationChanged)) { _ in
            accessibilityTrusted = AccessibilityPermission.shared.isTrusted
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityTrusted = AccessibilityPermission.shared.isTrusted
            Task { await manager.refreshPackStatus() }
        }
    }

    @ViewBuilder
    private var packStatus: some View {
        Group {
            switch manager.packStatus {
            case .installed:
                Label("Downloaded", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .needsDownload:
                Label("Not downloaded", systemImage: "arrow.down.circle")
                    .foregroundStyle(.secondary)
            case .unsupported:
                Label("Not available", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            case .unknown:
                ProgressView().controlSize(.small)
            }
        }
        .labelStyle(.titleAndIcon)
        .contentTransition(.symbolEffect(.replace))
        .animation(Motion.respecting(Motion.snappy), value: manager.packStatus)
    }

    /// The notch's Download button sends the user here to download.
    private func startRequestedDownload() {
        guard manager.downloadRequested else { return }
        manager.downloadRequested = false
        if manager.packStatus != .installed { requestDownload() }
    }

    private func requestDownload() {
        if var config = downloadConfig {
            config.invalidate()
            downloadConfig = config
        } else {
            downloadConfig = .init(source: TranslateLanguage.english.language, target: TranslateLanguage.russian.language)
        }
    }
}
