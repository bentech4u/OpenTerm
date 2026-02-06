import Foundation

enum SSHAskPassHelper {
    static func environment(password: String) -> [String]? {
        guard !password.isEmpty else { return nil }
        do {
            let scriptURL = try ensureScript()
            return [
                "SSH_ASKPASS=\(scriptURL.path)",
                "SSH_ASKPASS_REQUIRE=force",
                "SSH_ASKPASS_PASSWORD=\(password)",
                "DISPLAY=1"
            ]
        } catch {
            NSLog("Failed to create askpass helper: \(error)")
            return nil
        }
    }

    private static func ensureScript() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent("OpenTerm", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("askpass.sh")

        if !FileManager.default.fileExists(atPath: url.path) {
            let script = "#!/bin/sh\n/bin/echo \"$SSH_ASKPASS_PASSWORD\"\n"
            try script.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        }
        return url
    }
}
