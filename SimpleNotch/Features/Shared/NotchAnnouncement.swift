//
//  NotchAnnouncement.swift
//  SimpleNotch
//
//  A Sneak peek that is not about music: the closed notch widens briefly to
//  say something happened (Pomodoro interval done, a Birthday, a finished
//  download) without opening.
//

import SwiftUI

struct NotchAnnouncement: Identifiable, Equatable {
    enum Kind: Equatable {
        case focus
        case timer
        case birthday
        case download
    }

    let id = UUID()
    var kind: Kind
    var title: String
    var subtitle: String?
    /// An emoji shown as the leading glyph, or nil to use `symbol`.
    var emoji: String?
    var symbol: String = "sparkles"
    var tint: Color = .white
    /// Bursts confetti when it appears.
    var celebrates: Bool = false
    /// The Tab to open if the user hovers while it is showing.
    var opensTab: NotchViews?
    /// Seconds before it hides itself; nil keeps it until dismissed.
    var duration: TimeInterval? = 4

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}
