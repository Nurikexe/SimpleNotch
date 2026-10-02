//
//  SnapLayout.swift
//  SimpleNotch
//
//  The Layouts a window can be Snapped to, their keyboard shortcuts, and the
//  geometry that turns a Layout into a window frame on a given screen.
//

import AppKit
import Defaults
import KeyboardShortcuts

extension Defaults.Keys {
    /// Space, in points, kept between snapped windows and the screen edges.
    static let snapGap = Key<Double>("snapGap", default: 0)
}

extension KeyboardShortcuts.Name {
    // Rectangle's defaults, so muscle memory carries over.
    static let snapMaximise = Self("snapMaximise", default: .init(.return, modifiers: [.control, .option]))
    static let snapCentre = Self("snapCentre", default: .init(.c, modifiers: [.control, .option]))
    static let snapLeftHalf = Self("snapLeftHalf", default: .init(.leftArrow, modifiers: [.control, .option]))
    static let snapRightHalf = Self("snapRightHalf", default: .init(.rightArrow, modifiers: [.control, .option]))
    static let snapTopLeft = Self("snapTopLeft", default: .init(.u, modifiers: [.control, .option]))
    static let snapTopRight = Self("snapTopRight", default: .init(.i, modifiers: [.control, .option]))
    static let snapBottomLeft = Self("snapBottomLeft", default: .init(.j, modifiers: [.control, .option]))
    static let snapBottomRight = Self("snapBottomRight", default: .init(.k, modifiers: [.control, .option]))
    static let snapLeftThird = Self("snapLeftThird", default: .init(.d, modifiers: [.control, .option]))
    static let snapCentreThird = Self("snapCentreThird", default: .init(.f, modifiers: [.control, .option]))
    static let snapRightThird = Self("snapRightThird", default: .init(.g, modifiers: [.control, .option]))
    static let snapLeftTwoThirds = Self("snapLeftTwoThirds", default: .init(.e, modifiers: [.control, .option]))
    /// No default: Rectangle's ⌃⌥T is taken by the Translate shortcut.
    static let snapRightTwoThirds = Self("snapRightTwoThirds")
}

/// A named target region of the screen a window can be Snapped to.
enum SnapLayout: String, CaseIterable, Identifiable, Hashable {
    case maximise, centre, leftHalf, rightHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centreThird, rightThird, leftTwoThirds, rightTwoThirds

    var id: String { rawValue }

    /// The Snap grid, row by row.
    static let rows: [[SnapLayout]] = [
        [.maximise, .centre, .leftHalf, .rightHalf],
        [.topLeft, .topRight, .bottomLeft, .bottomRight],
        [.leftThird, .centreThird, .rightThird, .leftTwoThirds, .rightTwoThirds],
    ]

    /// The region as fractions of the visible frame, with a top-left origin
    /// (x to the right, y downwards), matching how the tile is drawn.
    var unitRect: CGRect {
        let third = 1.0 / 3.0
        switch self {
        case .maximise: return CGRect(x: 0, y: 0, width: 1, height: 1)
        case .centre: return CGRect(x: 0.2, y: 0.15, width: 0.6, height: 0.7)
        case .leftHalf: return CGRect(x: 0, y: 0, width: 0.5, height: 1)
        case .rightHalf: return CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        case .topLeft: return CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        case .topRight: return CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        case .bottomLeft: return CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)
        case .bottomRight: return CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        case .leftThird: return CGRect(x: 0, y: 0, width: third, height: 1)
        case .centreThird: return CGRect(x: third, y: 0, width: third, height: 1)
        case .rightThird: return CGRect(x: 2 * third, y: 0, width: third, height: 1)
        case .leftTwoThirds: return CGRect(x: 0, y: 0, width: 2 * third, height: 1)
        case .rightTwoThirds: return CGRect(x: third, y: 0, width: 2 * third, height: 1)
        }
    }

    var title: String {
        switch self {
        case .maximise: return String(localized: "Maximise")
        case .centre: return String(localized: "Centre")
        case .leftHalf: return String(localized: "Left half")
        case .rightHalf: return String(localized: "Right half")
        case .topLeft: return String(localized: "Top-left quarter")
        case .topRight: return String(localized: "Top-right quarter")
        case .bottomLeft: return String(localized: "Bottom-left quarter")
        case .bottomRight: return String(localized: "Bottom-right quarter")
        case .leftThird: return String(localized: "Left third")
        case .centreThird: return String(localized: "Centre third")
        case .rightThird: return String(localized: "Right third")
        case .leftTwoThirds: return String(localized: "Left two-thirds")
        case .rightTwoThirds: return String(localized: "Right two-thirds")
        }
    }

    var shortcutName: KeyboardShortcuts.Name {
        switch self {
        case .maximise: return .snapMaximise
        case .centre: return .snapCentre
        case .leftHalf: return .snapLeftHalf
        case .rightHalf: return .snapRightHalf
        case .topLeft: return .snapTopLeft
        case .topRight: return .snapTopRight
        case .bottomLeft: return .snapBottomLeft
        case .bottomRight: return .snapBottomRight
        case .leftThird: return .snapLeftThird
        case .centreThird: return .snapCentreThird
        case .rightThird: return .snapRightThird
        case .leftTwoThirds: return .snapLeftTwoThirds
        case .rightTwoThirds: return .snapRightTwoThirds
        }
    }

    /// The window frame for this Layout, in AppKit global coordinates
    /// (bottom-left origin). `visibleFrame` is the screen's visible frame.
    /// Outer edges get the full gap; neighbouring windows are a gap apart.
    func frame(in visibleFrame: CGRect, gap: CGFloat) -> CGRect {
        let half = max(0, gap) / 2
        let area = visibleFrame.insetBy(dx: half, dy: half)
        let unit = unitRect
        let rect = CGRect(
            x: area.minX + unit.minX * area.width,
            y: area.maxY - unit.maxY * area.height,
            width: unit.width * area.width,
            height: unit.height * area.height
        )
        return rect.insetBy(dx: half, dy: half).integral
    }
}

/// AppKit global space has its origin at the bottom-left of the primary screen
/// with y going up; Accessibility uses the top-left of the primary screen with
/// y going down. The flip is its own inverse.
enum SnapCoordinates {
    private static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    static func flip(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    static func flip(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
