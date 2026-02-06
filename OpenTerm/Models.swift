import Foundation

enum AuthType: String, Codable, CaseIterable, Identifiable {
    case password
    case privateKey

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .password:
            return "Password"
        case .privateKey:
            return "Private Key"
        }
    }
}

enum ConnectionType: String, Codable, CaseIterable, Identifiable {
    case ssh
    case rdp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ssh:
            return "SSH"
        case .rdp:
            return "RDP"
        }
    }

    var defaultPort: Int {
        switch self {
        case .ssh:
            return 22
        case .rdp:
            return 3389
        }
    }
}

enum RdpDisplayMode: String, Codable, CaseIterable, Identifiable {
    case fitToWindow
    case fullscreen
    case fixed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fitToWindow:
            return "Fit to Window"
        case .fullscreen:
            return "Fullscreen"
        case .fixed:
            return "Fixed Resolution"
        }
    }
}

enum RdpSoundMode: String, Codable, CaseIterable, Identifiable {
    case off
    case local
    case remote

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off:
            return "Off"
        case .local:
            return "Local"
        case .remote:
            return "Remote"
        }
    }
}

enum RdpPerformanceProfile: String, Codable, CaseIterable, Identifiable {
    case bestQuality
    case balanced
    case bestPerformance

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bestQuality:
            return "Best Quality"
        case .balanced:
            return "Balanced"
        case .bestPerformance:
            return "Best Performance"
        }
    }

    var description: String {
        switch self {
        case .bestQuality:
            return "32-bit color, H.264 + AVC444, all effects enabled"
        case .balanced:
            return "24-bit color, H.264, some effects disabled"
        case .bestPerformance:
            return "16-bit color, no graphics pipeline, maximum caching"
        }
    }
}

struct Folder: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var parentId: UUID?

    init(id: UUID = UUID(), name: String, parentId: UUID? = nil) {
        self.id = id
        self.name = name
        self.parentId = parentId
    }
}

struct Connection: Identifiable, Codable, Hashable {
    var id: UUID
    var type: ConnectionType
    var name: String
    var host: String
    var port: Int
    var username: String
    var authType: AuthType
    var keyPath: String
    var tcpKeepAliveSeconds: Int?
    var folderId: UUID?
    var tags: [String]
    var notes: String
    var iconName: String?
    var x11Forwarding: Bool?
    var executeCommand: String?
    var executeDelaySeconds: Int?
    var executeMacroId: UUID?
    var terminalFontName: String?
    var terminalFontSize: Double?
    var terminalFontBold: Bool?
    var terminalForegroundHex: String?
    var terminalBackgroundHex: String?
    var terminalLogPath: String?
    var rdpDisplayMode: RdpDisplayMode
    var rdpWidth: Int
    var rdpHeight: Int
    var rdpClipboardEnabled: Bool
    var rdpSoundMode: RdpSoundMode
    var rdpDriveRedirectionEnabled: Bool
    var rdpPerformanceProfile: RdpPerformanceProfile

    var displayName: String {
        name.isEmpty ? host : name
    }

    init(
        id: UUID = UUID(),
        type: ConnectionType = .ssh,
        name: String,
        host: String,
        port: Int = ConnectionType.ssh.defaultPort,
        username: String,
        authType: AuthType = .password,
        keyPath: String = "",
        tcpKeepAliveSeconds: Int? = nil,
        folderId: UUID? = nil,
        tags: [String] = [],
        notes: String = "",
        iconName: String? = nil,
        x11Forwarding: Bool? = nil,
        executeCommand: String? = nil,
        executeDelaySeconds: Int? = nil,
        executeMacroId: UUID? = nil,
        terminalFontName: String? = nil,
        terminalFontSize: Double? = nil,
        terminalFontBold: Bool? = nil,
        terminalForegroundHex: String? = nil,
        terminalBackgroundHex: String? = nil,
        terminalLogPath: String? = nil,
        rdpDisplayMode: RdpDisplayMode = .fitToWindow,
        rdpWidth: Int = 1280,
        rdpHeight: Int = 720,
        rdpClipboardEnabled: Bool = true,
        rdpSoundMode: RdpSoundMode = .off,
        rdpDriveRedirectionEnabled: Bool = false,
        rdpPerformanceProfile: RdpPerformanceProfile = .balanced
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authType = authType
        self.keyPath = keyPath
        self.tcpKeepAliveSeconds = tcpKeepAliveSeconds
        self.folderId = folderId
        self.tags = tags
        self.notes = notes
        self.iconName = iconName
        self.x11Forwarding = x11Forwarding
        self.executeCommand = executeCommand
        self.executeDelaySeconds = executeDelaySeconds
        self.executeMacroId = executeMacroId
        self.terminalFontName = terminalFontName
        self.terminalFontSize = terminalFontSize
        self.terminalFontBold = terminalFontBold
        self.terminalForegroundHex = terminalForegroundHex
        self.terminalBackgroundHex = terminalBackgroundHex
        self.terminalLogPath = terminalLogPath
        self.rdpDisplayMode = rdpDisplayMode
        self.rdpWidth = rdpWidth
        self.rdpHeight = rdpHeight
        self.rdpClipboardEnabled = rdpClipboardEnabled
        self.rdpSoundMode = rdpSoundMode
        self.rdpDriveRedirectionEnabled = rdpDriveRedirectionEnabled
        self.rdpPerformanceProfile = rdpPerformanceProfile
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case name
        case host
        case port
        case username
        case authType
        case keyPath
        case tcpKeepAliveSeconds
        case folderId
        case tags
        case notes
        case iconName
        case x11Forwarding
        case executeCommand
        case executeDelaySeconds
        case executeMacroId
        case terminalFontName
        case terminalFontSize
        case terminalFontBold
        case terminalForegroundHex
        case terminalBackgroundHex
        case terminalLogPath
        case rdpDisplayMode
        case rdpWidth
        case rdpHeight
        case rdpClipboardEnabled
        case rdpSoundMode
        case rdpDriveRedirectionEnabled
        case rdpPerformanceProfile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = (try? container.decode(ConnectionType.self, forKey: .type)) ?? .ssh
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        host = try container.decodeIfPresent(String.self, forKey: .host) ?? ""
        port = try container.decodeIfPresent(Int.self, forKey: .port) ?? type.defaultPort
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? ""
        authType = try container.decodeIfPresent(AuthType.self, forKey: .authType) ?? .password
        keyPath = try container.decodeIfPresent(String.self, forKey: .keyPath) ?? ""
        tcpKeepAliveSeconds = try container.decodeIfPresent(Int.self, forKey: .tcpKeepAliveSeconds)
        folderId = try container.decodeIfPresent(UUID.self, forKey: .folderId)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
        x11Forwarding = try container.decodeIfPresent(Bool.self, forKey: .x11Forwarding)
        executeCommand = try container.decodeIfPresent(String.self, forKey: .executeCommand)
        executeDelaySeconds = try container.decodeIfPresent(Int.self, forKey: .executeDelaySeconds)
        executeMacroId = try container.decodeIfPresent(UUID.self, forKey: .executeMacroId)
        terminalFontName = try container.decodeIfPresent(String.self, forKey: .terminalFontName)
        terminalFontSize = try container.decodeIfPresent(Double.self, forKey: .terminalFontSize)
        terminalFontBold = try container.decodeIfPresent(Bool.self, forKey: .terminalFontBold)
        terminalForegroundHex = try container.decodeIfPresent(String.self, forKey: .terminalForegroundHex)
        terminalBackgroundHex = try container.decodeIfPresent(String.self, forKey: .terminalBackgroundHex)
        terminalLogPath = try container.decodeIfPresent(String.self, forKey: .terminalLogPath)
        rdpDisplayMode = try container.decodeIfPresent(RdpDisplayMode.self, forKey: .rdpDisplayMode) ?? .fitToWindow
        rdpWidth = try container.decodeIfPresent(Int.self, forKey: .rdpWidth) ?? 1280
        rdpHeight = try container.decodeIfPresent(Int.self, forKey: .rdpHeight) ?? 720
        rdpClipboardEnabled = try container.decodeIfPresent(Bool.self, forKey: .rdpClipboardEnabled) ?? true
        rdpSoundMode = try container.decodeIfPresent(RdpSoundMode.self, forKey: .rdpSoundMode) ?? .off
        rdpDriveRedirectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .rdpDriveRedirectionEnabled) ?? false
        rdpPerformanceProfile = try container.decodeIfPresent(RdpPerformanceProfile.self, forKey: .rdpPerformanceProfile) ?? .balanced
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encode(host, forKey: .host)
        try container.encode(port, forKey: .port)
        try container.encode(username, forKey: .username)
        try container.encode(authType, forKey: .authType)
        try container.encode(keyPath, forKey: .keyPath)
        try container.encodeIfPresent(tcpKeepAliveSeconds, forKey: .tcpKeepAliveSeconds)
        try container.encodeIfPresent(folderId, forKey: .folderId)
        try container.encode(tags, forKey: .tags)
        try container.encode(notes, forKey: .notes)
        try container.encodeIfPresent(iconName, forKey: .iconName)
        try container.encodeIfPresent(x11Forwarding, forKey: .x11Forwarding)
        try container.encodeIfPresent(executeCommand, forKey: .executeCommand)
        try container.encodeIfPresent(executeDelaySeconds, forKey: .executeDelaySeconds)
        try container.encodeIfPresent(executeMacroId, forKey: .executeMacroId)
        try container.encodeIfPresent(terminalFontName, forKey: .terminalFontName)
        try container.encodeIfPresent(terminalFontSize, forKey: .terminalFontSize)
        try container.encodeIfPresent(terminalFontBold, forKey: .terminalFontBold)
        try container.encodeIfPresent(terminalForegroundHex, forKey: .terminalForegroundHex)
        try container.encodeIfPresent(terminalBackgroundHex, forKey: .terminalBackgroundHex)
        try container.encodeIfPresent(terminalLogPath, forKey: .terminalLogPath)
        try container.encode(rdpDisplayMode, forKey: .rdpDisplayMode)
        try container.encode(rdpWidth, forKey: .rdpWidth)
        try container.encode(rdpHeight, forKey: .rdpHeight)
        try container.encode(rdpClipboardEnabled, forKey: .rdpClipboardEnabled)
        try container.encode(rdpSoundMode, forKey: .rdpSoundMode)
        try container.encode(rdpDriveRedirectionEnabled, forKey: .rdpDriveRedirectionEnabled)
        try container.encode(rdpPerformanceProfile, forKey: .rdpPerformanceProfile)
    }
}

struct AppData: Codable {
    var folders: [Folder]
    var connections: [Connection]
}

struct RemoteEntry: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let isDirectory: Bool
    let size: Int?
    let rawLine: String
}
