//
//  Motion.swift
//  SimpleNotch
//
//  The one place animation curves live, so every motion in the app feels like
//  one system. See "Motion standard" in CLAUDE.md before adding to this file.
//

import AppKit
import SwiftUI

enum Motion {
    /// Opening the notch (boring.notch's own spring).
    static let notchOpen = Animation.spring(response: 0.42, dampingFraction: 0.8)
    /// Closing the notch: critically damped so it never overshoots into the menu bar.
    static let notchClose = Animation.spring(response: 0.45, dampingFraction: 1.0)
    /// Hover, drag and gesture-driven movement; retargets with velocity.
    static let interactive = Animation.interactiveSpring(response: 0.38, dampingFraction: 0.8)
    /// Small UI state changes: selection, toggles, list rows.
    static let snappy = Animation.snappy(duration: 0.32)
    /// Content swaps that should feel calm: tab changes, text, layout shifts.
    static let smooth = Animation.smooth(duration: 0.4)
    /// Playful arrivals: the Tomato, confetti, a new tally tomato.
    static let bouncy = Animation.bouncy(duration: 0.5, extraBounce: 0.12)

    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Returns a calm cross-fade when Reduce Motion is on, otherwise `animation`.
    static func respecting(_ animation: Animation) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : animation
    }
}

/// `withAnimation` that honours Reduce Motion.
@discardableResult
func withMotion<Result>(_ animation: Animation, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(Motion.respecting(animation), body)
}

private struct BlurModifier: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View { content.blur(radius: radius) }
}

extension AnyTransition {
    /// The standard way content appears and leaves inside the notch:
    /// fade + slight scale + blur, never a bare pop.
    static var notchContent: AnyTransition {
        .opacity
            .combined(with: .scale(scale: 0.94, anchor: .top))
            .combined(with: .modifier(active: BlurModifier(radius: 8), identity: BlurModifier(radius: 0)))
    }

    /// For small elements (chips, rows, badges).
    static var softPop: AnyTransition {
        .opacity
            .combined(with: .scale(scale: 0.8))
            .combined(with: .modifier(active: BlurModifier(radius: 4), identity: BlurModifier(radius: 0)))
    }
}
