import AppKit
import SwiftTerm

final class OpenTermTerminalView: LocalProcessTerminalView {
    var pasteOnRightClick: Bool = false
    var warnBeforePaste: Bool = false
    var selectToCopyEnabled: Bool = false

    private var logFileHandle: FileHandle?
    private var logFileURL: URL?

    func configureLogging(directory: String?, fileName: String) {
        closeLog()

        guard let directory, !directory.isEmpty else { return }
        let sanitized = sanitizeFileName(fileName)
        let dirURL = URL(fileURLWithPath: directory)
        let fileURL = dirURL.appendingPathComponent("\(sanitized).log")

        do {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            logFileHandle = handle
            logFileURL = fileURL
        } catch {
            NSLog("Failed to configure log file: \(error)")
            logFileHandle = nil
            logFileURL = nil
        }
    }

    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        guard let handle = logFileHandle else { return }
        handle.write(Data(slice))
    }

    override func rightMouseDown(with event: NSEvent) {
        guard pasteOnRightClick else {
            super.rightMouseDown(with: event)
            return
        }

        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            NSSound.beep()
            return
        }

        if warnBeforePaste {
            presentPasteWarning(for: text)
        } else {
            send(txt: text)
        }
    }

    override func selectionChanged(source: Terminal) {
        super.selectionChanged(source: source)

        guard selectToCopyEnabled, selectionActive, let text = getSelection(), !text.isEmpty else { return }
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.writeObjects([text as NSString])
    }

    private func presentPasteWarning(for text: String) {
        let alert = NSAlert()
        alert.messageText = "Paste into terminal?"
        alert.informativeText = truncatedText(text)
        alert.addButton(withTitle: "Paste")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            send(txt: text)
        }
    }

    private func truncatedText(_ text: String) -> String {
        let limit = 800
        if text.count <= limit {
            return text
        }
        let prefix = text.prefix(limit)
        return "\(prefix)\n\n… (truncated)"
    }

    private func sanitizeFileName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "session" : trimmed
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        return base.components(separatedBy: invalid).joined(separator: "_")
    }

    private func closeLog() {
        do {
            try logFileHandle?.close()
        } catch {
            NSLog("Failed to close log file: \(error)")
        }
        logFileHandle = nil
        logFileURL = nil
    }

    deinit {
        closeLog()
    }
}
