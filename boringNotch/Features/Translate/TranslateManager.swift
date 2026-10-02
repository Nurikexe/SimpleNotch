import Defaults
import SwiftUI

@MainActor
final class TranslateManager: ObservableObject, NotchFeature {
    static let shared = TranslateManager()
    var enabledKey: Defaults.Key<Bool> { .tabTranslateEnabled }
    func start() {}
    func stop() {}
}

struct TranslateTabView: View {
    var body: some View { Text("Translate") }
}

struct TranslateSettingsView: View {
    var body: some View { Form { Text("Translate") } }
}
