import Foundation
import AppKit

enum SSHLauncher {
    static func openInTerminal(connection: Connection) {
        let command = buildCommand(connection: connection)
        let script = """
        tell application "Terminal"
            activate
            do script "\(escapeForAppleScript(command))"
        end tell
        """

        var errorInfo: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&errorInfo)
        }

        if let errorInfo {
            NSLog("AppleScript error: \(errorInfo)")
        }
    }

    static func buildCommand(connection: Connection) -> String {
        SSHCommandBuilder.commandString(for: connection)
    }

    private static func escapeForAppleScript(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
