import SwiftUI

@main
struct OpenTermApp: App {
    @StateObject private var store = ConnectionStore()
    @StateObject private var appState = AppState()
    @StateObject private var vault = PasswordVault()
    @StateObject private var settings = SettingsStore()
    @StateObject private var macroStore = MacroStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(appState)
                .environmentObject(vault)
                .environmentObject(settings)
                .environmentObject(macroStore)
                .sheet(isPresented: $appState.showAbout) {
                    AboutView()
                }
                .sheet(isPresented: $appState.showAcknowledgments) {
                    AcknowledgmentsView()
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About OpenTerm") {
                    appState.showAbout = true
                }
            }
            CommandMenu("Configuration") {
                Button("Password Manager…") {
                    appState.showPasswordManager = true
                }
                Button("Settings…") {
                    appState.showSettings = true
                }
            }
            CommandGroup(replacing: .help) {
                Button("Report an Issue…") {
                    if let url = URL(string: "https://github.com/bentech4u/OpenTerm/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("View on GitHub") {
                    if let url = URL(string: "https://github.com/bentech4u/OpenTerm") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Buy Me a Coffee") {
                    if let url = URL(string: "https://buymeacoffee.com/bentech4u") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Divider()
                Button("Acknowledgments…") {
                    appState.showAcknowledgments = true
                }
            }
        }
    }
}
