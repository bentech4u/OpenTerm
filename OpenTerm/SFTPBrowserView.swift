import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct SFTPBrowserView: View {
    let connection: Connection
    @ObservedObject var manager: SFTPManager
    let isCompact: Bool
    let onConnectRequested: (() -> Void)?
    let onDisconnectRequested: (() -> Void)?

    @State private var showUploadPicker = false
    @State private var showNewFolderPrompt = false
    @State private var showNewFilePrompt = false
    @State private var newFolderName = ""
    @State private var newFileName = ""

    init(
        connection: Connection,
        manager: SFTPManager,
        isCompact: Bool = false,
        onConnectRequested: (() -> Void)? = nil,
        onDisconnectRequested: (() -> Void)? = nil
    ) {
        self.connection = connection
        self.manager = manager
        self.isCompact = isCompact
        self.onConnectRequested = onConnectRequested
        self.onDisconnectRequested = onDisconnectRequested
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let status = manager.statusMessage {
                Text(status)
                    .foregroundStyle(.red)
            }

            if manager.isBusy {
                ProgressView()
            }

            List(manager.entries) { entry in
                HStack {
                    Image(systemName: entry.isDirectory ? "folder" : "doc")
                        .foregroundStyle(entry.isDirectory ? .secondary : .primary)
                    Text(entry.name)
                    Spacer()
                    if let size = entry.size, !entry.isDirectory {
                        Text("\(size) bytes")
                            .foregroundStyle(.secondary)
                    }
                    if !isCompact {
                        Button("Download") {
                            download(entry)
                        }
                        .buttonStyle(.link)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    if entry.isDirectory {
                        manager.changeDirectory(to: entry.name)
                    }
                }
                .contextMenu {
                    if entry.isDirectory {
                        Button("Open") {
                            manager.changeDirectory(to: entry.name)
                        }
                    }
                    Button("Download") {
                        download(entry)
                    }
                }
            }
            .frame(minHeight: isCompact ? 240 : 200)
        }
        .fileImporter(isPresented: $showUploadPicker, allowedContentTypes: [.item]) { result in
            switch result {
            case .success(let url):
                manager.upload(localURL: url)
            case .failure(let error):
                manager.statusMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showNewFolderPrompt) {
            NamePrompt(title: "New Folder", placeholder: "Folder name", name: $newFolderName) {
                manager.createDirectory(named: newFolderName)
                newFolderName = ""
            }
        }
        .sheet(isPresented: $showNewFilePrompt) {
            NamePrompt(title: "New File", placeholder: "File name", name: $newFileName) {
                manager.createFile(named: newFileName)
                newFileName = ""
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Remote path", text: $manager.currentPath)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        manager.changeDirectory(to: manager.currentPath)
                    }

                Button(action: { manager.goUpDirectory() }) {
                    Image(systemName: "arrow.up")
                }
                .disabled(!manager.isConnected)

                Button(action: { manager.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(!manager.isConnected)

                Button(manager.isConnected ? "Disconnect" : "Connect") {
                    handleConnectTap()
                }
                .disabled(manager.isBusy)
            }

            HStack(spacing: 10) {
                Button(action: { showNewFolderPrompt = true }) {
                    Image(systemName: "folder.badge.plus")
                }
                .disabled(!manager.isConnected)

                Button(action: { showNewFilePrompt = true }) {
                    Image(systemName: "doc.badge.plus")
                }
                .disabled(!manager.isConnected)

                Button(action: { showUploadPicker = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(!manager.isConnected)

                Spacer()
            }
        }
    }

    private func handleConnectTap() {
        if manager.isConnected {
            if let onDisconnectRequested {
                onDisconnectRequested()
            } else {
                manager.disconnect()
            }
            return
        }

        if let onConnectRequested {
            onConnectRequested()
        } else {
            manager.connect(connection: connection, password: nil)
        }
    }

    private func download(_ entry: RemoteEntry) {
        if entry.isDirectory {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                let target = url.appendingPathComponent(entry.name)
                manager.downloadDirectory(entry: entry, to: target)
            }
        } else {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = entry.name
            panel.canCreateDirectories = true
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                manager.download(entry: entry, to: url)
            }
        }
    }
}

private struct NamePrompt: View {
    let title: String
    let placeholder: String
    @Binding var name: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            TextField(placeholder, text: $name)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Create") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        name = trimmed
                        dismiss()
                        onSave()
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
