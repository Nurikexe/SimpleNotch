//
//  TranslateTabView.swift
//  SimpleNotch
//
//  The Translate tab: input on the left, translation on the right, the
//  direction as two small chips that trade places when flipped.
//

import AppKit
import Defaults
import SwiftUI
import Translation

struct TranslateTabView: View {
    @EnvironmentObject var vm: NotchViewModel
    @ObservedObject private var manager = TranslateManager.shared
    @Default(.translateClearOnClose) private var clearOnClose

    @FocusState private var inputFocused: Bool
    @State private var pinnedForEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            toolbar
            HStack(spacing: 8) {
                inputCard
                outputCard
            }
        }
        .padding(.top, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .translationTask(manager.configuration) { session in
            await manager.run(session)
        }
        .onAppear {
            Task { await manager.refreshPackStatus() }
        }
        .onDisappear {
            inputFocused = false
            if vm.notchState == .closed && clearOnClose {
                manager.clear()
            }
        }
        .onChange(of: inputFocused) { _, focused in
            if focused {
                beginEditing()
            } else if pinnedForEditing {
                pinnedForEditing = false
                vm.pinnedOpen = false
            }
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            DirectionChips(direction: manager.direction)

            SwapButton { manager.swapDirection() }

            Spacer(minLength: 0)

            if manager.hasInput {
                Button {
                    withMotion(Motion.snappy) { manager.clear() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                        .frame(width: 22, height: 22)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Clear")
                .transition(.softPop)
            }
        }
        .frame(height: 22)
        .animation(Motion.respecting(Motion.snappy), value: manager.hasInput)
    }

    // MARK: Input

    private var inputCard: some View {
        TextField("Type or paste…", text: $manager.input, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(.white)
            .lineLimit(1...7)
            .focused($inputFocused)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(inputFocused ? 0.1 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(inputFocused ? 0.12 : 0), lineWidth: 1)
            )
            .animation(Motion.respecting(Motion.snappy), value: inputFocused)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .simultaneousGesture(TapGesture().onEnded { beginEditing() })
    }

    /// The notch panel only becomes key during a keyboard session, which a
    /// TextField needs; pinning keeps it open if the pointer drifts away.
    private func beginEditing() {
        if !pinnedForEditing || !vm.pinnedOpen {
            pinnedForEditing = true
            vm.pinnedOpen = true
        }
        vm.beginKeyboardSession()
        if !inputFocused {
            Task { @MainActor in inputFocused = true }
        }
    }

    // MARK: Output

    @ViewBuilder
    private var outputCard: some View {
        ZStack {
            switch manager.packStatus {
            case .needsDownload:
                DownloadPacksCard { requestDownload() }
                    .transition(.notchContent)
            case .unsupported:
                OutputMessage(symbol: "exclamationmark.triangle", text: "Translation between English and Russian isn't available on this Mac.")
                    .transition(.notchContent)
            case .installed, .unknown:
                TranslationOutput(manager: manager)
                    .transition(.notchContent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(Motion.respecting(Motion.smooth), value: manager.packStatus)
    }

    private func requestDownload() {
        // The framework's download sheet must attach to a regular window; the
        // notch panel isn't one. Hand off to the Translate page in Settings.
        manager.downloadRequested = true
        withMotion(Motion.notchClose) { vm.close() }
        DispatchQueue.main.async {
            SettingsWindowController.shared.showWindow(page: "Translate")
        }
    }
}

// MARK: - Direction chips

private struct DirectionChips: View {
    let direction: TranslateDirection
    @Namespace private var chips
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            chip(direction.source, slot: 0)
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.gray)
            chip(direction.target, slot: 1)
        }
        .animation(Motion.respecting(Motion.snappy), value: direction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(direction == .englishToRussian ? Text("English to Russian") : Text("Russian to English"))
    }

    /// Each chip is matched by language, so on a flip the EN chip travels to
    /// where RU was and back. With Reduce Motion they stay put and cross-fade.
    private func chip(_ language: TranslateLanguage, slot: Int) -> some View {
        Text(language.code)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .contentTransition(.opacity)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(0.1)))
            .matchedGeometryEffect(id: reduceMotion ? "slot\(slot)" : language.id, in: chips)
    }
}

private struct SwapButton: View {
    let action: () -> Void
    @State private var flips = 0

    var body: some View {
        Button {
            flips += 1
            action()
        } label: {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.gray)
                .symbolEffect(.bounce, value: flips)
                .frame(width: 24, height: 22)
                .background(Capsule().fill(Color.white.opacity(0.06)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Swap languages")
    }
}

// MARK: - Output contents

private struct TranslationOutput: View {
    @ObservedObject var manager: TranslateManager
    @State private var copied = false
    @State private var copies = 0
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    if let error = manager.errorMessage {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(.orange.opacity(0.9))
                            .transition(.softPop)
                    } else if manager.output.isEmpty {
                        Text("Translation")
                            .font(.system(size: 13))
                            .foregroundStyle(.gray.opacity(0.7))
                            .transition(.opacity)
                    } else {
                        Text(manager.output)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .id(manager.outputRevision)
                            .transition(.resultCrossFade)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(10)
                .padding(.trailing, 18)
            }
            .notchScrollRegion()
            .modifier(TranslatingPulse(active: manager.isTranslating))

            if !manager.output.isEmpty && manager.errorMessage == nil {
                copyButton
                    .padding(6)
                    .transition(.softPop)
            }
        }
        .animation(Motion.respecting(Motion.snappy), value: manager.output.isEmpty)
    }

    private var copyButton: some View {
        Button(action: copy) {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(copied ? .green : .gray)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: copies)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.black.opacity(0.5)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Copy translation")
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(manager.output, forType: .string)
        copies += 1
        withMotion(Motion.snappy) { copied = true }
        resetTask?.cancel()
        resetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            withMotion(Motion.snappy) { copied = false }
        }
    }
}

private struct DownloadPacksCard: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.85))
            Text("Download English and Russian for offline translation")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Button(action: action) {
                Text("Download")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.14)))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct OutputMessage: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 16))
            Text(text)
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.gray)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Motion helpers

/// A soft opacity pulse on the output while a translation is in flight.
/// The timeline is paused (and costs nothing) the rest of the time.
private struct TranslatingPulse: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: nil, paused: !active || reduceMotion)) { context in
            content.opacity(opacity(at: context.date))
        }
        .animation(Motion.respecting(Motion.smooth), value: active)
    }

    private func opacity(at date: Date) -> Double {
        guard active else { return 1 }
        if reduceMotion { return 0.6 }
        let phase = date.timeIntervalSinceReferenceDate * (2 * .pi / 1.1)
        return 0.62 + 0.2 * cos(phase)
    }
}

private struct BlurEffect: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View { content.blur(radius: radius) }
}

extension AnyTransition {
    /// New results fade and sharpen in while the old one fades out in place.
    fileprivate static var resultCrossFade: AnyTransition {
        .opacity.combined(with: .modifier(active: BlurEffect(radius: 3), identity: BlurEffect(radius: 0)))
    }
}

// MARK: - Language pack download

extension View {
    /// Runs `prepareTranslation()` (the framework's download prompt) whenever
    /// `config` is set or invalidated, then refreshes the pack status.
    func languagePackDownloader(_ config: Binding<TranslationSession.Configuration?>) -> some View {
        translationTask(config.wrappedValue) { session in
            do {
                try await session.prepareTranslation()
                await TranslateManager.shared.packDownloadFinished(error: nil)
            } catch {
                await TranslateManager.shared.packDownloadFinished(error: error)
            }
        }
    }
}
