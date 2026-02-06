import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var store: ConnectionStore
    @EnvironmentObject var vault: PasswordVault
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: SettingsStore
    @StateObject private var sessionStore = SessionStore()

    @State private var sidebarTab: SidebarTab = .sessions
    @State private var showNewFolder = false
    @State private var showNewConnection = false
    @State private var editingConnection: EditingConnection?
    @State private var sidebarCollapsed = false

    @State private var pendingSftpSessionId: UUID?
    @State private var showSftpPasswordPrompt = false

    @State private var showRenamePrompt = false
    @State private var renameText = ""
    @State private var renamingConnectionId: UUID?

    @State private var showConnectAsPrompt = false
    @State private var connectAsUsername = ""
    @State private var connectAsConnection: Connection?

    @State private var showDeleteConfirmation = false
    @State private var deleteConnectionId: UUID?

    @State private var showVaultUnlockPrompt = false
    @State private var vaultUnlockPassword = ""
    @State private var vaultUnlockError: String?
    @State private var pendingOpenConnection: Connection?
    @State private var pendingRdpConnection: Connection?
    @State private var showRdpPasswordPrompt = false
    @State private var showUnsupportedAlert = false
    @State private var unsupportedMessage = ""

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                store: store,
                selectedTab: $sidebarTab,
                activeSession: sessionStore.activeTerminalSession,
                sshBrowserEnabled: settings.sshBrowserEnabled,
                isCollapsed: sidebarCollapsed,
                onToggleCollapse: { sidebarCollapsed.toggle() },
                onOpenConnection: openSession,
                onConnectAs: requestConnectAs,
                onRename: requestRename,
                onEditConnection: editConnection,
                onDelete: requestDelete,
                onDuplicate: duplicateConnection,
                onRequestSftpConnect: requestSftpConnect,
                onNewConnection: { showNewConnection = true },
                onNewFolder: { showNewFolder = true }
            )
            .frame(minWidth: sidebarCollapsed ? 52 : 260, idealWidth: sidebarCollapsed ? 56 : 280, maxWidth: sidebarCollapsed ? 72 : 320)

            Divider()

            SessionTabsView(sessionStore: sessionStore)
        }
        .onReceive(settings.objectWillChange) { _ in
            DispatchQueue.main.async {
                sessionStore.applySettings()
            }
        }
        .sheet(isPresented: $showNewFolder) {
            NewFolderSheet { folder in
                store.addFolder(folder)
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showNewConnection) {
            NewConnectionSheet { connection in
                store.addConnection(connection)
            }
            .environmentObject(store)
            .environmentObject(vault)
            .environmentObject(settings)
        }
        .sheet(item: $editingConnection) { item in
            NavigationStack {
                ConnectionDetailView(connection: store.bindingForConnection(id: item.id))
                    .environmentObject(store)
                    .environmentObject(settings)
                    .navigationTitle("Edit Connection")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                editingConnection = nil
                            }
                        }
                    }
            }
            .frame(minWidth: 520, minHeight: 480)
        }
        .sheet(isPresented: $showSftpPasswordPrompt) {
            if let session = pendingSftpSession {
                SftpPasswordPrompt(connection: session.connection, policy: settings.passwordSavePolicy) { password in
                    sessionStore.connectSftp(sessionId: session.id, password: password)
                    sidebarTab = .sftp
                    pendingSftpSessionId = nil
                } onCancel: {
                    pendingSftpSessionId = nil
                }
            }
        }
        .sheet(isPresented: $showRdpPasswordPrompt) {
            if let connection = pendingRdpConnection {
                RdpPasswordPrompt(connection: connection, policy: settings.passwordSavePolicy) { password in
                    openRdpSessionWithPassword(connection, password: password)
                } onCancel: {
                    pendingRdpConnection = nil
                }
            }
        }
        .sheet(isPresented: $showRenamePrompt) {
            RenamePrompt(name: $renameText) {
                applyRename()
            }
        }
        .sheet(isPresented: $showConnectAsPrompt) {
            ConnectAsPrompt(username: $connectAsUsername) {
                applyConnectAs()
            }
        }
        .sheet(isPresented: $appState.showPasswordManager) {
            PasswordManagerView()
                .environmentObject(store)
                .environmentObject(vault)
                .environmentObject(settings)
        }
        .sheet(isPresented: $appState.showSettings) {
            SettingsView()
                .environmentObject(store)
                .environmentObject(vault)
                .environmentObject(settings)
        }
        .sheet(isPresented: $showVaultUnlockPrompt) {
            VaultUnlockPrompt(password: $vaultUnlockPassword, errorMessage: $vaultUnlockError) {
                let success = vault.unlock(password: vaultUnlockPassword)
                if success {
                    vaultUnlockPassword = ""
                    vaultUnlockError = nil
                    showVaultUnlockPrompt = false
                    if let connection = pendingOpenConnection {
                        pendingOpenConnection = nil
                        openSessionDirect(connection)
                    }
                } else {
                    vaultUnlockError = "Invalid master password."
                }
            } onCancel: {
                pendingOpenConnection = nil
                showVaultUnlockPrompt = false
            }
        }
        .alert("Delete session?", isPresented: $showDeleteConfirmation, actions: {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                confirmDelete()
            }
        }, message: {
            Text("This will permanently remove the saved session.")
        })
        .alert("Connection type not supported", isPresented: $showUnsupportedAlert, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(unsupportedMessage)
        })
    }

    private func openSession(_ connection: Connection) {
        switch connection.type {
        case .ssh:
            if connection.authType == .password,
               vault.isConfigured,
               !vault.isUnlocked {
                pendingOpenConnection = connection
                showVaultUnlockPrompt = true
                return
            }
            openSessionDirect(connection)
        case .rdp:
            openRdpSession(connection)
        }
    }

    private func openSessionDirect(_ connection: Connection) {
        if connection.type != .ssh { return }
        let savedPassword = vault.isUnlocked ? vault.password(for: connection.id) : nil
        let session = sessionStore.open(connection: connection, sshPassword: savedPassword, settings: settings)
        if settings.sshBrowserEnabled {
            sidebarTab = .sftp
            if let sshSession = session.terminalSession {
                requestSftpConnect(sshSession)
            }
        } else {
            sidebarTab = .sessions
        }
    }

    private func openRdpSession(_ connection: Connection) {
        if vault.isUnlocked, let savedPassword = vault.password(for: connection.id), !savedPassword.isEmpty {
            openRdpSessionWithPassword(connection, password: savedPassword)
            return
        }
        pendingRdpConnection = connection
        showRdpPasswordPrompt = true
    }

    private func openRdpSessionWithPassword(_ connection: Connection, password: String) {
        pendingRdpConnection = nil
        _ = sessionStore.open(connection: connection, sshPassword: password, settings: settings)
        sidebarTab = .sessions
    }

    private func editConnection(_ connection: Connection) {
        editingConnection = EditingConnection(id: connection.id)
    }

    private func requestRename(_ connection: Connection) {
        renamingConnectionId = connection.id
        renameText = connection.displayName
        showRenamePrompt = true
    }

    private func applyRename() {
        guard let id = renamingConnectionId else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            store.renameConnection(id: id, newName: trimmed)
        }
        renamingConnectionId = nil
        showRenamePrompt = false
    }

    private func requestConnectAs(_ connection: Connection) {
        connectAsConnection = connection
        connectAsUsername = ""
        showConnectAsPrompt = true
    }

    private func applyConnectAs() {
        guard var connection = connectAsConnection else { return }
        let trimmed = connectAsUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        connection.username = trimmed
        connection.name = "\(connection.displayName) (\(trimmed))"
        openSession(connection)
        connectAsConnection = nil
        showConnectAsPrompt = false
    }

    private func requestDelete(_ connection: Connection) {
        deleteConnectionId = connection.id
        showDeleteConfirmation = true
    }

    private func confirmDelete() {
        guard let id = deleteConnectionId else { return }
        store.deleteConnection(id: id)
        deleteConnectionId = nil
    }

    private func duplicateConnection(_ connection: Connection) {
        _ = store.duplicateConnection(id: connection.id)
    }

    private func requestSftpConnect(_ session: TerminalSession) {
        guard settings.sshBrowserEnabled else { return }
        guard session.connection.type == .ssh else { return }
        if session.sftpManager.isConnected || session.sftpManager.isBusy {
            return
        }

        if session.connection.authType == .password {
            switch settings.passwordSavePolicy {
            case .never:
                if vault.isUnlocked, let saved = vault.password(for: session.connection.id) {
                    sessionStore.connectSftp(sessionId: session.id, password: saved)
                } else {
                    session.sftpManager.statusMessage = "No saved password available. Unlock the vault to connect."
                }
                return
            case .ask:
                pendingSftpSessionId = session.id
                showSftpPasswordPrompt = true
                return
            case .always:
                if vault.isUnlocked, let saved = vault.password(for: session.connection.id) {
                    sessionStore.connectSftp(sessionId: session.id, password: saved)
                    return
                }
                pendingSftpSessionId = session.id
                showSftpPasswordPrompt = true
                return
            }
        } else {
            sessionStore.connectSftp(sessionId: session.id, password: nil)
        }
    }

    private var pendingSftpSession: TerminalSession? {
        guard let id = pendingSftpSessionId else { return nil }
        return sessionStore.session(id: id)?.terminalSession
    }
}

private struct EditingConnection: Identifiable {
    let id: UUID
}

private struct RenamePrompt: View {
    @Binding var name: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename session")
                .font(.headline)

            TextField("Display name", text: $name)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    dismiss()
                    onSave()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

private struct ConnectAsPrompt: View {
    @Binding var username: String
    let onConnect: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect as…")
                .font(.headline)

            TextField("Username", text: $username)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Connect") {
                    dismiss()
                    onConnect()
                }
                .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

private struct VaultUnlockPrompt: View {
    @Binding var password: String
    @Binding var errorMessage: String?
    let onUnlock: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Unlock Password Manager")
                .font(.headline)
            SecureField("Master password", text: $password)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                    onCancel()
                }
                Spacer()
                Button("Unlock") {
                    onUnlock()
                }
                .disabled(password.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
    }
}

private struct SftpPasswordPrompt: View {
    let connection: Connection
    let policy: PasswordSavePolicy
    let onConnect: (String) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var vault: PasswordVault
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var saveToVault = true
    @State private var masterPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?

    init(connection: Connection, policy: PasswordSavePolicy, onConnect: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.connection = connection
        self.policy = policy
        self.onConnect = onConnect
        self.onCancel = onCancel
        _saveToVault = State(initialValue: policy != .ask)
    }

    private var savedPasswordAvailable: Bool {
        vault.isUnlocked && vault.password(for: connection.id) != nil
    }

    private var requiresSave: Bool {
        switch policy {
        case .always, .never:
            return true
        case .ask:
            return saveToVault
        }
    }

    private var canConnect: Bool {
        if requiresSave {
            if !vault.isConfigured {
                return !password.isEmpty && !masterPassword.isEmpty && !confirmPassword.isEmpty
            }
            if !vault.isUnlocked {
                return !masterPassword.isEmpty
            }
            return !password.isEmpty || savedPasswordAvailable
        }
        return !password.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect SFTP")
                .font(.headline)

            Text(connection.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SecureField("SSH password", text: $password)

            if policy == .ask {
                Toggle("Save in Password Manager", isOn: $saveToVault)
            } else {
                Text(policy == .never ? "Password Manager is required for this connection." : "Password will be saved automatically.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if requiresSave {
                if !vault.isConfigured {
                    SecureField("Master password", text: $masterPassword)
                    SecureField("Confirm master password", text: $confirmPassword)
                } else if !vault.isUnlocked {
                    SecureField("Master password", text: $masterPassword)
                    Text("Unlock the vault to use saved passwords or store a new one.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if savedPasswordAvailable {
                    Text("Saved password available. Leave the SSH password blank to use it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if policy == .ask, savedPasswordAvailable, vault.isUnlocked {
                Button("Use saved password") {
                    password = vault.password(for: connection.id) ?? ""
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                    onCancel()
                }
                Spacer()
                Button("Connect") {
                    handleConnect()
                }
                .disabled(!canConnect)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
    }

    private func handleConnect() {
        errorMessage = nil

        if requiresSave {
            if !vault.isConfigured {
                let success = vault.configureMasterPassword(password: masterPassword, confirm: confirmPassword)
                if !success {
                    errorMessage = "Master passwords do not match."
                    return
                }
            } else if !vault.isUnlocked {
                let success = vault.unlock(password: masterPassword)
                if !success {
                    errorMessage = "Invalid master password."
                    return
                }
            }
        }

        var finalPassword = password
        if finalPassword.isEmpty, requiresSave, vault.isUnlocked {
            finalPassword = vault.password(for: connection.id) ?? ""
        }

        guard !finalPassword.isEmpty else {
            errorMessage = "Enter the SSH password."
            return
        }

        if requiresSave && vault.isUnlocked {
            vault.storePassword(finalPassword, for: connection.id)
        }

        dismiss()
        onConnect(finalPassword)
    }
}

private struct RdpPasswordPrompt: View {
    let connection: Connection
    let policy: PasswordSavePolicy
    let onConnect: (String) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var vault: PasswordVault
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var saveToVault = true
    @State private var masterPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?

    init(connection: Connection, policy: PasswordSavePolicy, onConnect: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.connection = connection
        self.policy = policy
        self.onConnect = onConnect
        self.onCancel = onCancel
        _saveToVault = State(initialValue: policy != .ask ? true : false)
    }

    private var savedPasswordAvailable: Bool {
        vault.isUnlocked && vault.password(for: connection.id) != nil
    }

    private var requiresSave: Bool {
        switch policy {
        case .always, .never:
            return true
        case .ask:
            return saveToVault
        }
    }

    private var canConnect: Bool {
        if requiresSave {
            if !vault.isConfigured {
                return !password.isEmpty && !masterPassword.isEmpty && !confirmPassword.isEmpty
            }
            if !vault.isUnlocked {
                return !masterPassword.isEmpty
            }
            return !password.isEmpty || savedPasswordAvailable
        }
        return !password.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect RDP")
                .font(.headline)

            Text(connection.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SecureField("RDP password", text: $password)

            if policy == .ask {
                Toggle("Save in Password Manager", isOn: $saveToVault)
            } else {
                Text(policy == .never ? "Password Manager is required for this connection." : "Password will be saved automatically.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if requiresSave {
                if !vault.isConfigured {
                    SecureField("Master password", text: $masterPassword)
                    SecureField("Confirm master password", text: $confirmPassword)
                } else if !vault.isUnlocked {
                    SecureField("Master password", text: $masterPassword)
                    Text("Unlock the vault to use saved passwords or store a new one.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if savedPasswordAvailable {
                    Text("Saved password available. Leave the RDP password blank to use it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if policy == .ask, savedPasswordAvailable, vault.isUnlocked {
                Button("Use saved password") {
                    password = vault.password(for: connection.id) ?? ""
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                    onCancel()
                }
                Spacer()
                Button("Connect") {
                    handleConnect()
                }
                .disabled(!canConnect)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
    }

    private func handleConnect() {
        errorMessage = nil

        if requiresSave {
            if !vault.isConfigured {
                let success = vault.configureMasterPassword(password: masterPassword, confirm: confirmPassword)
                if !success {
                    errorMessage = "Master passwords do not match."
                    return
                }
            } else if !vault.isUnlocked {
                let success = vault.unlock(password: masterPassword)
                if !success {
                    errorMessage = "Invalid master password."
                    return
                }
            }
        }

        var finalPassword = password
        if finalPassword.isEmpty, requiresSave, vault.isUnlocked {
            finalPassword = vault.password(for: connection.id) ?? ""
        }

        guard !finalPassword.isEmpty else {
            errorMessage = "Enter the RDP password."
            return
        }

        if requiresSave && vault.isUnlocked {
            vault.storePassword(finalPassword, for: connection.id)
        }

        dismiss()
        onConnect(finalPassword)
    }
}

private struct NewFolderSheet: View {
    @EnvironmentObject var store: ConnectionStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var parentId: UUID?

    let onCreate: (Folder) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Folder")
                .font(.headline)

            TextField("Name", text: $name)

            Picker("Parent", selection: $parentId) {
                Text("None").tag(UUID?.none)
                ForEach(store.topLevelFolders()) { folder in
                    Text(folder.name).tag(Optional(folder.id))
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Create") {
                    let folder = Folder(name: name.trimmingCharacters(in: .whitespacesAndNewlines), parentId: parentId)
                    onCreate(folder)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

private struct NewConnectionSheet: View {
    @EnvironmentObject var store: ConnectionStore
    @EnvironmentObject var vault: PasswordVault
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var host = ""
    @State private var username = ""
    @State private var connectionType: ConnectionType = .ssh
    @State private var port = ConnectionType.ssh.defaultPort
    @State private var authType: AuthType = .password
    @State private var keyPath = ""
    @State private var folderId: UUID?
    @State private var password = ""
    @State private var masterPassword = ""
    @State private var confirmPassword = ""
    @State private var unlockPassword = ""
    @State private var errorMessage: String?
    @State private var iconName: String?
    @State private var showIconPicker = false
    @State private var x11Forwarding = false
    @State private var executeCommand = ""
    @State private var executeDelaySeconds = 0
    @State private var portWasAuto = true
    @State private var isUpdatingPort = false
    @State private var rdpDisplayMode: RdpDisplayMode = .fitToWindow
    @State private var rdpWidth = 1280
    @State private var rdpHeight = 720
    @State private var rdpClipboardEnabled = true
    @State private var rdpSoundMode: RdpSoundMode = .off
    @State private var rdpDriveRedirectionEnabled = false

    let onCreate: (Connection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Connection")
                .font(.headline)

            HStack(spacing: 12) {
                Button {
                    showIconPicker = true
                } label: {
                    Image(systemName: iconName ?? "terminal")
                        .font(.title2)
                        .frame(width: 32, height: 32)
                        .background(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection Type")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $connectionType) {
                        ForEach(ConnectionType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Port")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("", value: $port, formatter: NumberFormatter())
                        .frame(width: 90)
                }
            }

            TextField("Name", text: $name)
            TextField("Host", text: $host)

            if connectionType == .rdp {
                HStack {
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)
                }
            } else {
                TextField("Username", text: $username)
            }

            if connectionType == .ssh {
                HStack(spacing: 12) {
                    Text("Auth Type")
                        .font(.subheadline)
                    RadioButton(title: "Password", isSelected: authType == .password) {
                        authType = .password
                    }
                    RadioButton(title: "Pub Key", isSelected: authType == .privateKey) {
                        authType = .privateKey
                    }
                }
            }

            if connectionType == .rdp {
                Divider()
                Text("RDP Settings")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Display")
                        .font(.subheadline)
                    Picker("Display mode", selection: $rdpDisplayMode) {
                        ForEach(RdpDisplayMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .frame(width: 220)

                    if rdpDisplayMode == .fixed {
                        HStack {
                            TextField("Width", value: $rdpWidth, formatter: NumberFormatter())
                                .frame(width: 100)
                            TextField("Height", value: $rdpHeight, formatter: NumberFormatter())
                                .frame(width: 100)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Local Resources")
                        .font(.subheadline)
                    Toggle("Clipboard", isOn: $rdpClipboardEnabled)
                    Picker("Sound", selection: $rdpSoundMode) {
                        ForEach(RdpSoundMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .frame(width: 160)
                    Toggle("Drive redirection", isOn: $rdpDriveRedirectionEnabled)
                }
            }

            if connectionType == .ssh {
                if authType == .privateKey {
                    TextField("Private key path", text: $keyPath)
                }
            }

            if authType == .password && connectionType == .ssh {
                SecureField("Password", text: $password)
            }

            if authType == .password {
                if !vault.isConfigured {
                    Text("Password vault not configured. Set a master password to save this password.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    SecureField("Master password", text: $masterPassword)
                    SecureField("Confirm master password", text: $confirmPassword)
                } else if !vault.isUnlocked {
                    Text("Unlock the password vault to save this password.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    SecureField("Master password", text: $unlockPassword)
                }
            }

            Divider()

            if connectionType == .ssh {
                Text("Advanced SSH")
                    .font(.headline)
                Toggle("Enable X11 Forwarding", isOn: $x11Forwarding)
                HStack {
                    TextField("Execute command after login", text: $executeCommand)
                    Picker("Delay", selection: $executeDelaySeconds) {
                        ForEach([0, 1, 3, 5, 10, 30, 60], id: \.self) { delay in
                            Text(delay == 0 ? "No delay" : "\(delay)s").tag(delay)
                        }
                    }
                    .frame(width: 140)
                }
            }

            Picker("Folder", selection: $folderId) {
                Text("None").tag(UUID?.none)
                ForEach(store.topLevelFolders()) { folder in
                    Text(folder.name).tag(Optional(folder.id))
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Create") {
                    errorMessage = nil
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedKey = keyPath.trimmingCharacters(in: .whitespacesAndNewlines)

                    if authType == .password {
                        guard !password.isEmpty else {
                            errorMessage = "Password is required."
                            return
                        }

                        if !vault.isConfigured {
                            let ok = vault.configureMasterPassword(password: masterPassword, confirm: confirmPassword)
                            if !ok {
                                errorMessage = "Master passwords do not match."
                                return
                            }
                        } else if !vault.isUnlocked {
                            let ok = vault.unlock(password: unlockPassword)
                            if !ok {
                                errorMessage = "Invalid master password."
                                return
                            }
                        }
                    }

                    let connection = Connection(
                        type: connectionType,
                        name: trimmedName,
                        host: trimmedHost,
                        port: port,
                        username: trimmedUser,
                        authType: authType,
                        keyPath: trimmedKey,
                        tcpKeepAliveSeconds: nil,
                        folderId: folderId,
                        iconName: iconName,
                        x11Forwarding: connectionType == .ssh ? x11Forwarding : nil,
                        executeCommand: connectionType == .ssh ? executeCommand.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                        executeDelaySeconds: connectionType == .ssh ? executeDelaySeconds : nil,
                        rdpDisplayMode: rdpDisplayMode,
                        rdpWidth: rdpWidth,
                        rdpHeight: rdpHeight,
                        rdpClipboardEnabled: rdpClipboardEnabled,
                        rdpSoundMode: rdpSoundMode,
                        rdpDriveRedirectionEnabled: rdpDriveRedirectionEnabled
                    )
                    onCreate(connection)

                    if authType == .password, vault.isUnlocked {
                        vault.storePassword(password, for: connection.id)
                    }

                    dismiss()
                }
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    (authType == .password && password.isEmpty)
                )
            }
        }
        .padding(24)
        .frame(width: 400)
        .sheet(isPresented: $showIconPicker) {
            IconPickerView(selectedIcon: $iconName)
        }
        .onAppear {
            port = connectionType.defaultPort
            portWasAuto = true
            if connectionType == .rdp {
                authType = .password
            }
        }
        .onChange(of: connectionType) { _, newValue in
            if newValue == .rdp {
                authType = .password
            }
            if portWasAuto {
                isUpdatingPort = true
                port = newValue.defaultPort
                isUpdatingPort = false
            }
        }
        .onChange(of: port) { _, newValue in
            if isUpdatingPort { return }
            portWasAuto = newValue == connectionType.defaultPort
        }
    }
}
