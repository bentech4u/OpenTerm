import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var showPasswordManager: Bool = false
    @Published var showSettings: Bool = false
    @Published var showAbout: Bool = false
    @Published var showAcknowledgments: Bool = false
}
