//
//  AccessibilityPermission.swift
//  SimpleNotch
//
//  In-process replacement for upstream's XPC helper. SimpleNotch is unsandboxed
//  (docs/adr/0003), so the app checks and requests Accessibility trust itself;
//  the permission then belongs to the app, which is what Snap and paste need.
//

import AppKit
import ApplicationServices

final class AccessibilityPermission: @unchecked Sendable {
    static let shared = AccessibilityPermission()

    private var monitoringTask: Task<Void, Never>?
    @MainActor private var lastKnownAuthorization: Bool?

    var isTrusted: Bool { AXIsProcessTrusted() }

    func isAccessibilityAuthorized() async -> Bool {
        let result = AXIsProcessTrusted()
        await notifyAuthorizationChange(result)
        return result
    }

    func requestAccessibilityAuthorization() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func ensureAccessibilityAuthorization(promptIfNeeded: Bool) async -> Bool {
        if AXIsProcessTrusted() {
            await notifyAuthorizationChange(true)
            return true
        }
        if promptIfNeeded { requestAccessibilityAuthorization() }
        await notifyAuthorizationChange(false)
        return false
    }

    func startMonitoringAccessibilityAuthorization(every interval: TimeInterval = 3.0) {
        stopMonitoringAccessibilityAuthorization()
        monitoringTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                _ = await self?.isAccessibilityAuthorized()
                do { try await Task.sleep(for: .seconds(interval)) } catch { break }
            }
        }
    }

    func stopMonitoringAccessibilityAuthorization() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    @MainActor
    private func notifyAuthorizationChange(_ granted: Bool) {
        guard lastKnownAuthorization != granted else { return }
        lastKnownAuthorization = granted
        NotificationCenter.default.post(name: .accessibilityAuthorizationChanged, object: nil, userInfo: ["granted": granted])
    }
}

extension Notification.Name {
    static let accessibilityAuthorizationChanged = Notification.Name("accessibilityAuthorizationChanged")
}
