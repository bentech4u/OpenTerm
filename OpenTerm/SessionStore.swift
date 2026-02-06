import Foundation
import Combine
import SwiftTerm
import AppKit

@MainActor
final class TerminalSession: ObservableObject, Identifiable {
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
}

enum SessionKind: Identifiable {
    case ssh(TerminalSession)
    case rdp(RdpSession)

    var id: UUID {
        switch self {
        case .ssh(let session):
            return session.id
        case .rdp(let session):
            return session.id
        }
    }

    var title: String {
        switch self {
        case .ssh(let session):
            return session.title
        case .rdp(let session):
            return session.title
        }
    }

    var connection: Connection {
        switch self {
        case .ssh(let session):
            return session.connection
        case .rdp(let session):
            return session.connection
        }
    }

    var terminalSession: TerminalSession? {
        switch self {
        case .ssh(let session):
            return session
        case .rdp:
            return nil
        }
    }

    var rdpSession: RdpSession? {
        switch self {
        case .ssh:
            return nil
        case .rdp(let session):
            return session
        }
    }
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [SessionKind] = []
    @Published var activeSessionId: UUID?

    var activeSession: SessionKind? {
        sessions.first { $0.id == activeSessionId }
    }

    var activeTerminalSession: TerminalSession? {
        activeSession?.terminalSession
    }

    func session(id: UUID) -> SessionKind? {
        sessions.first { $0.id == id }
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
        }
    }
}
