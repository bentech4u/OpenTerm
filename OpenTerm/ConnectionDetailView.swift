import SwiftUI
import AppKit

struct ConnectionDetailView: View {
    @Binding var connection: Connection
    @EnvironmentObject var store: ConnectionStore
    @EnvironmentObject var settings: SettingsStore
    @State private var showIconPicker = false
    @State private var showFontSheet = false
    @State private var showColorSheet = false
    @State private var portWasAuto = true
    @State private var isUpdatingPort = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                formSection
            }
            .padding(20)
        }
        .onAppear {
            portWasAuto = connection.port == connection.type.defaultPort
            if connection.type == .rdp {
                connection.authType = .password
            }
        }
        .onChange(of: connection.type) { _, newValue in
            if newValue == .rdp {
                connection.authType = .password
                connection.keyPath = ""
                connection.tcpKeepAliveSeconds = nil
                connection.x11Forwarding = nil
                connection.executeCommand = nil
                connection.executeDelaySeconds = nil
            }
            if portWasAuto {
                isUpdatingPort = true
                connection.port = newValue.defaultPort
                isUpdatingPort = false
            }
        }
        .onChange(of: connection.port) { _, newValue in
            if isUpdatingPort { return }
            portWasAuto = newValue == connection.type.defaultPort
        }
        .sheet(isPresented: $showIconPicker) {
            IconPickerView(selectedIcon: iconBinding)
        }
        .sheet(isPresented: $showFontSheet) {
            FontSettingsSheet(fontName: fontNameBinding, fontSize: fontSizeBinding, isBold: fontBoldBinding)
        }
        .sheet(isPresented: $showColorSheet) {
            ColorSettingsSheet(
                foreground: foregroundBinding,
                background: backgroundBinding
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(connection.name.isEmpty ? "New Connection" : connection.name)
                .font(.title2)
                .fontWeight(.semibold)
            Text(connection.type == .rdp ? "RDP" : "SSH and SFTP")
                .foregroundStyle(.secondary)
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection")
                .font(.headline)

            HStack(spacing: 12) {
                Text("Connection Type")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $connection.type) {
                    ForEach(ConnectionType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .labelsHidden()
                .frame(width: 160)

                Text("Port")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("", value: $connection.port, formatter: NumberFormatter())
                    .frame(width: 90)
            }

            HStack {
                TextField("Name", text: $connection.name)
                TextField("Host", text: $connection.host)
            }

            HStack {
                TextField("Username", text: $connection.username)
            }

            if connection.type == .ssh {
                HStack(spacing: 12) {
                    Text("Auth Type")
                        .font(.subheadline)
                    RadioButton(title: "Password", isSelected: connection.authType == .password) {
                        connection.authType = .password
                    }
                    RadioButton(title: "Pub Key", isSelected: connection.authType == .privateKey) {
                        connection.authType = .privateKey
                    }
                }
            }

            if connection.authType == .privateKey {
                TextField("Private key path", text: $connection.keyPath)
            }

            if connection.type == .rdp {
                Divider()
                Text("RDP Settings")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Display")
                        .font(.subheadline)
                    Picker("Display mode", selection: rdpDisplayModeBinding) {
                        ForEach(RdpDisplayMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .frame(width: 220)

                    if (connection.rdpDisplayMode == .fixed) {
                        HStack {
                            TextField("Width", value: rdpWidthBinding, formatter: NumberFormatter())
                                .frame(width: 100)
                            TextField("Height", value: rdpHeightBinding, formatter: NumberFormatter())
                                .frame(width: 100)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Local Resources")
                        .font(.subheadline)
                    Toggle("Clipboard", isOn: rdpClipboardBinding)
                    Picker("Sound", selection: rdpSoundModeBinding) {
                        ForEach(RdpSoundMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .frame(width: 160)
                    Toggle("Drive redirection", isOn: rdpDriveBinding)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Performance")
                        .font(.subheadline)
                    Picker("Profile", selection: $connection.rdpPerformanceProfile) {
                        ForEach(RdpPerformanceProfile.allCases) { profile in
                            Text(profile.displayName).tag(profile)
                        }
                    }
                    .frame(width: 220)
                    Text(connection.rdpPerformanceProfile.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Folder", selection: $connection.folderId) {
                Text("None").tag(UUID?.none)
                ForEach(store.topLevelFolders()) { folder in
                    Text(folder.name).tag(Optional(folder.id))
                }
            }

            TextField("Tags (comma separated)", text: tagsBinding)

            Text("Notes")
                .font(.subheadline)
            TextEditor(text: $connection.notes)
                .frame(minHeight: 100)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))

            Divider()

            Text("Appearance")
                .font(.headline)

            HStack(spacing: 12) {
                Image(systemName: connection.iconName ?? "terminal")
                    .font(.title2)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                Button("Choose Icon") {
                    showIconPicker = true
                }
            }

            Divider()

            if connection.type == .ssh {
                Text("Advanced SSH")
                    .font(.headline)

                Toggle("Enable X11 Forwarding", isOn: x11Binding)
                Text("Requires an X11 server on macOS (XQuartz).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("Execute command after login", text: executeCommandBinding)
                    Picker("Delay", selection: executeDelayBinding) {
                        ForEach(executeDelayOptions, id: \.self) { delay in
                            Text(delay == 0 ? "No delay" : "\(delay)s").tag(delay)
                        }
                    }
                    .frame(width: 140)
                }

                HStack {
                    Picker("Execute macro", selection: executeMacroBinding) {
                        Text("None").tag(UUID?.none)
                    }
                    .disabled(true)
                    Text("Macros coming soon")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if connection.type == .ssh {
                Divider()

                Text("Terminal Settings")
                    .font(.headline)

                HStack {
                    Text(fontSummary)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Choose Font…") {
                        showFontSheet = true
                    }
                }

                HStack {
                    Text("Colors")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Choose Colors…") {
                        showColorSheet = true
                    }
                }

                HStack {
                    TextField("Log output to (directory)", text: logPathBinding)
                    Button("Choose…") {
                        chooseLogDirectory()
                    }
                }
            }
        }
    }

    private var tagsBinding: Binding<String> {
        Binding(
            get: {
                connection.tags.joined(separator: ", ")
            },
            set: { value in
                connection.tags = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    private var iconBinding: Binding<String?> {
        Binding(
            get: { connection.iconName },
            set: { connection.iconName = $0 }
        )
    }

    private var x11Binding: Binding<Bool> {
        Binding(
            get: { connection.x11Forwarding ?? false },
            set: { connection.x11Forwarding = $0 }
        )
    }

    private var executeCommandBinding: Binding<String> {
        Binding(
            get: { connection.executeCommand ?? "" },
            set: { connection.executeCommand = $0 }
        )
    }

    private var executeDelayBinding: Binding<Int> {
        Binding(
            get: { connection.executeDelaySeconds ?? 0 },
            set: { connection.executeDelaySeconds = $0 }
        )
    }

    private var executeMacroBinding: Binding<UUID?> {
        Binding(
            get: { connection.executeMacroId },
            set: { connection.executeMacroId = $0 }
        )
    }

    private var fontNameBinding: Binding<String> {
        Binding(
            get: { connection.terminalFontName ?? settings.defaultTerminalFontName },
            set: { connection.terminalFontName = $0 == settings.defaultTerminalFontName ? nil : $0 }
        )
    }

    private var fontSizeBinding: Binding<Double> {
        Binding(
            get: { connection.terminalFontSize ?? settings.defaultTerminalFontSize },
            set: { connection.terminalFontSize = abs($0 - settings.defaultTerminalFontSize) < 0.01 ? nil : $0 }
        )
    }

    private var fontBoldBinding: Binding<Bool> {
        Binding(
            get: { connection.terminalFontBold ?? settings.defaultTerminalFontBold },
            set: { connection.terminalFontBold = $0 == settings.defaultTerminalFontBold ? nil : $0 }
        )
    }

    private var foregroundBinding: Binding<Color> {
        Binding(
            get: { ColorHex.toColor(connection.terminalForegroundHex ?? settings.defaultTerminalForegroundHex, fallback: .white) },
            set: {
                let hex = ColorHex.toHex($0)
                connection.terminalForegroundHex = hex == settings.defaultTerminalForegroundHex ? nil : hex
            }
        )
    }

    private var backgroundBinding: Binding<Color> {
        Binding(
            get: { ColorHex.toColor(connection.terminalBackgroundHex ?? settings.defaultTerminalBackgroundHex, fallback: .black) },
            set: {
                let hex = ColorHex.toHex($0)
                connection.terminalBackgroundHex = hex == settings.defaultTerminalBackgroundHex ? nil : hex
            }
        )
    }

    private var logPathBinding: Binding<String> {
        Binding(
            get: { connection.terminalLogPath ?? "" },
            set: { connection.terminalLogPath = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }

    private var fontSummary: String {
        let name = connection.terminalFontName ?? settings.defaultTerminalFontName
        let size = Int(connection.terminalFontSize ?? settings.defaultTerminalFontSize)
        let bold = (connection.terminalFontBold ?? settings.defaultTerminalFontBold) ? " Bold" : ""
        return "\(name) \(size)\(bold)"
    }

    private var executeDelayOptions: [Int] {
        [0, 1, 3, 5, 10, 30, 60]
    }

    private var rdpDisplayModeBinding: Binding<RdpDisplayMode> {
        Binding(
            get: { connection.rdpDisplayMode },
            set: { connection.rdpDisplayMode = $0 }
        )
    }

    private var rdpWidthBinding: Binding<Int> {
        Binding(
            get: { connection.rdpWidth },
            set: { connection.rdpWidth = max(320, $0) }
        )
    }

    private var rdpHeightBinding: Binding<Int> {
        Binding(
            get: { connection.rdpHeight },
            set: { connection.rdpHeight = max(240, $0) }
        )
    }

    private var rdpClipboardBinding: Binding<Bool> {
        Binding(
            get: { connection.rdpClipboardEnabled },
            set: { connection.rdpClipboardEnabled = $0 }
        )
    }

    private var rdpSoundModeBinding: Binding<RdpSoundMode> {
        Binding(
            get: { connection.rdpSoundMode },
            set: { connection.rdpSoundMode = $0 }
        )
    }

    private var rdpDriveBinding: Binding<Bool> {
        Binding(
            get: { connection.rdpDriveRedirectionEnabled },
            set: { connection.rdpDriveRedirectionEnabled = $0 }
        )
    }

    private func chooseLogDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            connection.terminalLogPath = url.path
        }
    }
}
