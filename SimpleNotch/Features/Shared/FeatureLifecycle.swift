//
//  FeatureLifecycle.swift
//  SimpleNotch
//
//  Starts each feature's background work when its switch is on and stops it
//  when the switch goes off: a Tab that is off costs nothing.
//

import Combine
import Defaults
import Foundation

/// A feature with background work that follows an on/off switch.
@MainActor
protocol NotchFeature: AnyObject {
    var enabledKey: Defaults.Key<Bool> { get }
    func start()
    func stop()
}

@MainActor
enum FeatureLifecycle {
    private static var features: [NotchFeature] {
        [
            FocusManager.shared,
            ClipboardManager.shared,
            TranslateManager.shared,
            BirthdayStore.shared,
            WindowSnapManager.shared,
            DownloadMonitor.shared,
        ]
    }

    private static var observers: Set<AnyCancellable> = []

    static func startAll() {
        for feature in features {
            if Defaults[feature.enabledKey] { feature.start() }
            Defaults.publisher(feature.enabledKey, options: [])
                .map(\.newValue)
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { enabled in
                    MainActor.assumeIsolated {
                        enabled ? feature.start() : feature.stop()
                    }
                }
                .store(in: &observers)
        }
    }

    static func stopAll() {
        observers.removeAll()
        features.forEach { $0.stop() }
    }
}
