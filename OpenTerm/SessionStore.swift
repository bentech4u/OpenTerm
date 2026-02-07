import Foundation
import Combine
import SwiftTerm
import AppKit

@MainActor
final class LocalTerminalSession: ObservableObject, Identifiable, MacroPlayable {
    let id: UUID
    let title: String
    let terminalView: OpenTermTerminalView
    private let settings: SettingsStore

    init(title: String, settings: SettingsStore) {
        self.id = UUID()
        self.title = title
        self.settings = settings
        self.terminalView = OpenTermTerminalView(frame: .zero)

        configureTerminal()
        startLocalShell()
    }

    func refreshAppearance() {
        configureTerminal()
    }

    private func configureTerminal() {
        let fontSize = CGFloat(settings.defaultTerminalFontSize)
        let fontName = settings.defaultTerminalFontName
        let bold = settings.defaultTerminalFontBold
        let weight: NSFont.Weight = bold ? .semibold : .regular

        if fontName != "Monospaced", let custom = NSFont(name: fontName, size: fontSize) {
            terminalView.font = custom
        } else {
            terminalView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: weight)
        }

        let backgroundHex = settings.defaultTerminalBackgroundHex
        let foregroundHex = settings.defaultTerminalForegroundHex
        let background = ColorHex.toNSColor(backgroundHex) ?? NSColor.black
        let foreground = ColorHex.toNSColor(foregroundHex) ?? NSColor(calibratedWhite: 0.9, alpha: 1.0)
        terminalView.nativeBackgroundColor = background
        terminalView.nativeForegroundColor = foreground
        terminalView.caretColor = foreground
        terminalView.optionAsMetaKey = true

        terminalView.pasteOnRightClick = settings.pasteOnRightClick
        terminalView.warnBeforePaste = settings.warnBeforePaste
        terminalView.selectToCopyEnabled = settings.selectToCopyEnabled

        let logDirectory = effectiveLogDirectory()
        terminalView.configureLogging(directory: logDirectory, fileName: title)
    }

    private func effectiveLogDirectory() -> String? {
        if settings.logTerminalEnabled, !settings.logTerminalDirectory.isEmpty {
            return settings.logTerminalDirectory
        }
        return nil
    }

    private func startLocalShell() {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let environment = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        terminalView.startProcess(executable: shell, args: [], environment: environment, execName: nil, currentDirectory: home)
    }

    // MARK: - MacroPlayable
    func sendMacroInput(_ data: Data) {
        terminalView.send([UInt8](data))
    }

    func getTerminalContent() -> String? {
        let data = terminalView.getTerminal().getBufferAsData()
        return String(data: data, encoding: .utf8)
    }
}

@MainActor
final class TerminalSession: ObservableObject, Identifiable, MacroPlayable {
    let id: UUID
    let connection: Connection
    let title: String
    let sftpManager: SFTPManager
    let terminalView: OpenTermTerminalView
    private let sshPassword: String?
    private let settings: SettingsStore

    init(connection: Connection, sshPassword: String? = nil, settings: SettingsStore) {
        self.id = UUID()
        self.connection = connection
        self.title = connection.displayName
        self.sftpManager = SFTPManager()
        self.terminalView = OpenTermTerminalView(frame: .zero)
        self.sshPassword = sshPassword
        self.settings = settings

        configureTerminal()
        startTerminal()
    }

    func connectSftp(password: String?) {
        sftpManager.connect(connection: connection, password: password)
    }

    func disconnectSftp() {
        sftpManager.disconnect()
    }

    func refreshAppearance() {
        configureTerminal()
    }

    private func configureTerminal() {
        let fontSize = CGFloat(connection.terminalFontSize ?? settings.defaultTerminalFontSize)
        let fontName = connection.terminalFontName ?? settings.defaultTerminalFontName
        let bold = connection.terminalFontBold ?? settings.defaultTerminalFontBold
        let weight: NSFont.Weight = bold ? .semibold : .regular

        if fontName != "Monospaced", let custom = NSFont(name: fontName, size: fontSize) {
            terminalView.font = custom
        } else {
            terminalView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: weight)
        }

        let backgroundHex = connection.terminalBackgroundHex ?? settings.defaultTerminalBackgroundHex
        let foregroundHex = connection.terminalForegroundHex ?? settings.defaultTerminalForegroundHex
        let background = ColorHex.toNSColor(backgroundHex) ?? NSColor.black
        let foreground = ColorHex.toNSColor(foregroundHex) ?? NSColor(calibratedWhite: 0.9, alpha: 1.0)
        terminalView.nativeBackgroundColor = background
        terminalView.nativeForegroundColor = foreground
        terminalView.caretColor = foreground
        terminalView.optionAsMetaKey = true

        terminalView.pasteOnRightClick = settings.pasteOnRightClick
        terminalView.warnBeforePaste = settings.warnBeforePaste
        terminalView.selectToCopyEnabled = settings.selectToCopyEnabled

        let logDirectory = effectiveLogDirectory()
        terminalView.configureLogging(directory: logDirectory, fileName: connection.displayName)
    }

    private func effectiveLogDirectory() -> String? {
        if let logPath = connection.terminalLogPath, !logPath.isEmpty {
            return logPath
        }
        if settings.logTerminalEnabled, !settings.logTerminalDirectory.isEmpty {
            return settings.logTerminalDirectory
        }
        return nil
    }

    private func startTerminal() {
        var effectiveConnection = connection
        if effectiveConnection.tcpKeepAliveSeconds == nil || effectiveConnection.tcpKeepAliveSeconds == 0 {
            effectiveConnection.tcpKeepAliveSeconds = settings.sshKeepAliveSeconds
        }

        let args = SSHCommandBuilder.arguments(for: effectiveConnection)
        var environment = Terminal.getEnvironmentVariables(termName: "xterm-256color")
        if let password = sshPassword, let askPassEnv = SSHAskPassHelper.environment(password: password) {
            environment.append(contentsOf: askPassEnv)
        }
        terminalView.startProcess(executable: "/usr/bin/ssh", args: args, environment: environment)

        if let command = connection.executeCommand?.trimmingCharacters(in: .whitespacesAndNewlines),
           !command.isEmpty {
            let delay = TimeInterval(connection.executeDelaySeconds ?? 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak terminalView] in
                terminalView?.send(txt: command + "\n")
            }
        }
    }

    // MARK: - MacroPlayable
    func sendMacroInput(_ data: Data) {
        terminalView.send([UInt8](data))
    }

    func getTerminalContent() -> String? {
        let data = terminalView.getTerminal().getBufferAsData()
        return String(data: data, encoding: .utf8)
    }
}

enum SessionKind: Identifiable {
    case ssh(TerminalSession)
    case rdp(RdpSession)
    case local(LocalTerminalSession)

    var id: UUID {
        switch self {
        case .ssh(let session):
            return session.id
        case .rdp(let session):
            return session.id
        case .local(let session):
            return session.id
        }
    }

    var title: String {
        switch self {
        case .ssh(let session):
            return session.title
        case .rdp(let session):
            return session.title
        case .local(let session):
            return session.title
        }
    }

    var connection: Connection? {
        switch self {
        case .ssh(let session):
            return session.connection
        case .rdp(let session):
            return session.connection
        case .local:
            return nil
        }
    }

    var terminalSession: TerminalSession? {
        switch self {
        case .ssh(let session):
            return session
        case .rdp:
            return nil
        case .local:
            return nil
        }
    }

    var rdpSession: RdpSession? {
        switch self {
        case .ssh:
            return nil
        case .rdp(let session):
            return session
        case .local:
            return nil
        }
    }

    var localSession: LocalTerminalSession? {
        switch self {
        case .ssh:
            return nil
        case .rdp:
            return nil
        case .local(let session):
            return session
        }
    }
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [SessionKind] = []
    @Published var activeSessionId: UUID?
    @Published var multiSessionMode: Bool = false
    @Published var excludedFromMultiExec: Set<UUID> = []
    private var localTerminalCounter: Int = 0

    /// Returns only terminal sessions (SSH + Local), excluding RDP
    var terminalSessions: [SessionKind] {
        sessions.filter { $0.rdpSession == nil }
    }

    func toggleMultiSessionMode() {
        multiSessionMode.toggle()
        if !multiSessionMode {
            excludedFromMultiExec.removeAll()
        }
    }

    func toggleExcludeFromMultiExec(sessionId: UUID) {
        if excludedFromMultiExec.contains(sessionId) {
            excludedFromMultiExec.remove(sessionId)
        } else {
            excludedFromMultiExec.insert(sessionId)
        }
    }

    func isExcludedFromMultiExec(sessionId: UUID) -> Bool {
        excludedFromMultiExec.contains(sessionId)
    }

    /// Send text to all non-excluded terminal sessions
    func broadcastToTerminals(_ text: String) {
        for session in terminalSessions {
            guard !excludedFromMultiExec.contains(session.id) else { continue }
            if let sshSession = session.terminalSession {
                sshSession.terminalView.send(txt: text)
            } else if let localSession = session.localSession {
                localSession.terminalView.send(txt: text)
            }
        }
    }

    var activeSession: SessionKind? {
        sessions.first { $0.id == activeSessionId }
    }

    var activeTerminalSession: TerminalSession? {
        activeSession?.terminalSession
    }

    var activeLocalSession: LocalTerminalSession? {
        activeSession?.localSession
    }

    func session(id: UUID) -> SessionKind? {
        sessions.first { $0.id == id }
    }

    @discardableResult
    func openLocalTerminal(settings: SettingsStore) -> SessionKind {
        localTerminalCounter += 1
        let title = "Terminal \(localTerminalCounter)"
        let session = LocalTerminalSession(title: title, settings: settings)
        let kind = SessionKind.local(session)
        sessions.append(kind)
        activeSessionId = kind.id
        return kind
    }

    @discardableResult
    func open(connection: Connection, sshPassword: String? = nil, settings: SettingsStore) -> SessionKind {
        switch connection.type {
        case .ssh:
            let session = TerminalSession(connection: connection, sshPassword: sshPassword, settings: settings)
            let kind = SessionKind.ssh(session)
            sessions.append(kind)
            activeSessionId = kind.id
            return kind
        case .rdp:
            let session = RdpSession(connection: connection, password: sshPassword)
            let kind = SessionKind.rdp(session)
            sessions.append(kind)
            activeSessionId = kind.id
            return kind
        }
    }

    func connectSftp(sessionId: UUID, password: String?) {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return }
        session.terminalSession?.connectSftp(password: password)
    }

    func close(sessionId: UUID) {
        if let session = sessions.first(where: { $0.id == sessionId }) {
            if let ssh = session.terminalSession {
                ssh.disconnectSftp()
            } else if let rdp = session.rdpSession {
                rdp.disconnect()
            }
            // Local sessions don't need explicit cleanup
        }
        sessions.removeAll { $0.id == sessionId }
        if activeSessionId == sessionId {
            activeSessionId = sessions.last?.id
        }
    }

    func activate(sessionId: UUID) {
        activeSessionId = sessionId
    }

    func closeAll() {
        sessions.forEach { session in
            if let ssh = session.terminalSession {
                ssh.disconnectSftp()
            } else if let rdp = session.rdpSession {
                rdp.disconnect()
            }
        }
        sessions.removeAll()
        activeSessionId = nil
    }

    func applySettings() {
        sessions.forEach { session in
            session.terminalSession?.refreshAppearance()
            session.localSession?.refreshAppearance()
        }
    }
}
