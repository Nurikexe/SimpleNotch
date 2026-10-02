import Defaults
import SwiftUI

@MainActor
final class WindowSnapManager: ObservableObject, NotchFeature {
    static let shared = WindowSnapManager()
    var enabledKey: Defaults.Key<Bool> { .windowSnappingEnabled }
    /// A window is being dragged anywhere on screen (the closed notch glows).
    @Published private(set) var isWindowDragActive = false
    /// The Snap grid is showing in the open notch on this screen.
    @Published private(set) var gridScreenID: String?
    func start() {}
    func stop() {}
}

struct SnapGridView: View {
    var body: some View { Text("Snap") }
}

struct SnapSettingsView: View {
    var body: some View { Form { Text("Window snapping") } }
}
