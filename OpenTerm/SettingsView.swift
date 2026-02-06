import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var store: ConnectionStore
    @EnvironmentObject var vault: PasswordVault
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: SettingsTab = .general
    @State private var statusMessage: String?

    @State private var showFontSheet = false
    @State private var showColorSheet = false

    @State private var showExportPasswordPrompt = false
    @State private var showImportPasswordPrompt = false
    @State private var masterPassword = ""
    @State private var pendingPasswordImport: PasswordExport?

    var body: some View {
        VStack(spacing: 0) {
            header

            TabView(selection: $selectedTab) {
                generalTab
                    .tabItem { Text("General") }
                    .tag(SettingsTab.general)

                terminalTab
                    .tabItem { Text("Terminal") }
                    .tag(SettingsTab.terminal)

                sshTab
                    .tabItem { Text("SSH") }
                    .tag(SettingsTab.ssh)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if let statusMessage {
                Text(statusMessage)
                    .foregroundStyle(statusMessage.contains("Failed") ? .red : .secondary)
                    .padding(.bottom, 12)
            }
        }
        .frame(minWidth: 620, minHeight: 480)
        .sheet(isPresented: $showFontSheet) {
            FontSettingsSheet(
                fontName: $settings.defaultTerminalFontName,
                fontSize: $settings.defaultTerminalFontSize,
                isBold: $settings.defaultTerminalFontBold
            )
        }
        .sheet(isPresented: $showColorSheet) {
            ColorSettingsSheet(
                foreground: defaultForegroundBinding,
                background: defaultBackgroundBinding
            )
        }
        .sheet(isPresented: $showExportPasswordPrompt) {
            MasterPasswordPrompt(title: "Export Passwords", password: $masterPassword) {
                handleExportPasswords()
            }
        }
        .sheet(isPresented: $showImportPasswordPrompt) {
            MasterPasswordPrompt(title: "Import Passwords", password: $masterPassword) {
                handleImportPasswords()
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Button("Close") {
                dismiss()
            }
        }
        .padding([.top, .horizontal], 16)
        .padding(.bottom, 8)
    }

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Export") {
                    VStack(alignment: .leading, spacing: 10) {
                        Button("Export all configurations") {
                            exportSettings()
                        }
                        Button("Export all sessions/connections") {
                            exportSessions()
                        }
                        Button("Export all passwords") {
                            masterPassword = ""
                            showExportPasswordPrompt = true
                        }
                        Text("Password export requires the master password.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Import") {
                    VStack(alignment: .leading, spacing: 10) {
                        Button("Import configurations") {
                            importSettings()
                        }
                        Button("Import sessions/connections") {
                            importSessions()
                        }
                        Button("Import passwords") {
                            importPasswords()
                        }
                        Text("Imports replace existing settings or add sessions/passwords.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var terminalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Default terminal look and feel") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(defaultFontSummary)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Default font settings…") {
                                showFontSheet = true
                            }
                        }
                        HStack {
                            Text("Default colors")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Default color settings…") {
                                showColorSheet = true
                            }
                        }
                        Text("Connection-specific font or colors override these defaults.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Terminal features") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Paste using right-click", isOn: $settings.pasteOnRightClick)
                        Toggle("Warn before pasting", isOn: $settings.warnBeforePaste)
                        Toggle("Enable select to copy", isOn: $settings.selectToCopyEnabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Log terminal output") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Log terminal output to directory", isOn: $settings.logTerminalEnabled)
                        HStack {
                            TextField("Log directory", text: $settings.logTerminalDirectory)
                            Button("Choose…") {
                                chooseLogDirectory()
                            }
                        }
                        .disabled(!settings.logTerminalEnabled)
                        Text("Log files are saved as <session name>.log.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var sshTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("SSH browser settings") {
                    Toggle("Enable SSH browser (SFTP panel)", isOn: $settings.sshBrowserEnabled)
                }

                GroupBox("SSH settings") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("SSH keep alive (sec)", value: $settings.sshKeepAliveSeconds, formatter: NumberFormatter())
                            .frame(width: 200)
                        Text("Connections can override this in their settings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var defaultForegroundBinding: Binding<Color> {
        Binding(
            get: { ColorHex.toColor(settings.defaultTerminalForegroundHex, fallback: .white) },
            set: { settings.defaultTerminalForegroundHex = ColorHex.toHex($0) }
        )
    }

    private var defaultBackgroundBinding: Binding<Color> {
        Binding(
            get: { ColorHex.toColor(settings.defaultTerminalBackgroundHex, fallback: .black) },
            set: { settings.defaultTerminalBackgroundHex = ColorHex.toHex($0) }
        )
    }

    private var defaultFontSummary: String {
        let name = settings.defaultTerminalFontName
        let size = Int(settings.defaultTerminalFontSize)
        let bold = settings.defaultTerminalFontBold ? " Bold" : ""
        return "\(name) \(size)\(bold)"
    }

    private func exportSettings() {
        do {
            let data = try JSONEncoder().encode(settings.snapshot())
            save(data: data, defaultName: "openterm-settings.json")
        } catch {
            statusMessage = "Failed to export settings: \(error.localizedDescription)"
        }
    }

    private func importSettings() {
        open { data in
            do {
                let snapshot = try JSONDecoder().decode(SettingsSnapshot.self, from: data)
                settings.apply(snapshot: snapshot)
                statusMessage = "Imported settings."
            } catch {
                statusMessage = "Failed to import settings: \(error.localizedDescription)"
            }
        }
    }

    private func exportSessions() {
        do {
            let data = try JSONEncoder().encode(AppData(folders: store.folders, connections: store.connections))
            save(data: data, defaultName: "openterm-sessions.json")
        } catch {
            statusMessage = "Failed to export sessions: \(error.localizedDescription)"
        }
    }

    private func importSessions() {
        open { data in
            do {
                let appData = try JSONDecoder().decode(AppData.self, from: data)
                store.replaceData(appData)
                statusMessage = "Imported sessions."
            } catch {
                statusMessage = "Failed to import sessions: \(error.localizedDescription)"
            }
        }
    }

    private func importPasswords() {
        open { data in
            do {
                let payload = try JSONDecoder().decode(PasswordExport.self, from: data)
                pendingPasswordImport = payload
                masterPassword = ""
                showImportPasswordPrompt = true
            } catch {
                statusMessage = "Failed to import passwords: \(error.localizedDescription)"
            }
        }
    }

    private func handleExportPasswords() {
        let export = vault.exportPasswords(masterPassword: masterPassword)
        if let export {
            do {
                let data = try JSONEncoder().encode(export)
                save(data: data, defaultName: "openterm-passwords.json")
                statusMessage = "Exported passwords."
            } catch {
                statusMessage = "Failed to export passwords: \(error.localizedDescription)"
            }
        } else {
            statusMessage = "Failed to export passwords. Check master password."
        }
        masterPassword = ""
    }

    private func handleImportPasswords() {
        guard let payload = pendingPasswordImport else {
            showImportPasswordPrompt = false
            return
        }

        let wasUnlocked = vault.isUnlocked
        let success = vault.importPasswords(payload, masterPassword: masterPassword)
        if !wasUnlocked {
            vault.lock()
        }
        if success {
            statusMessage = "Imported passwords."
        } else {
            statusMessage = "Failed to import passwords. Check master password."
        }
        pendingPasswordImport = nil
        masterPassword = ""
    }

    private func save(data: Data, defaultName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = defaultName
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: [.atomic])
                statusMessage = "Exported to \(url.lastPathComponent)."
            } catch {
                statusMessage = "Failed to export: \(error.localizedDescription)"
            }
        }
    }

    private func open(onSelect: @escaping (Data) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                onSelect(data)
            } catch {
                statusMessage = "Failed to read file: \(error.localizedDescription)"
            }
        }
    }

    private func chooseLogDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            settings.logTerminalDirectory = url.path
        }
    }
}

private enum SettingsTab: String {
    case general
    case terminal
    case ssh
}

private struct MasterPasswordPrompt: View {
    let title: String
    @Binding var password: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            SecureField("Master password", text: $password)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Continue") {
                    dismiss()
                    onConfirm()
                }
                .disabled(password.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
