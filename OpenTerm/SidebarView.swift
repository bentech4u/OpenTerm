import SwiftUI
import UniformTypeIdentifiers

enum SidebarTab: String, CaseIterable, Identifiable {
    case sessions = "Sessions"
    case sftp = "SFTP"
    case tools = "Tools"
    case macros = "Macros"

    var id: String { rawValue }
}

struct SidebarView: View {
    @ObservedObject var store: ConnectionStore
    @Binding var selectedTab: SidebarTab
    let activeSession: TerminalSession?
    let sshBrowserEnabled: Bool
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    let onOpenConnection: (Connection) -> Void
    let onConnectAs: (Connection) -> Void
    let onRename: (Connection) -> Void
    let onEditConnection: (Connection) -> Void
    let onDelete: (Connection) -> Void
    let onDuplicate: (Connection) -> Void
    let onRequestSftpConnect: (TerminalSession) -> Void
    let onNewConnection: () -> Void
    let onNewFolder: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            header
            if isCollapsed {
                collapsedTabs
                Spacer()
            } else {
                Picker("", selection: $selectedTab) {
                    ForEach(SidebarTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                Divider()

                switch selectedTab {
                case .sessions:
                    sessionsList
                case .sftp:
                    if sshBrowserEnabled {
                        sftpPanel
                    } else {
                        placeholder("SSH browser is disabled in Settings")
                    }
                case .tools:
                    placeholder("Tools coming soon")
                case .macros:
                    placeholder("Macros coming soon")
                }
            }
        }
        .padding(12)
    }

    private var header: some View {
        HStack {
            if !isCollapsed {
                Text("OpenTerm")
                    .font(.headline)
                Spacer()
                Button {
                    onNewFolder()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .buttonStyle(.borderless)

                Button {
                    onNewConnection()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            } else {
                Button(action: onToggleCollapse) {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            if !isCollapsed {
                Button(action: onToggleCollapse) {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var collapsedTabs: some View {
        VStack(spacing: 12) {
            ForEach(SidebarTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Image(systemName: icon(for: tab))
                        .font(.title3)
                        .frame(width: 28, height: 28)
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
                .help(tab.rawValue)
            }

            Divider()

            Button(action: onNewFolder) {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(.plain)
            .help("New Folder")

            Button(action: onNewConnection) {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .help("New Connection")
        }
        .frame(maxWidth: .infinity)
    }

    private func icon(for tab: SidebarTab) -> String {
        switch tab {
        case .sessions:
            return "list.bullet"
        case .sftp:
            return "folder"
        case .tools:
            return "wrench"
        case .macros:
            return "bolt"
        }
    }

    private var sessionsList: some View {
        List {
            Section {
                ForEach(store.connections(in: nil)) { connection in
                    ConnectionRow(
                        connection: connection,
                        onOpen: onOpenConnection,
                        onConnectAs: onConnectAs,
                        onRename: onRename,
                        onEdit: onEditConnection,
                        onDelete: onDelete,
                        onDuplicate: onDuplicate
                    )
                }
            } header: {
                DropHeader(title: "Ungrouped") { providers in
                    handleDrop(providers: providers, folderId: nil)
                }
            }

            Section("Folders") {
                ForEach(store.topLevelFolders()) { folder in
                    DisclosureGroup {
                        ForEach(store.connections(in: folder.id)) { connection in
                            ConnectionRow(
                                connection: connection,
                                onOpen: onOpenConnection,
                                onConnectAs: onConnectAs,
                                onRename: onRename,
                                onEdit: onEditConnection,
                                onDelete: onDelete,
                                onDuplicate: onDuplicate
                            )
                        }
                    } label: {
                        DropHeader(title: folder.name, showFolderIcon: true) { providers in
                            handleDrop(providers: providers, folderId: folder.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .id(store.revision)
        .frame(maxHeight: .infinity)
    }

    private var sftpPanel: some View {
        Group {
            if let session = activeSession {
                SFTPBrowserView(
                    connection: session.connection,
                    manager: session.sftpManager,
                    isCompact: true,
                    onConnectRequested: { onRequestSftpConnect(session) }
                )
            } else {
                placeholder("Open a session to browse files")
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func placeholder(_ text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "sidebar.left")
                .font(.title2)
            Text(text)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleDrop(providers: [NSItemProvider], folderId: UUID?) -> Bool {
        let type = UTType.text.identifier
        for provider in providers where provider.hasItemConformingToTypeIdentifier(type) {
            _ = provider.loadObject(ofClass: NSString.self) { item, _ in
                guard let value = item as? String, let id = UUID(uuidString: value) else { return }
                DispatchQueue.main.async {
                    store.moveConnection(id, to: folderId)
                }
            }
            return true
        }
        return false
    }
}

private struct ConnectionRow: View {
    let connection: Connection
    let onOpen: (Connection) -> Void
    let onConnectAs: (Connection) -> Void
    let onRename: (Connection) -> Void
    let onEdit: (Connection) -> Void
    let onDelete: (Connection) -> Void
    let onDuplicate: (Connection) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: connection.iconName ?? "terminal")
            Text(connection.displayName)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onOpen(connection)
        }
        .onDrag {
            NSItemProvider(object: connection.id.uuidString as NSString)
        }
        .contextMenu {
            Button("Execute") {
                onOpen(connection)
            }
            Button("Connect as…") {
                onConnectAs(connection)
            }
            Divider()
            Button("Rename session") {
                onRename(connection)
            }
            Button("Edit") {
                onEdit(connection)
            }
            Button("Delete") {
                onDelete(connection)
            }
            Button("Duplicate session") {
                onDuplicate(connection)
            }
        }
    }
}

private struct DropHeader: View {
    let title: String
    var showFolderIcon: Bool = false
    let onDrop: ([NSItemProvider]) -> Bool
    @State private var isTargeted = false

    var body: some View {
        HStack(spacing: 6) {
            if showFolderIcon {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(isTargeted ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .onDrop(of: [UTType.text], isTargeted: $isTargeted, perform: onDrop)
    }
}
