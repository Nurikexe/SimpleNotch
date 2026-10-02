import Defaults
import SwiftUI

@MainActor
final class ClipboardManager: ObservableObject, NotchFeature {
    static let shared = ClipboardManager()
    var enabledKey: Defaults.Key<Bool> { .tabClipboardEnabled }
    func start() {}
    func stop() {}
}

struct ClipboardTabView: View {
    var body: some View { Text("Clipboard") }
}

struct ClipboardSettingsView: View {
    var body: some View { Form { Text("Clipboard") } }
}
