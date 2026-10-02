import Defaults
import SwiftUI

@MainActor
final class FocusManager: ObservableObject, NotchFeature {
    static let shared = FocusManager()
    var enabledKey: Defaults.Key<Bool> { .tabFocusEnabled }

    enum WingsPriority { case none, low, high }

    /// A Pomodoro interval or Timer is running or paused.
    var isActive: Bool { false }
    /// .high during a Focus session or Timer, .low during a break (music wins).
    var wingsPriority: WingsPriority { .none }
    var showsProgressLine: Bool { false }
    func start() {}
    func stop() {}
}

struct FocusTabView: View {
    var body: some View { Text("Focus") }
}

struct FocusWingsView: View {
    static let wingWidth: CGFloat = 44
    var body: some View { EmptyView() }
}

struct FocusProgressLine: View {
    var body: some View { EmptyView() }
}
