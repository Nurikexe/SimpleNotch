import Defaults
import SwiftUI

@MainActor
final class BirthdayStore: ObservableObject, NotchFeature {
    static let shared = BirthdayStore()
    var enabledKey: Defaults.Key<Bool> { .tabBirthdaysEnabled }
    func start() {}
    func stop() {}
}

struct BirthdaysTabView: View {
    var body: some View { Text("Birthdays") }
}

struct BirthdaysSettingsView: View {
    var body: some View { Form { Text("Birthdays") } }
}
