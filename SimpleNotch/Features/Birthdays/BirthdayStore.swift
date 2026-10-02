//
//  BirthdayStore.swift
//  SimpleNotch
//
//  Keeps the user's Birthdays on disk and announces today's Birthdays (and an
//  optional reminder N days before) with a Sneak peek. Checks happen on start,
//  at midnight and on wake only: no timers, so it costs nothing while idle.
//

import AppKit
import Defaults
import SwiftUI

extension Defaults.Keys {
    /// Days before a Birthday to show a reminder; 0 turns the reminder off.
    static let birthdayReminderDays = Key<Int>("birthdayReminderDays", default: 1)
    /// What has already been announced today, so restarts don't repeat it.
    static let birthdayAnnouncementLog = Key<BirthdayAnnouncementLog>(
        "birthdayAnnouncementLog", default: BirthdayAnnouncementLog(day: "", ids: [])
    )
}

/// The local day ("yyyy-MM-dd") plus the announcement ids shown on it.
struct BirthdayAnnouncementLog: Codable, Equatable, Defaults.Serializable {
    var day: String
    var ids: [String]
}

@MainActor
final class BirthdayStore: ObservableObject, NotchFeature {
    static let shared = BirthdayStore()
    var enabledKey: Defaults.Key<Bool> { .tabBirthdaysEnabled }

    @Published private(set) var birthdays: [Birthday] = []
    /// Start of the current local day; moves at midnight so Countdowns refresh.
    @Published private(set) var today: Date = Calendar.current.startOfDay(for: Date())

    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var announceTask: Task<Void, Never>?
    private var isRunning = false

    private let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("SimpleNotch", isDirectory: true)
            .appendingPathComponent("birthdays.json")
    }()

    private init() {
        load()
    }

    // MARK: Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true
        refreshDay()

        let center = NotificationCenter.default
        let dayToken = center.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.dayDidChange() }
        }
        observers.append((center, dayToken))

        let workspace = NSWorkspace.shared.notificationCenter
        let wakeToken = workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.dayDidChange() }
        }
        observers.append((workspace, wakeToken))

        checkAnnouncements()
    }

    func stop() {
        isRunning = false
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
        announceTask?.cancel()
        announceTask = nil
    }

    private func dayDidChange() {
        refreshDay()
        checkAnnouncements()
    }

    private func refreshDay() {
        let start = Calendar.current.startOfDay(for: Date())
        if start != today { today = start }
    }

    // MARK: Queries

    /// All Birthdays, soonest first (today on top), then by name.
    var sorted: [Birthday] {
        let now = today
        let keyed: [(birthday: Birthday, days: Int)] = birthdays.map { ($0, $0.countdown(from: now)) }
        let ordered = keyed.sorted { (lhs: (birthday: Birthday, days: Int), rhs: (birthday: Birthday, days: Int)) -> Bool in
            if lhs.days != rhs.days { return lhs.days < rhs.days }
            return lhs.birthday.name.localizedCaseInsensitiveCompare(rhs.birthday.name) == .orderedAscending
        }
        return ordered.map { $0.birthday }
    }

    // MARK: Editing

    func save(_ birthday: Birthday) {
        if let index = birthdays.firstIndex(where: { $0.id == birthday.id }) {
            birthdays[index] = birthday
        } else {
            birthdays.append(birthday)
        }
        persist()
        if isRunning { checkAnnouncements() }
    }

    func delete(_ birthday: Birthday) {
        birthdays.removeAll { $0.id == birthday.id }
        persist()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            birthdays = try JSONDecoder().decode([Birthday].self, from: data)
        } catch {
            NSLog("SimpleNotch: could not read birthdays.json: \(error)")
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(birthdays).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("SimpleNotch: could not save birthdays.json: \(error)")
        }
    }

    // MARK: Announcements

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Announces Birthdays that are today, and reminders N days ahead, each
    /// at most once per local day.
    func checkAnnouncements() {
        let now = Date()
        let dayKey = Self.dayFormatter.string(from: now)
        var log = Defaults[.birthdayAnnouncementLog]
        if log.day != dayKey { log = BirthdayAnnouncementLog(day: dayKey, ids: []) }

        let reminderDays = Defaults[.birthdayReminderDays]
        var pending: [NotchAnnouncement] = []

        for birthday in sorted {
            let countdown = birthday.countdown(from: now)
            let age = birthday.ageTurning(from: now)
            if countdown == 0 {
                let key = "today:\(birthday.id.uuidString)"
                guard !log.ids.contains(key) else { continue }
                log.ids.append(key)
                pending.append(NotchAnnouncement(
                    kind: .birthday,
                    title: String(localized: "\(birthday.name)'s birthday today"),
                    subtitle: age.map { String(localized: "turns \($0)") },
                    emoji: "🎂",
                    celebrates: true,
                    opensTab: .birthdays,
                    duration: 6
                ))
            } else if reminderDays > 0, countdown == reminderDays {
                let key = "reminder:\(birthday.id.uuidString)"
                guard !log.ids.contains(key) else { continue }
                log.ids.append(key)
                let title = countdown == 1
                    ? String(localized: "\(birthday.name)'s birthday tomorrow")
                    : String(localized: "\(birthday.name)'s birthday in \(countdown) days")
                pending.append(NotchAnnouncement(
                    kind: .birthday,
                    title: title,
                    subtitle: age.map { String(localized: "turns \($0)") },
                    emoji: birthday.emoji ?? "🎁",
                    celebrates: false,
                    opensTab: .birthdays,
                    duration: 4
                ))
            }
        }

        Defaults[.birthdayAnnouncementLog] = log
        guard !pending.isEmpty else { return }
        enqueue(pending)
    }

    /// Shows announcements one after another, since a new one replaces the
    /// one on screen.
    private func enqueue(_ announcements: [NotchAnnouncement]) {
        let previous = announceTask
        announceTask = Task { @MainActor in
            await previous?.value
            for announcement in announcements {
                guard !Task.isCancelled else { return }
                NotchViewCoordinator.shared.announce(announcement)
                try? await Task.sleep(for: .seconds((announcement.duration ?? 4) + 0.6))
            }
        }
    }
}
