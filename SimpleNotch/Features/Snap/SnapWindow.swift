//
//  SnapWindow.swift
//  SimpleNotch
//
//  A thin wrapper over another app's window, read and moved through the
//  Accessibility API. All AX geometry is top-left-origin global space.
//

import AppKit
import ApplicationServices

struct SnapWindow {
    let element: AXUIElement

    /// Keeps a hung app from stalling the main thread.
    private static let messagingTimeout: Float = 0.25

    // MARK: Finding windows

    /// The window under `point` (AppKit global coordinates), if it belongs to
    /// another app.
    static func at(appKitPoint point: CGPoint) -> SnapWindow? {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, messagingTimeout)
        let axPoint = SnapCoordinates.flip(point)
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(axPoint.x), Float(axPoint.y), &hit) == .success,
              var current = hit
        else { return nil }

        var pid: pid_t = 0
        AXUIElementGetPid(current, &pid)
        guard pid != getpid() else { return nil }

        // Walk up to the AXWindow; most elements also point straight at it.
        for _ in 0 ..< 32 {
            if string(current, kAXRoleAttribute) == (kAXWindowRole as String) {
                return SnapWindow(element: current)
            }
            if let window = element(current, kAXWindowAttribute),
               string(window, kAXRoleAttribute) == (kAXWindowRole as String) {
                return SnapWindow(element: window)
            }
            guard let parent = element(current, kAXParentAttribute) else { break }
            current = parent
        }
        return nil
    }

    /// The window of app `pid` whose frame is closest to `cgBounds`
    /// (top-left-origin global space, as the window list reports it).
    static func matching(pid: pid_t, cgBounds: CGRect) -> SnapWindow? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, messagingTimeout)
        guard let windows = copy(app, kAXWindowsAttribute) as? [AXUIElement] else { return nil }
        let scored = windows.compactMap { element -> (SnapWindow, CGFloat)? in
            let window = SnapWindow(element: element)
            guard let position = window.position, let size = window.size else { return nil }
            let distance = abs(position.x - cgBounds.minX) + abs(position.y - cgBounds.minY)
                + abs(size.width - cgBounds.width) + abs(size.height - cgBounds.height)
            return (window, distance)
        }
        guard let best = scored.min(by: { $0.1 < $1.1 }), best.1 < 40 else { return nil }
        return best.0
    }

    /// The focused window of the frontmost app.
    static func focused() -> SnapWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != getpid()
        else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, messagingTimeout)
        guard let window = element(appElement, kAXFocusedWindowAttribute) else { return nil }
        return SnapWindow(element: window)
    }

    // MARK: Geometry

    /// Top-left corner, in AX coordinates.
    var position: CGPoint? {
        guard let value = Self.axValue(element, kAXPositionAttribute) else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    var size: CGSize? {
        guard let value = Self.axValue(element, kAXSizeAttribute) else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    /// The window's frame in AppKit global coordinates.
    var appKitFrame: CGRect? {
        guard let position, let size else { return nil }
        return SnapCoordinates.flip(CGRect(origin: position, size: size))
    }

    /// The screen holding most of the window.
    var screen: NSScreen? {
        guard let frame = appKitFrame else { return nil }
        return NSScreen.screens.max { a, b in
            Self.area(a.frame.intersection(frame)) < Self.area(b.frame.intersection(frame))
        }
    }

    /// Moves and resizes the window to `frame` (AppKit global coordinates).
    /// Size, then position, then size again, as Rectangle does: the first
    /// resize lets the window fit where it lands, the last one fixes any
    /// clamping the app applied while it was still at its old position.
    func setFrame(appKit frame: CGRect) {
        let axFrame = SnapCoordinates.flip(frame)
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        let app = AXUIElementCreateApplication(pid)

        // "Enhanced user interface" (set by some assistive apps) makes AX
        // resizes animate and land in the wrong place; turn it off meanwhile.
        let enhancedKey = "AXEnhancedUserInterface" as CFString
        var enhancedValue: CFTypeRef?
        let wasEnhanced = AXUIElementCopyAttributeValue(app, enhancedKey, &enhancedValue) == .success
            && (enhancedValue as? Bool) == true
        if wasEnhanced { AXUIElementSetAttributeValue(app, enhancedKey, kCFBooleanFalse) }

        var size = axFrame.size
        var origin = axFrame.origin
        if let sizeValue = AXValueCreate(.cgSize, &size), let originValue = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, originValue)
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        }

        if wasEnhanced { AXUIElementSetAttributeValue(app, enhancedKey, kCFBooleanTrue) }
    }

    // MARK: AX plumbing

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }

    private static func copy(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    private static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = copy(element, attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        copy(element, attribute) as? String
    }

    private static func axValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        guard let value = copy(element, attribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXValue.self)
    }
}
