import Defaults
import SwiftUI

@MainActor
final class DownloadMonitor: ObservableObject, NotchFeature {
    static let shared = DownloadMonitor()
    var enabledKey: Defaults.Key<Bool> { .downloadIndicatorEnabled }
    /// Something is downloading right now.
    @Published private(set) var isActive = false
    func start() {}
    func stop() {}
}

/// Closed-notch Wings content while a download is in progress.
struct DownloadWingsView: View {
    static let wingWidth: CGFloat = 44
    var body: some View { EmptyView() }
}
