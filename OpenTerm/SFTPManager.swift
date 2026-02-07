import Foundation
import Combine
#if canImport(Shout)
import Shout
#endif

enum SFTPError: Error, LocalizedError {
    case notConnected
    case fileNotFound
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "SFTP is not connected"
        case .fileNotFound:
            return "File not found"
        case .uploadFailed:
            return "Upload failed"
        }
    }
}

#if canImport(Shout)
@MainActor
final class SFTPManager: ObservableObject {
    @Published var isConnected = false
    @Published var isBusy = false
    @Published var currentPath: String = "~"
    @Published var entries: [RemoteEntry] = []
    @Published var statusMessage: String?

    private var session: SSH?
    private var sftp: SFTP?

    func connect(connection: Connection, password: String?) {
        statusMessage = nil
        isBusy = true
        let path = currentPath

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let ssh = try SSH(host: connection.host, port: Int32(connection.port))

                switch connection.authType {
                case .password:
                    let passwordValue = password ?? ""
                    try ssh.authenticate(username: connection.username, password: passwordValue)
                case .privateKey:
                    let keyPath = connection.keyPath.isEmpty ? "~/.ssh/id_rsa" : connection.keyPath
                    try ssh.authenticate(username: connection.username, privateKey: keyPath)
                }

                let sftp = try ssh.openSftp()
                let listing = try Self.fetchListing(sftp: sftp, path: path, currentPath: path)

                DispatchQueue.main.async {
                    self.session = ssh
                    self.sftp = sftp
                    self.entries = listing
                    self.currentPath = Self.resolvePath(path)
                    self.isConnected = true
                    self.isBusy = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = error.localizedDescription
                    self.isConnected = false
                    self.isBusy = false
                }
            }
        }
    }

    func disconnect() {
        session = nil
        sftp = nil
        entries = []
        statusMessage = nil
        isConnected = false
        isBusy = false
    }

    func refresh() {
        guard let sftp else {
            statusMessage = "SFTP is not connected."
            return
        }
        isBusy = true
        let path = currentPath

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let listing = try Self.fetchListing(sftp: sftp, path: path, currentPath: path)
                DispatchQueue.main.async {
                    self.entries = listing
                    self.isBusy = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = error.localizedDescription
                    self.isBusy = false
                }
            }
        }
    }

    func upload(localURL: URL) {
        guard let sftp else { return }
        isBusy = true
        let remote = remotePath(for: localURL.lastPathComponent)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                do {
                    try sftp.upload(localURL: localURL, remotePath: remote)
                } catch {
                    if let ssh = self.session {
                        _ = try ssh.sendFile(localURL: localURL, remotePath: remote)
                    } else {
                        throw error
                    }
                }
                DispatchQueue.main.async {
                    self.isBusy = false
                    self.refresh()
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = error.localizedDescription
                    self.isBusy = false
                }
            }
        }
    }

    func download(entry: RemoteEntry, to localURL: URL) {
        guard let sftp else { return }
        isBusy = true
        let remote = remotePath(for: entry.name)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try sftp.download(remotePath: remote, localURL: localURL)
                DispatchQueue.main.async {
                    self.isBusy = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = error.localizedDescription
                    self.isBusy = false
                }
            }
        }
    }

    func downloadDirectory(entry: RemoteEntry, to localURL: URL) {
        guard let sftp else { return }
        isBusy = true
        let remoteRoot = remotePath(for: entry.name)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try FileManager.default.createDirectory(at: localURL, withIntermediateDirectories: true)
                try Self.downloadDirectory(
                    sftp: sftp,
                    remotePath: remoteRoot,
                    localURL: localURL
                )
                DispatchQueue.main.async {
                    self.isBusy = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = error.localizedDescription
                    self.isBusy = false
                }
            }
        }
    }

    func changeDirectory(to path: String) {
        guard let sftp else {
            statusMessage = "SFTP is not connected."
            return
        }
        isBusy = true
        let basePath = currentPath
        let target = Self.normalizePath(path, currentPath: basePath)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let listing = try Self.fetchListing(sftp: sftp, path: target, currentPath: basePath)
                DispatchQueue.main.async {
                    self.entries = listing
                    self.currentPath = target
                    self.isBusy = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = error.localizedDescription
                    self.isBusy = false
                }
            }
        }
    }

    func goUpDirectory() {
        let base = Self.resolvePath(currentPath)
        if base == "." || base == "/" {
            return
        }
        let parent = (base as NSString).deletingLastPathComponent
        let target = parent.isEmpty ? "/" : parent
        changeDirectory(to: target)
    }

    func createDirectory(named name: String) {
        guard let sftp else { return }
        isBusy = true
        let remote = remotePath(for: name)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try sftp.createDirectory(remote)
                DispatchQueue.main.async {
                    self.isBusy = false
                    self.refresh()
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = error.localizedDescription
                    self.isBusy = false
                }
            }
        }
    }

    func createFile(named name: String) {
        guard let sftp else { return }
        isBusy = true
        let remote = remotePath(for: name)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                do {
                    try sftp.upload(data: Data(), remotePath: remote)
                } catch {
                    if let ssh = self.session {
                        let escaped = Self.shellEscape(remote)
                        _ = try ssh.execute("touch \(escaped)", silent: true)
                    } else {
                        throw error
                    }
                }
                DispatchQueue.main.async {
                    self.isBusy = false
                    self.refresh()
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = error.localizedDescription
                    self.isBusy = false
                }
            }
        }
    }

    /// Download file content directly to memory (no temp file)
    func downloadToMemory(entry: RemoteEntry, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let sftp else {
            completion(.failure(SFTPError.notConnected))
            return
        }
        isBusy = true
        let remote = remotePath(for: entry.name)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Self.downloadFileToData(sftp: sftp, remotePath: remote)
                DispatchQueue.main.async {
                    self.isBusy = false
                    completion(.success(data))
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = error.localizedDescription
                    self.isBusy = false
                    completion(.failure(error))
                }
            }
        }
    }

    /// Upload content from memory directly to remote file
    func uploadFromMemory(data: Data, remotePath: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let ssh = session else {
            completion(.failure(SFTPError.notConnected))
            return
        }
        isBusy = true
        let rawPath = self.remotePath(for: remotePath)
        // Normalize path - strip "./" prefix as some SFTP servers don't handle it well
        let fullPath = rawPath.hasPrefix("./") ? String(rawPath.dropFirst(2)) : rawPath

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Use SSH command with base64 to write file - most reliable method
                let base64Content = data.base64EncodedString()
                let escapedPath = Self.shellEscape(fullPath)
                let command = "echo '\(base64Content)' | base64 -d > \(escapedPath)"
                _ = try ssh.execute(command)

                DispatchQueue.main.async {
                    self.isBusy = false
                    self.refresh()
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = error.localizedDescription
                    self.isBusy = false
                    completion(.failure(error))
                }
            }
        }
    }

    private static func downloadFileToData(sftp: SFTP, remotePath: String) throws -> Data {
        // Create a temporary URL for download, then read into memory
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }
        // Normalize path - strip "./" prefix as some SFTP servers don't handle it well
        let normalizedPath = remotePath.hasPrefix("./") ? String(remotePath.dropFirst(2)) : remotePath
        try sftp.download(remotePath: normalizedPath, localURL: tempFile)
        return try Data(contentsOf: tempFile)
    }

    private func remotePath(for name: String) -> String {
        // Already a full/absolute path - don't modify
        if name.hasPrefix("/") {
            return name
        }
        // Already a relative path from current directory - don't prepend again
        if name.hasPrefix("./") || name.hasPrefix("../") || name == "." || name == ".." {
            return name
        }
        // Tilde paths are home-relative - don't modify
        if name.hasPrefix("~") {
            return name
        }
        // Relative name - prepend current path
        let base = Self.resolvePath(currentPath)
        if base.hasSuffix("/") {
            return base + name
        }
        return base + "/" + name
    }

    private static func fetchListing(sftp: SFTP, path: String, currentPath: String) throws -> [RemoteEntry] {
        let resolved = normalizePath(path, currentPath: currentPath)
        let files = try sftp.listFiles(in: resolved)
        return files.compactMap { name, attributes in
            if name == "." || name == ".." { return nil }
            let isDirectory = attributes.fileType == .directory
            let size = Int(exactly: attributes.size)
            return RemoteEntry(name: name, isDirectory: isDirectory, size: size, rawLine: name)
        }
        .sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func resolvePath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "~" {
            return "."
        }
        return trimmed
    }

    private static func normalizePath(_ path: String, currentPath: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return resolvePath(currentPath)
        }
        let base = resolvePath(currentPath)
        if trimmed == base {
            return base
        }
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            return resolvePath(trimmed)
        }
        if trimmed == "." || trimmed == ".." || trimmed.hasPrefix("./") || trimmed.hasPrefix("../") {
            return resolvePath(trimmed)
        }
        if base == "." {
            return trimmed
        }
        if base.hasSuffix("/") {
            return base + trimmed
        }
        return base + "/" + trimmed
    }

    private static func shellEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    private static func downloadDirectory(sftp: SFTP, remotePath: String, localURL: URL) throws {
        let files = try sftp.listFiles(in: remotePath)
        for (name, attributes) in files {
            if name == "." || name == ".." { continue }
            let childRemote = remotePath.hasSuffix("/") ? remotePath + name : remotePath + "/" + name
            let childLocal = localURL.appendingPathComponent(name)
            if attributes.fileType == .directory {
                try FileManager.default.createDirectory(at: childLocal, withIntermediateDirectories: true)
                try downloadDirectory(sftp: sftp, remotePath: childRemote, localURL: childLocal)
            } else {
                try sftp.download(remotePath: childRemote, localURL: childLocal)
            }
        }
    }
}
#else

@MainActor
final class SFTPManager: ObservableObject {
    @Published var isConnected = false
    @Published var isBusy = false
    @Published var currentPath: String = "~"
    @Published var entries: [RemoteEntry] = []
    @Published var statusMessage: String?

    func connect(connection: Connection, password: String?) {
        statusMessage = "SFTP is unavailable: missing Shout module. Please add the Shout dependency to enable SFTP."
        isConnected = false
    }

    func disconnect() {
        isConnected = false
        isBusy = false
        entries = []
        statusMessage = nil
    }

    func refresh() {
        statusMessage = "SFTP is unavailable: missing Shout module."
    }

    func upload(localURL: URL) {
        statusMessage = "SFTP is unavailable: missing Shout module."
    }

    func download(entry: RemoteEntry, to localURL: URL) {
        statusMessage = "SFTP is unavailable: missing Shout module."
    }
}

#endif
