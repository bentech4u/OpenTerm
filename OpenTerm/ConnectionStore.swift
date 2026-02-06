import Foundation
import SwiftUI
import Combine

@MainActor
final class ConnectionStore: ObservableObject {
    @Published private(set) var folders: [Folder] = []
    @Published private(set) var connections: [Connection] = []
    @Published private(set) var revision: Int = 0

    init() {
        load()
    }

    func folder(id: UUID) -> Folder? {
        folders.first { $0.id == id }
    }

    func connection(id: UUID) -> Connection? {
        connections.first { $0.id == id }
    }

    func bindingForConnection(id: UUID) -> Binding<Connection> {
        Binding(
            get: { [weak self] in
                self?.connections.first(where: { $0.id == id }) ?? Connection(name: "", host: "", username: "")
            },
            set: { [weak self] updated in
                guard let self else { return }
                if let index = self.connections.firstIndex(where: { $0.id == id }) {
                    self.connections[index] = updated
                    self.save()
                }
            }
        )
    }

    func bindingForFolder(id: UUID) -> Binding<Folder> {
        Binding(
            get: { [weak self] in
                self?.folders.first(where: { $0.id == id }) ?? Folder(name: "")
            },
            set: { [weak self] updated in
                guard let self else { return }
                if let index = self.folders.firstIndex(where: { $0.id == id }) {
                    self.folders[index] = updated
                    self.save()
                }
            }
        )
    }

    func addFolder(_ folder: Folder) {
        folders.append(folder)
        save()
        bumpRevision()
    }

    func deleteFolder(id: UUID) {
        folders.removeAll { $0.id == id }
        connections = connections.map { connection in
            var updated = connection
            if connection.folderId == id {
                updated.folderId = nil
            }
            return updated
        }
        save()
        bumpRevision()
    }

    func addConnection(_ connection: Connection) {
        connections.append(connection)
        save()
        bumpRevision()
    }

    func replaceData(_ data: AppData) {
        folders = data.folders
        connections = data.connections
        save()
        bumpRevision()
    }

    func deleteConnection(id: UUID) {
        connections.removeAll { $0.id == id }
        save()
        bumpRevision()
    }

    func moveConnection(_ connectionId: UUID, to folderId: UUID?) {
        guard let index = connections.firstIndex(where: { $0.id == connectionId }) else { return }
        connections[index].folderId = folderId
        save()
        bumpRevision()
    }

    func renameConnection(id: UUID, newName: String) {
        guard let index = connections.firstIndex(where: { $0.id == id }) else { return }
        connections[index].name = newName
        save()
        bumpRevision()
    }

    func duplicateConnection(id: UUID) -> Connection? {
        guard let existing = connections.first(where: { $0.id == id }) else { return nil }
        var copy = existing
        copy.id = UUID()
        copy.name = uniqueCopyName(for: existing.displayName)
        connections.append(copy)
        save()
        bumpRevision()
        return copy
    }

    func connections(in folderId: UUID?) -> [Connection] {
        connections.filter { $0.folderId == folderId }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func topLevelFolders() -> [Folder] {
        folders.filter { $0.parentId == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func save() {
        do {
            let data = AppData(folders: folders, connections: connections)
            try JSONStore.save(data)
        } catch {
            NSLog("Failed to save data: \(error)")
        }
    }

    private func bumpRevision() {
        revision += 1
    }

    private func uniqueCopyName(for base: String) -> String {
        let trimmed = base.isEmpty ? "Session" : base
        let initial = "\(trimmed) Copy"
        if !connections.contains(where: { $0.displayName == initial }) {
            return initial
        }
        var index = 2
        while connections.contains(where: { $0.displayName == "\(initial) \(index)" }) {
            index += 1
        }
        return "\(initial) \(index)"
    }

    private func load() {
        do {
            if let data = try JSONStore.load() {
                folders = data.folders
                connections = data.connections
            } else {
                seedSampleData()
            }
        } catch {
            NSLog("Failed to load data: \(error)")
            seedSampleData()
        }
    }

    private func seedSampleData() {
        let servers = Folder(name: "Servers")
        let dev = Folder(name: "Development")
        let sample = Connection(name: "Example SSH", host: "example.com", username: "user", folderId: servers.id)
        folders = [servers, dev]
        connections = [sample]
        save()
    }
}

enum JSONStore {
    static func load() throws -> AppData? {
        let url = try dataURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AppData.self, from: data)
    }

    static func save(_ data: AppData) throws {
        let url = try dataURL()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let payload = try encoder.encode(data)
        try payload.write(to: url, options: [.atomic])
    }

    private static func dataURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent("OpenTerm", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("connections.json")
    }
}
