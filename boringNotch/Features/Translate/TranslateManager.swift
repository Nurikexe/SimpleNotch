//
//  TranslateManager.swift
//  SimpleNotch
//
//  The Translate tab's shared state: the input, the direction (chosen from the
//  script of the input unless the user flips it), the latest translation and
//  the state of the offline language packs. Lives outside the view so the
//  ⌃⌥T shortcut can fill it while the notch is closed.
//

import AppKit
import Defaults
import KeyboardShortcuts
import SwiftUI
import Translation

// MARK: - Keys

extension Defaults.Keys {
    static let translateClearOnClose = Key<Bool>("translateClearOnClose", default: false)
}

extension KeyboardShortcuts.Name {
    static let translateSelection = Self("translateSelection", default: .init(.t, modifiers: [.control, .option]))
}

// MARK: - Languages

enum TranslateLanguage: String, Identifiable, Hashable {
    case english = "en"
    case russian = "ru"

    var id: String { rawValue }
    var code: String { rawValue.uppercased() }
    var language: Locale.Language { Locale.Language(identifier: rawValue) }
}

struct TranslateDirection: Equatable {
    let source: TranslateLanguage
    let target: TranslateLanguage

    static let englishToRussian = TranslateDirection(source: .english, target: .russian)
    static let russianToEnglish = TranslateDirection(source: .russian, target: .english)

    var flipped: TranslateDirection { TranslateDirection(source: target, target: source) }

    /// Cyrillic → English, otherwise → Russian. "Mostly" means at least half
    /// of the letters are Cyrillic, so a Russian sentence with a brand name in
    /// Latin letters still reads as Russian.
    static func detect(from text: String) -> TranslateDirection {
        var cyrillic = 0
        var letters = 0
        for scalar in text.unicodeScalars where scalar.properties.isAlphabetic {
            letters += 1
            if (0x0400...0x052F).contains(scalar.value) { cyrillic += 1 }
        }
        guard letters > 0 else { return .englishToRussian }
        return cyrillic * 2 >= letters ? .russianToEnglish : .englishToRussian
    }
}

// MARK: - Manager

@MainActor
final class TranslateManager: ObservableObject, NotchFeature {
    static let shared = TranslateManager()
    var enabledKey: Defaults.Key<Bool> { .tabTranslateEnabled }

    enum PackStatus: Equatable {
        case unknown
        case installed
        case needsDownload
        case unsupported
    }

    /// What the user typed or pasted (or what ⌃⌥T captured).
    @Published var input: String = "" {
        didSet { inputDidChange(from: oldValue) }
    }
    /// Set by ⇄; holds until the input is cleared.
    @Published private(set) var directionOverride: TranslateDirection?
    @Published private(set) var output: String = ""
    /// Bumped on every new result so the output cross-fades even when only a
    /// word changes.
    @Published private(set) var outputRevision = 0
    @Published private(set) var isTranslating = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var packStatus: PackStatus = .unknown
    /// Drives `.translationTask` in the tab. Replaced when the direction
    /// changes, invalidated to translate again in the same direction.
    @Published private(set) var configuration: TranslationSession.Configuration?

    var direction: TranslateDirection { directionOverride ?? .detect(from: input) }
    var hasInput: Bool { !trimmedInput.isEmpty }

    private var trimmedInput: String { input.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var debounceTask: Task<Void, Never>?
    private var runID = 0
    private var shortcutRegistered = false
    private var isRunning = false

    private init() {}

    // MARK: Lifecycle

    func start() {
        if !shortcutRegistered {
            shortcutRegistered = true
            KeyboardShortcuts.onKeyDown(for: .translateSelection) {
                Task { @MainActor in TranslateManager.shared.translateSelection() }
            }
        }
        KeyboardShortcuts.enable(.translateSelection)
        isRunning = true
        Task { await refreshPackStatus() }
    }

    func stop() {
        KeyboardShortcuts.disable(.translateSelection)
        isRunning = false
        debounceTask?.cancel()
        debounceTask = nil
    }

    // MARK: Input

    func clear() {
        input = ""
    }

    func swapDirection() {
        withMotion(Motion.snappy) {
            directionOverride = direction.flipped
        }
        if hasInput { scheduleTranslation(after: .zero) }
    }

    /// Replaces the input and translates at once, without the typing debounce.
    func setInputAndTranslate(_ text: String) {
        directionOverride = nil
        input = text
        scheduleTranslation(after: .zero)
    }

    private func inputDidChange(from oldValue: String) {
        guard input != oldValue else { return }
        if trimmedInput.isEmpty {
            debounceTask?.cancel()
            runID += 1
            withMotion(Motion.smooth) {
                directionOverride = nil
                output = ""
                errorMessage = nil
                isTranslating = false
            }
            return
        }
        scheduleTranslation(after: .milliseconds(350))
    }

    /// Re-runs the current input, e.g. after the language packs arrive.
    func retranslate() {
        guard hasInput else { return }
        scheduleTranslation(after: .zero)
    }

    private func scheduleTranslation(after delay: Duration) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
                if Task.isCancelled { return }
            }
            await self?.requestTranslation()
        }
    }

    /// Hands the work to the tab's `.translationTask` by changing its
    /// configuration. Only runs when the packs are installed, so the
    /// framework never pops its download sheet unasked.
    private func requestTranslation() async {
        guard hasInput else { return }
        await refreshPackStatus()
        guard packStatus == .installed, hasInput else { return }

        let dir = direction
        if var config = configuration,
           config.source == dir.source.language,
           config.target == dir.target.language {
            config.invalidate()
            configuration = config
        } else {
            configuration = TranslationSession.Configuration(
                source: dir.source.language,
                target: dir.target.language
            )
        }
    }

    // MARK: Translation

    /// Called from `.translationTask` with a session for `configuration`.
    func run(_ session: TranslationSession) async {
        let text = trimmedInput
        guard !text.isEmpty else { return }

        // The session was made for an older direction; a fresh one is coming.
        let dir = direction
        guard configuration?.source == dir.source.language,
              configuration?.target == dir.target.language else {
            scheduleTranslation(after: .zero)
            return
        }

        runID += 1
        let id = runID
        isTranslating = true
        defer { if id == runID { isTranslating = false } }

        do {
            let response = try await session.translate(text)
            // The input moved on while we waited; its own run will follow.
            guard id == runID, text == trimmedInput else { return }
            withMotion(Motion.smooth) {
                output = response.targetText
                outputRevision += 1
                errorMessage = nil
            }
        } catch is CancellationError {
            return
        } catch {
            guard id == runID else { return }
            await refreshPackStatus()
            guard packStatus == .installed else { return }
            withMotion(Motion.smooth) {
                errorMessage = Self.message(for: error)
            }
        }
    }

    private static func message(for error: Error) -> String {
        if TranslationError.unableToIdentifyLanguage ~= error {
            return String(localized: "Couldn't recognise the language of this text.")
        }
        if TranslationError.nothingToTranslate ~= error {
            return String(localized: "There's nothing to translate.")
        }
        if TranslationError.unsupportedLanguagePairing ~= error
            || TranslationError.unsupportedSourceLanguage ~= error
            || TranslationError.unsupportedTargetLanguage ~= error {
            return String(localized: "This language pair isn't supported on this Mac.")
        }
        return String(localized: "Couldn't translate this text. Try again.")
    }

    // MARK: Language packs

    func refreshPackStatus() async {
        let dir = direction
        let status = await LanguageAvailability().status(from: dir.source.language, to: dir.target.language)
        let newStatus: PackStatus
        switch status {
        case .installed: newStatus = .installed
        case .supported: newStatus = .needsDownload
        case .unsupported: newStatus = .unsupported
        @unknown default: newStatus = .unsupported
        }
        guard newStatus != packStatus else { return }
        withMotion(Motion.smooth) { packStatus = newStatus }
    }

    /// Called after `prepareTranslation()` returns (or fails).
    func packDownloadFinished(error: Error?) async {
        await refreshPackStatus()
        if packStatus == .installed {
            errorMessage = nil
            retranslate()
        } else if let error, !(error is CancellationError) {
            withMotion(Motion.smooth) {
                errorMessage = String(localized: "The download didn't finish. Try again.")
            }
        }
    }

    // MARK: ⌃⌥T

    /// Copies the selection in the frontmost app, puts the pasteboard back as
    /// it was, and opens the Translate tab with the captured text.
    func translateSelection() {
        guard isRunning else { return }
        guard AccessibilityPermission.shared.isTrusted else {
            AccessibilityPermission.shared.requestAccessibilityAuthorization()
            NotchRouter.shared.open(.translate, pinned: true, keyboard: false)
            return
        }

        let pasteboard = NSPasteboard.general
        let saved = PasteboardSnapshot(of: pasteboard)
        let before = pasteboard.changeCount
        ClipboardManager.shared.ignoreChanges(for: 1.0)
        SelectionCopier.postCopy()

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard let self else { return }
            var captured: String?
            if pasteboard.changeCount != before {
                captured = pasteboard.string(forType: .string)
                saved.restore(to: pasteboard)
            }
            NotchRouter.shared.open(.translate, pinned: true, keyboard: false)
            if let captured, !captured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.setInputAndTranslate(captured)
            }
        }
    }
}
