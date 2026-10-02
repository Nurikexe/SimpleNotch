//
//  ShelfActionBar.swift
//  SimpleNotch
//
//  The Shelf item's actions, drawn inside the notch. A system context menu
//  stutters when macOS draws it over the notch's window, and its pointer trip
//  leaves the notch; this bar does neither.
//

import AppKit
import SwiftUI

/// Which Shelf item shows its action bar. One at a time.
@MainActor
final class ShelfActionBarState: ObservableObject {
    static let shared = ShelfActionBarState()

    @Published private(set) var itemID: UUID?
    /// The bar's frame in its window's SwiftUI (top-left) space; clicks
    /// inside it must not dismiss it.
    var barFrame: CGRect = .null

    private var monitor: Any?

    private init() {}

    func show(for id: UUID) {
        withMotion(Motion.bouncy) { itemID = id }
        installMonitor()
    }

    func dismiss() {
        guard itemID != nil else { return }
        withMotion(Motion.snappy) { itemID = nil }
        barFrame = .null
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            let isEscape = event.type == .keyDown && event.keyCode == 53
            if event.type == .keyDown && !isEscape { return event }
            let location = event.locationInWindow
            let contentHeight = event.window?.contentView?.bounds.height
            let consumed = MainActor.assumeIsolated { () -> Bool in
                guard let self else { return false }
                if isEscape {
                    self.dismiss()
                    return true
                }
                if let contentHeight,
                   self.barFrame.contains(CGPoint(x: location.x, y: contentHeight - location.y)) {
                    return false
                }
                // A right-click on an item re-shows the bar there right after.
                self.dismiss()
                return false
            }
            return consumed ? nil : event
        }
    }
}

struct ShelfActionBar: View {
    let actions: [ShelfItemViewModel.Action]
    let perform: (ShelfItemViewModel.Action, _ alternate: Bool) -> Void

    @State private var hovered: ShelfItemViewModel.Action?
    @State private var copied = false
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 2) {
            ForEach(actions) { action in
                button(action)
            }
        }
        .padding(2)
        .background(
            Capsule(style: .continuous)
                .fill(Color(white: 0.17))
                .shadow(color: .black.opacity(0.55), radius: 8, y: 3)
        )
        .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
        .onHover { if !$0 { withMotion(Motion.interactive) { hovered = nil } } }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
            ShelfActionBarState.shared.barFrame = frame
        }
    }

    private func button(_ action: ShelfItemViewModel.Action) -> some View {
        let isHovered = hovered == action
        let symbol = action == .copy && copied ? "checkmark" : action.symbol
        return Button {
            let alternate = NSEvent.modifierFlags.contains(.option)
            perform(action, alternate)
            if action == .copy {
                withMotion(Motion.snappy) { copied = true }
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(action == .remove && isHovered ? Color.red : Color.white.opacity(isHovered ? 1 : 0.8))
                .frame(width: 20, height: 20)
                .background {
                    if isHovered {
                        Circle()
                            .fill(action == .remove ? Color.red.opacity(0.2) : Color.white.opacity(0.15))
                            .matchedGeometryEffect(id: "hover", in: highlight)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(ActionPressStyle())
        .help(action.title)
        .onHover { inside in
            guard inside else { return }
            withMotion(Motion.interactive) { hovered = action }
        }
    }
}

private struct ActionPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .animation(Motion.respecting(Motion.snappy), value: configuration.isPressed)
    }
}
