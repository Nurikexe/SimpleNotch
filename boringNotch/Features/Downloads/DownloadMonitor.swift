//
//  DownloadMonitor.swift
//  SimpleNotch
//
//  The Download indicator: watches ~/Downloads for in-progress browser
//  downloads and shows their progress in the Wings of the closed notch.
//
//  Two sources, merged per download:
//  - Published `Progress` objects. Safari and Chrome publish file progress for
//    the file they are writing; `Progress.addSubscriber(forFileURL:)` on the
//    Downloads folder hears every one of them, across processes.
//  - The folder itself. A DispatchSource on the directory fires when an
//    in-progress file (`.crdownload`, `.part`, `.download`) appears, is
//    renamed or disappears. A download with no published Progress (Firefox)
//    is shown as indeterminate while its file keeps growing.
//
//  Everything is event-driven. A light 1 s timer runs only while a download
//  without a Progress is live, to notice when it stalls. At rest nothing runs.
//

import AppKit
import Defaults
import SwiftUI

@MainActor
final class DownloadMonitor: ObservableObject, NotchFeature {
    static let shared = DownloadMonitor()
    var enabledKey: Defaults.Key<Bool> { .downloadIndicatorEnabled }

    /// Something is downloading right now (or just finished, for the
    /// checkmark moment before the Wings collapse).
    @Published private(set) var isActive = false
    /// Aggregate progress of every live download, 0...1; nil when no
    /// download publishes a known size.
    @Published private(set) var fraction: Double?
    /// Number of downloads in flight.
    @Published private(set) var count = 0
    /// The last download just finished: the Wings show a checkmark.
    @Published private(set) var didFinish = false

    /// File extensions browsers use while a download is in progress.
    static let inProgressExtensions: Set<String> = ["crdownload", "part", "download"]

    /// How long after its last write a download without a Progress still
    /// counts as live. Leftover `.crdownload` files from a crashed browser
    /// would otherwise keep the indicator up forever.
    nonisolated private static let staleAfter: TimeInterval = 20
    /// How long the checkmark stays in the Wings before they collapse.
    private static let finishLinger: Duration = .seconds(1.6)

    private final class Entry {
        let key: String
        var displayName: String
        /// The in-progress file or bundle on disk, if any.
        var diskURL: URL?
        var lastWrite: Date = .distantPast
        var progress: Progress?
        var progressObservation: NSKeyValueObservation?
        var progressPublished = false
        var progressFinished = false

        init(key: String, displayName: String) {
            self.key = key
            self.displayName = displayName
        }

        var isLive: Bool {
            if progressPublished { return true }
            guard diskURL != nil else { return false }
            return Date().timeIntervalSince(lastWrite) < DownloadMonitor.staleAfter
        }

        /// Completed and total units when the size is known.
        var units: (completed: Double, total: Double)? {
            guard progressPublished, let progress, !progress.isIndeterminate,
                  progress.totalUnitCount > 0 else { return nil }
            let total = Double(progress.totalUnitCount)
            return (min(Double(progress.completedUnitCount), total), total)
        }
    }

    private var downloadsURL: URL?
    private var directorySource: DispatchSourceFileSystemObject?
    private var subscriber: Any?
    private var staleTimer: Timer?
    private var entries: [String: Entry] = [:]
    private var refreshScheduled = false
    private var collapseTask: Task<Void, Never>?
    private var running = false

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard !running else { return }
        guard let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }
        running = true
        downloadsURL = url.resolvingSymlinksInPath()
        watchDirectory()
        subscribeToProgress()
        rescan()
    }

    func stop() {
        guard running else { return }
        running = false
        directorySource?.cancel()
        directorySource = nil
        if let subscriber { Progress.removeSubscriber(subscriber) }
        subscriber = nil
        staleTimer?.invalidate()
        staleTimer = nil
        collapseTask?.cancel()
        collapseTask = nil
        for entry in entries.values { entry.progressObservation?.invalidate() }
        entries.removeAll()
        fraction = nil
        count = 0
        didFinish = false
        if isActive {
            withMotion(Motion.notchClose) { isActive = false }
        }
    }

    // MARK: - Sources

    private func watchDirectory() {
        guard let downloadsURL else { return }
        let fd = open(downloadsURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .link],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.rescan() }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        directorySource = source
    }

    private func subscribeToProgress() {
        guard let downloadsURL else { return }
        // The handler runs off the main thread; hop over before touching state.
        subscriber = Progress.addSubscriber(forFileURL: downloadsURL) { progress in
            let box = UncheckedBox(progress)
            DispatchQueue.main.async {
                MainActor.assumeIsolated { DownloadMonitor.shared.progressPublished(box.value) }
            }
            return {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { DownloadMonitor.shared.progressUnpublished(box.value) }
                }
            }
        }
    }

    // MARK: - Progress

    private func progressPublished(_ progress: Progress) {
        guard running, Self.isDownload(progress) else { return }
        let url = progress.fileURL ?? progress.userInfo[.fileURLKey] as? URL
        let key = url.map(Self.key(for:)) ?? "progress-\(ObjectIdentifier(progress).hashValue)"
        let entry = entry(for: key, url: url)
        entry.progressObservation?.invalidate()
        entry.progress = progress
        entry.progressPublished = true
        entry.progressFinished = false
        entry.progressObservation = progress.observe(\.fractionCompleted, options: []) { _, _ in
            // KVO fires on the writer's thread, often per chunk: coalesce.
            DispatchQueue.main.async {
                MainActor.assumeIsolated { DownloadMonitor.shared.scheduleRefresh() }
            }
        }
        refresh()
    }

    private func progressUnpublished(_ progress: Progress) {
        guard let entry = entries.values.first(where: { $0.progress === progress }) else { return }
        entry.progressObservation?.invalidate()
        entry.progressObservation = nil
        entry.progressPublished = false
        entry.progressFinished = !progress.isCancelled
            && (progress.isFinished || progress.fractionCompleted >= 0.999)
        // The browser renames the file right around now; let the folder say
        // whether the download landed.
        rescan()
    }

    private static func isDownload(_ progress: Progress) -> Bool {
        guard let operation = progress.fileOperationKind else { return true }
        // Finder copies and Archive Utility unzips into Downloads publish too.
        if operation == .downloading || operation == .receiving { return true }
        return false
    }

    // MARK: - Folder

    private func rescan() {
        guard running, let downloadsURL else { return }
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var seen = Set<String>()
        for url in contents where Self.inProgressExtensions.contains(url.pathExtension.lowercased()) {
            let key = Self.key(for: url)
            seen.insert(key)
            let entry = entry(for: key, url: url)
            entry.diskURL = url
            entry.lastWrite = max(entry.lastWrite, Self.lastWrite(of: url))
        }

        // In-progress files that are gone: the download landed or was cancelled.
        for entry in entries.values where entry.diskURL != nil && !seen.contains(entry.key) {
            entry.diskURL = nil
        }

        refresh()
    }

    /// The newest modification date of a file, or of anything inside a
    /// `.download` bundle (Safari writes into a file within it).
    private static func lastWrite(of url: URL) -> Date {
        var newest = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? .distantPast
        if url.pathExtension.lowercased() == "download",
           let inner = try? FileManager.default.contentsOfDirectory(
               at: url, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for item in inner {
                if let date = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate {
                    newest = max(newest, date)
                }
            }
        }
        return newest
    }

    /// One key per download, whether it is seen as `photo.jpg.crdownload`,
    /// `photo.jpg.download` or a Progress for either.
    private static func key(for url: URL) -> String {
        var url = url.standardizedFileURL.resolvingSymlinksInPath()
        if inProgressExtensions.contains(url.pathExtension.lowercased()) {
            url.deletePathExtension()
        }
        return url.path
    }

    private func entry(for key: String, url: URL?) -> Entry {
        if let existing = entries[key] { return existing }
        let name = URL(fileURLWithPath: key).lastPathComponent
        let entry = Entry(key: key, displayName: url == nil ? "" : name)
        entries[key] = entry
        return entry
    }

    // MARK: - State

    private func scheduleRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.refreshScheduled = false
                self?.refresh()
            }
        }
    }

    private func refresh() {
        guard running else { return }
        rekeyLateProgress()

        // Downloads that are over: neither a published Progress nor a file.
        let ended = entries.values.filter { !$0.progressPublished && $0.diskURL == nil }
        var landed: [String] = []
        for entry in ended {
            entries[entry.key] = nil
            entry.progressObservation?.invalidate()
            if let name = landedName(of: entry) { landed.append(name) }
        }
        for name in landed { announce(fileName: name) }

        let live = entries.values.filter(\.isLive)
        updateStaleTimer()

        if live.isEmpty {
            count = 0
            guard isActive, collapseTask == nil else { return }
            if landed.isEmpty {
                // Cancelled or stalled: just go.
                collapse(after: .seconds(0.3))
            } else {
                withMotion(Motion.snappy) {
                    fraction = 1
                    didFinish = true
                }
                collapse(after: Self.finishLinger)
            }
            return
        }

        collapseTask?.cancel()
        collapseTask = nil
        let known = live.compactMap(\.units)
        let newFraction: Double? = known.isEmpty
            ? nil
            : known.reduce(0) { $0 + $1.completed } / known.reduce(0) { $0 + $1.total }

        if count != live.count { count = live.count }
        if didFinish { didFinish = false }
        if fraction != newFraction {
            fraction = newFraction
        }
        if !isActive {
            withMotion(Motion.notchOpen) { isActive = true }
        }
    }

    /// A Progress proxy can arrive before its userInfo (fileURL) does; once
    /// the URL shows up, fold it into the entry for that file.
    private func rekeyLateProgress() {
        for entry in entries.values where entry.key.hasPrefix("progress-") {
            guard let progress = entry.progress,
                  let url = progress.fileURL ?? progress.userInfo[.fileURLKey] as? URL else { continue }
            let key = Self.key(for: url)
            entries[entry.key] = nil
            let target = self.entry(for: key, url: url)
            target.progressObservation?.invalidate()
            target.progress = progress
            target.progressObservation = entry.progressObservation
            target.progressPublished = entry.progressPublished
            target.progressFinished = entry.progressFinished
        }
    }

    /// The name of the file a finished download produced, or nil if it was
    /// cancelled (its file is gone and its Progress did not complete).
    private func landedName(of entry: Entry) -> String? {
        // A leftover file the user deleted is not a finished download.
        let recentlyWritten = Date().timeIntervalSince(entry.lastWrite) < Self.staleAfter
        guard entry.progressFinished || (entry.progress == nil && recentlyWritten) else { return nil }
        let fm = FileManager.default
        if fm.fileExists(atPath: entry.key) {
            // Chrome's "Unconfirmed 1234.crdownload" never had a real name.
            let name = URL(fileURLWithPath: entry.key).lastPathComponent
            if !name.hasPrefix("Unconfirmed ") { return name }
        }
        // Fall back to whatever just appeared in Downloads.
        if let newest = newestRecentFile() { return newest }
        return entry.progressFinished ? entry.displayName : nil
    }

    private func newestRecentFile() -> String? {
        guard let downloadsURL else { return nil }
        let keys: [URLResourceKey] = [.addedToDirectoryDateKey, .contentModificationDateKey]
        let items = (try? FileManager.default.contentsOfDirectory(
            at: downloadsURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        let cutoff = Date().addingTimeInterval(-5)
        return items
            .filter { !Self.inProgressExtensions.contains($0.pathExtension.lowercased()) }
            .compactMap { url -> (URL, Date)? in
                let values = try? url.resourceValues(forKeys: Set(keys))
                guard let date = values?.contentModificationDate ?? values?.addedToDirectoryDate,
                      date > cutoff else { return nil }
                return (url, date)
            }
            .max { $0.1 < $1.1 }?
            .0.lastPathComponent
    }

    private func announce(fileName: String) {
        BoringViewCoordinator.shared.announce(NotchAnnouncement(
            kind: .download,
            title: "Downloaded",
            subtitle: fileName,
            symbol: "checkmark.circle.fill",
            tint: .green,
            opensTab: .shelf,
            duration: 3
        ))
    }

    private func collapse(after delay: Duration) {
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.collapseTask = nil
            withMotion(Motion.notchClose) { self.isActive = false }
            self.didFinish = false
            self.fraction = nil
        }
    }

    /// Runs only while a download without a Progress is live, so it can fall
    /// stale (and let the Wings go) when its file stops growing.
    private func updateStaleTimer() {
        let needsTimer = entries.values.contains { $0.isLive && !$0.progressPublished }
        if needsTimer, staleTimer == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.rescan() }
            }
            timer.tolerance = 0.3
            RunLoop.main.add(timer, forMode: .common)
            staleTimer = timer
        } else if !needsTimer, let timer = staleTimer {
            timer.invalidate()
            staleTimer = nil
        }
    }
}

/// Carries a non-Sendable reference across the hop to the main queue.
private struct UncheckedBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}

// MARK: - Wings

/// Closed-notch Wings content while a download is in progress: a progress
/// ring around a down arrow on the left, the percentage on the right.
struct DownloadWingsView: View {
    static let wingWidth: CGFloat = 44

    @ObservedObject private var monitor = DownloadMonitor.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NotchWings(wingWidth: Self.wingWidth) {
            DownloadRing(fraction: monitor.fraction, finished: monitor.didFinish)
                .padding(.leading, 6)
        } trailing: {
            trailing
                .padding(.trailing, 6)
        }
        .animation(Motion.respecting(Motion.smooth), value: monitor.fraction == nil)
        .animation(Motion.respecting(Motion.bouncy), value: monitor.didFinish)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var trailing: some View {
        ZStack(alignment: .trailing) {
            if monitor.didFinish {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.green)
                    .transition(.softPop)
            } else if let fraction = monitor.fraction {
                Text("\(Int((fraction * 100).rounded(.down)))%")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: fraction))
                    .animation(Motion.respecting(Motion.snappy), value: Int(fraction * 100))
                    .lineLimit(1)
                    .fixedSize()
                    .transition(.softPop)
            } else {
                IndeterminateArc(reduceMotion: reduceMotion)
                    .frame(width: 14, height: 14)
                    .transition(.softPop)
            }
        }
    }

    private var accessibilityText: Text {
        if monitor.didFinish { return Text("Download finished") }
        if let fraction = monitor.fraction {
            return Text("Downloading, \(Int(fraction * 100)) percent")
        }
        return Text("Downloading")
    }
}

/// The leading wing: a ring that fills with the download, around an arrow
/// that turns into a checkmark when it lands.
private struct DownloadRing: View {
    var fraction: Double?
    var finished: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 2.2)
            Circle()
                .trim(from: 0, to: max(0.001, fraction ?? 0))
                .stroke(
                    finished ? Color.green : Color.white,
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(fraction == nil ? 0 : 1)
                // A spring per update retargets with velocity, so frequent
                // progress ticks read as one continuous glide.
                .animation(Motion.respecting(.spring(response: 0.6, dampingFraction: 1)), value: fraction)
            Image(systemName: finished ? "checkmark" : "arrow.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(finished ? Color.green : Color.white)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: finished)
        }
        .frame(width: 20, height: 20)
    }
}

/// Shown when the size is unknown: an arc sweeping round, computed from the
/// clock so it never stutters. With Reduce Motion it breathes in place.
private struct IndeterminateArc: View {
    var reduceMotion: Bool

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(reduceMotion ? -90 : (t * 360 / 1.1).truncatingRemainder(dividingBy: 360)))
                    .opacity(reduceMotion ? 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 2 * .pi / 1.6)) : 1)
            }
        }
    }
}
