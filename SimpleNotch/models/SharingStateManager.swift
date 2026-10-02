//
//  SharingStateManager.swift
//  SimpleNotch
//
//  Created by Alexander on 2025-10-10.
//

import AppKit
import Combine
import Foundation

extension Notification.Name {
	static let sharingDidFinish = Notification.Name("io.github.nurikexe.SimpleNotch.sharingDidFinish")
}

@MainActor
final class SharingStateManager: ObservableObject {
	static let shared = SharingStateManager()

	private var activeSessions: Int = 0 {
		didSet { update(announceIdle: true) }
	}

	/// A menu (e.g. a Shelf item's context menu) is open. The pointer is then
	/// over the menu, outside the notch, and closing the notch under it would
	/// both dismiss the menu's context and make tracking stutter.
	/// After a menu closes, the notch's own pointer watch decides when to
	/// close, so an item that opens UI in the notch (Rename) isn't cut off.
	private var menuTracking = false {
		didSet { update(announceIdle: false) }
	}

	private func update(announceIdle: Bool) {
		let newValue = activeSessions > 0 || menuTracking
		guard newValue != preventNotchClose else { return }
		preventNotchClose = newValue
		if !newValue && announceIdle {
			NotificationCenter.default.post(name: .sharingDidFinish, object: nil)
		}
	}

	@Published var preventNotchClose: Bool = false

	private var activeDelegates: [UUID: SharingLifecycleDelegate] = [:]

	private var menuObservers: [NSObjectProtocol] = []

	private init() {
		let center = NotificationCenter.default
		menuObservers = [
			center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
				MainActor.assumeIsolated { self?.menuTracking = true }
			},
			center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { [weak self] _ in
				MainActor.assumeIsolated { self?.menuTracking = false }
			},
		]
	}
	
	func requestCloseIfReady() {
		if !preventNotchClose {
			NotificationCenter.default.post(name: .sharingDidFinish, object: nil)
		}
	}

	func beginInteraction() {
		activeSessions += 1
	}

	func endInteraction() {
		if activeSessions > 0 { activeSessions -= 1 }
	}

	func makeDelegate(onEnd: (() -> Void)? = nil) -> SharingLifecycleDelegate {
		let id = UUID()
		let delegate = SharingLifecycleDelegate(id: id, onEnd: { [weak self] in
			onEnd?()
			self?.unregisterDelegate(id: id)
		}, onBegin: { [weak self] in
			self?.beginInteraction()
		}, onFinish: { [weak self] in
			self?.endInteraction()
		})
		activeDelegates[id] = delegate
		return delegate
	}

	private func unregisterDelegate(id: UUID) {
		activeDelegates.removeValue(forKey: id)
	}
}

final class SharingLifecycleDelegate: NSObject, NSSharingServiceDelegate, NSSharingServicePickerDelegate {
	let id: UUID
	private let onEnd: () -> Void
	private let onBegin: () -> Void
	private let onFinish: () -> Void

	private var pickerActive = false
	private var serviceInProgress = false
	private var finished = false
	private var timeoutTask: Task<Void, Never>?

	init(id: UUID, onEnd: @escaping () -> Void, onBegin: @escaping () -> Void, onFinish: @escaping () -> Void) {
		self.id = id
		self.onEnd = onEnd
		self.onBegin = onBegin
		self.onFinish = onFinish
	}
	
	deinit {
		timeoutTask?.cancel()
	}

	func markPickerBegan() {
		guard !pickerActive else { return }
		pickerActive = true
		onBegin()
	}

	func markServiceBegan() {
		guard !serviceInProgress else { return }
		serviceInProgress = true
		onBegin()
		startTimeoutFallback()
	}
	
	private func startTimeoutFallback() {
		timeoutTask?.cancel()
		timeoutTask = Task { @MainActor [weak self] in
			try? await Task.sleep(for: .seconds(2))
			guard let self = self, !Task.isCancelled else { return }
			if !self.finished {
				self.finishIfNeeded()
			}
		}
	}

	private func finishIfNeeded() {
		guard !finished else { return }
		finished = true
		timeoutTask?.cancel()
		onFinish()
		onEnd()
	}

	// MARK: - NSSharingServicePickerDelegate

	func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
		if service == nil {
			if pickerActive && !serviceInProgress {
				finishIfNeeded()
			}
			return
		}

		service?.delegate = self
		serviceInProgress = true
		startTimeoutFallback()
	}

	// MARK: - NSSharingServiceDelegate

	func sharingService(_ sharingService: NSSharingService, willShareItems items: [Any]) {
		if !pickerActive && !serviceInProgress {
			onBegin()
		}
		serviceInProgress = true
	}

	func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
		finishIfNeeded()
	}

	func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
		finishIfNeeded()
	}
}

