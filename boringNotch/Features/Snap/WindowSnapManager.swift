//
//  WindowSnapManager.swift
//  SimpleNotch
//
//  Window snapping. Watches mouse events (and nothing else, so it costs
//  nothing at rest) to notice another app's window being dragged; when the
//  pointer nears the notch, the notch opens on that screen as the Snap grid,
//  and dropping the window on a Layout Snaps it there. Keyboard shortcuts Snap
//  the focused window directly.
//

import AppKit
import Defaults
import KeyboardShortcuts
import SwiftUI

/// Which tile of the Snap grid the pointer is over. Kept apart from the
/// manager so hover changes re-render only the grid, not the whole notch.
@MainActor
final class SnapGridHover: ObservableObject {
    @Published fileprivate(set) var layout: SnapLayout?
}

@MainActor
final class WindowSnapManager: ObservableObject, NotchFeature {
    static let shared = WindowSnapManager()
    var enabledKey: Defaults.Key<Bool> { .windowSnappingEnabled }

    /// A window is being dragged anywhere on screen (the closed notch glows).
    @Published private(set) var isWindowDragActive = false
    /// The Snap grid is showing in the open notch on this screen.
    @Published private(set) var gridScreenID: String?
    /// The Layout under the pointer while the Snap grid shows.
    let hover = SnapGridHover()

    // How close the pointer must come to the closed notch to open the grid,
    // and how far beyond the open notch it may wander before the grid closes.
    private let openDistance: CGFloat = 120
    private let stayMargin: CGFloat = 28
    /// Window-moved checks are throttled to this interval until a drag is seen.
    private let moveCheckInterval: CFTimeInterval = 1.0 / 30.0

    private var monitors: [Any] = []
    private var isRunning = false

    // The current mouse-down candidate.
    private var draggedWindow: SnapWindow?
    private var dragStartPosition: CGPoint?
    private var lastMoveCheck: CFTimeInterval = 0

    // Tile frames reported by the visible SnapGridView, in its window's space.
    private var tileFrames: [SnapLayout: CGRect] = [:]
    private weak var tileWindow: NSWindow?

    private init() {}

    // MARK: Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Snapping can't see other apps' windows without Accessibility; ask
        // up front rather than silently doing nothing on the first drag.
        if !AccessibilityPermission.shared.isTrusted {
            AccessibilityPermission.shared.requestAccessibilityAuthorization()
        }

        let handlers: [(NSEvent.EventTypeMask, @MainActor (WindowSnapManager) -> Void)] = [
            (.leftMouseDown, { $0.mouseDown() }),
            (.leftMouseDragged, { $0.mouseDragged() }),
            (.leftMouseUp, { $0.mouseUp() }),
        ]
        monitors = handlers.compactMap { mask, handler in
            NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    handler(self)
                }
            }
        }

        for layout in SnapLayout.allCases {
            KeyboardShortcuts.onKeyDown(for: layout.shortcutName) { [weak self] in
                MainActor.assumeIsolated { self?.snapFocusedWindow(to: layout) }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        for layout in SnapLayout.allCases {
            KeyboardShortcuts.removeHandler(for: layout.shortcutName)
        }
        endDrag()
    }

    // MARK: Keyboard shortcuts

    func snapFocusedWindow(to layout: SnapLayout) {
        guard AccessibilityPermission.shared.isTrusted,
              let window = SnapWindow.focused(),
              let screen = window.screen
        else {
            NSSound.beep()
            return
        }
        snap(window, to: layout, on: screen)
    }

    private func snap(_ window: SnapWindow, to layout: SnapLayout, on screen: NSScreen) {
        let frame = layout.frame(in: screen.visibleFrame, gap: CGFloat(Defaults[.snapGap]))
        window.setFrame(appKit: frame)
    }

    // MARK: Window-drag detection

    private func mouseDown() {
        endDrag()
        guard AccessibilityPermission.shared.isTrusted,
              let window = SnapWindow.at(appKitPoint: NSEvent.mouseLocation),
              let position = window.position
        else { return }
        draggedWindow = window
        dragStartPosition = position
        lastMoveCheck = 0
    }

    private func mouseDragged() {
        guard let window = draggedWindow else { return }

        if !isWindowDragActive {
            // Until the window itself moves this may be a text selection or a
            // slider drag inside it; check its position at a modest rate.
            let now = CACurrentMediaTime()
            guard now - lastMoveCheck >= moveCheckInterval else { return }
            lastMoveCheck = now
            guard let start = dragStartPosition, let position = window.position,
                  abs(position.x - start.x) > 1 || abs(position.y - start.y) > 1
            else { return }
            isWindowDragActive = true
        }

        updateGrid(pointer: NSEvent.mouseLocation)
    }

    private func mouseUp() {
        defer { endDrag() }
        guard isWindowDragActive,
              let window = draggedWindow,
              let layout = hover.layout,
              let screenID = gridScreenID,
              let screen = NSScreen.screen(withUUID: screenID)
        else { return }
        snap(window, to: layout, on: screen)
    }

    private func endDrag() {
        hideGrid()
        draggedWindow = nil
        dragStartPosition = nil
        if isWindowDragActive { isWindowDragActive = false }
    }

    // MARK: Snap grid

    private func updateGrid(pointer: CGPoint) {
        guard let screen = Self.screen(containing: pointer), let screenID = screen.displayUUID else {
            hideGrid()
            return
        }

        let showing = gridScreenID == screenID
        let near = isNearNotch(pointer, on: screen) || (showing && isOverOpenNotch(pointer, on: screen))

        if near {
            if !showing { showGrid(on: screen, id: screenID) }
            updateHover(pointer: pointer)
        } else {
            hideGrid()
        }
    }

    private func showGrid(on screen: NSScreen, id screenID: String) {
        hideGrid()
        guard NotchRouter.shared.viewModel(on: screen) != nil else { return }
        tileFrames.removeAll()
        withMotion(Motion.notchOpen) {
            gridScreenID = screenID
        }
        NotchRouter.shared.open(nil, on: screen, pinned: true)
    }

    private func hideGrid() {
        guard let screenID = gridScreenID else { return }
        withMotion(Motion.notchClose) {
            gridScreenID = nil
            hover.layout = nil
        }
        tileFrames.removeAll()
        tileWindow = nil
        if let screen = NSScreen.screen(withUUID: screenID) {
            NotchRouter.shared.close(on: screen)
        }
    }

    /// Called by SnapGridView with each tile's frame in its window's space.
    func registerTileFrame(_ frame: CGRect, for layout: SnapLayout, screenID: String?, window: NSWindow?) {
        guard let screenID, screenID == gridScreenID, let window else { return }
        tileFrames[layout] = frame
        tileWindow = window
    }

    private func updateHover(pointer: CGPoint) {
        var hit: SnapLayout?
        if let window = tileWindow {
            let windowFrame = window.frame
            for (layout, frame) in tileFrames {
                // SwiftUI's global space is the hosting view: top-left origin.
                let global = CGRect(
                    x: windowFrame.minX + frame.minX,
                    y: windowFrame.maxY - frame.maxY,
                    width: frame.width,
                    height: frame.height
                ).insetBy(dx: -4, dy: -4)
                if global.contains(pointer) {
                    hit = layout
                    break
                }
            }
        }
        guard hit != hover.layout else { return }
        withMotion(Motion.interactive) {
            hover.layout = hit
        }
    }

    // MARK: Geometry

    private static func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { frame in
            let f = frame.frame
            return point.x >= f.minX && point.x < f.maxX && point.y >= f.minY && point.y <= f.maxY
        }
    }

    /// Within `openDistance` of the closed notch at the top centre of the screen.
    private func isNearNotch(_ point: CGPoint, on screen: NSScreen) -> Bool {
        let frame = screen.frame
        let notch = NotchRouter.shared.viewModel(on: screen)?.closedNotchSize ?? CGSize(width: 200, height: 32)
        let notchRect = CGRect(x: frame.midX - notch.width / 2, y: frame.maxY - notch.height,
                               width: notch.width, height: notch.height)
        let dx = max(notchRect.minX - point.x, 0, point.x - notchRect.maxX)
        let dy = max(notchRect.minY - point.y, 0, point.y - notchRect.maxY)
        return (dx * dx + dy * dy).squareRoot() <= openDistance
    }

    /// Over the open notch (plus a margin), where the tiles are.
    private func isOverOpenNotch(_ point: CGPoint, on screen: NSScreen) -> Bool {
        let frame = screen.frame
        let width = openNotchSize.width + stayMargin * 2
        let height = openNotchSize.height + stayMargin
        return CGRect(x: frame.midX - width / 2, y: frame.maxY - height, width: width, height: height)
            .contains(point)
    }
}
