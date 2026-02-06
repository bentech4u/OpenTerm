import Foundation

enum SSHCommandBuilder {
    static func arguments(for connection: Connection) -> [String] {
        guard connection.type == .ssh else { return [] }
        var args: [String] = ["-p", "\(connection.port)"]

        if let keepAlive = connection.tcpKeepAliveSeconds, keepAlive > 0 {
            args.append(contentsOf: ["-o", "ServerAliveInterval=\(keepAlive)"])
        }

        if connection.x11Forwarding ?? false {
            args.append("-X")
        }

        if connection.authType == .password {
            args.append(contentsOf: ["-o", "PreferredAuthentications=password"])
            args.append(contentsOf: ["-o", "PubkeyAuthentication=no"])
        }

        if connection.authType == .privateKey, !connection.keyPath.isEmpty {
            let expandedPath = (connection.keyPath as NSString).expandingTildeInPath
            args.append(contentsOf: ["-i", expandedPath])
        }

        let target = "\(connection.username)@\(connection.host)"
        args.append(target)
        return args
    }

    static func commandString(for connection: Connection) -> String {
        let args = arguments(for: connection).map { escapeArgument($0) }
        return (["ssh"] + args).joined(separator: " ")
    }

    private static func escapeArgument(_ value: String) -> String {
        if value.contains(" ") || value.contains("\"") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
