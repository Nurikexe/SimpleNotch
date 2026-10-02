//
//  Birthday.swift
//  SimpleNotch
//
//  A Birthday the user tracks by hand, and the calendar maths for its
//  Countdown (days until the next occurrence; zero means today).
//

import Foundation

struct Birthday: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    /// 1...31
    var day: Int
    /// 1...12
    var month: Int
    /// Birth year, if known; used to show the age they are turning.
    var year: Int?
    var emoji: String?

    /// The next occurrence on or after the start of `today`, in the local calendar.
    /// A Feb 29 Birthday falls on Feb 28 in non-leap years.
    func nextOccurrence(from today: Date = Date(), calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: today)
        let thisYear = calendar.component(.year, from: start)
        if let date = occurrence(in: thisYear, calendar: calendar), date >= start {
            return date
        }
        return occurrence(in: thisYear + 1, calendar: calendar) ?? start
    }

    /// The Countdown: whole days from today to the next occurrence. 0 is today.
    func countdown(from today: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: today)
        let next = nextOccurrence(from: start, calendar: calendar)
        return calendar.dateComponents([.day], from: start, to: next).day ?? 0
    }

    /// The age they turn on the next occurrence, if the birth year is known.
    func ageTurning(from today: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let year else { return nil }
        let next = nextOccurrence(from: today, calendar: calendar)
        let age = calendar.component(.year, from: next) - year
        return age > 0 ? age : nil
    }

    /// The day this Birthday is celebrated in `year`, clamping days the month
    /// doesn't have (Feb 29 in a common year becomes Feb 28).
    func occurrence(in year: Int, calendar: Calendar = .current) -> Date? {
        guard let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth)
        else { return nil }
        let clampedDay = min(max(day, 1), range.upperBound - 1)
        return calendar.date(from: DateComponents(year: year, month: month, day: clampedDay))
    }

    /// Short date such as "12 Mar", in the user's locale.
    var shortDate: String {
        var comps = DateComponents()
        comps.year = 2000 // a leap year, so Feb 29 formats as itself
        comps.month = month
        comps.day = day
        guard let date = Calendar.current.date(from: comps) else { return "\(day).\(month)" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    var initial: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() } ?? "?"
    }

    /// Number of days a month can have, allowing Feb 29.
    static func maxDays(inMonth month: Int) -> Int {
        switch month {
        case 2: 29
        case 4, 6, 9, 11: 30
        default: 31
        }
    }
}
