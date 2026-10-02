//
//  NotchTab.swift
//  SimpleNotch
//
//  The six Tabs of the open notch and the switches that turn each one off.
//  Turning a Tab off removes its icon and stops its background work.
//

import Defaults
import SwiftUI

extension NotchViews {
    var label: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .shelf: "Shelf"
        case .clipboard: "Clipboard"
        case .focus: "Focus"
        case .translate: "Translate"
        case .birthdays: "Birthdays"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .shelf: "tray.fill"
        case .clipboard: "doc.on.clipboard.fill"
        case .focus: "timer"
        case .translate: "character.bubble.fill"
        case .birthdays: "gift.fill"
        }
    }

    var enabledKey: Defaults.Key<Bool> {
        switch self {
        case .home: .tabHomeEnabled
        case .shelf: .boringShelf
        case .clipboard: .tabClipboardEnabled
        case .focus: .tabFocusEnabled
        case .translate: .tabTranslateEnabled
        case .birthdays: .tabBirthdaysEnabled
        }
    }

    var isEnabled: Bool { Defaults[enabledKey] }

    static var enabledTabs: [NotchViews] { allCases.filter(\.isEnabled) }
}

extension Defaults.Keys {
    static let tabHomeEnabled = Key<Bool>("tabHomeEnabled", default: true)
    static let tabClipboardEnabled = Key<Bool>("tabClipboardEnabled", default: true)
    static let tabFocusEnabled = Key<Bool>("tabFocusEnabled", default: true)
    static let tabTranslateEnabled = Key<Bool>("tabTranslateEnabled", default: true)
    static let tabBirthdaysEnabled = Key<Bool>("tabBirthdaysEnabled", default: true)
    static let windowSnappingEnabled = Key<Bool>("windowSnappingEnabled", default: true)
    static let downloadIndicatorEnabled = Key<Bool>("downloadIndicatorEnabled", default: true)
    /// The Tab the user last chose, used when nothing more specific applies.
    static let lastSelectedTab = Key<NotchViews>("lastSelectedTab", default: .home)
}
