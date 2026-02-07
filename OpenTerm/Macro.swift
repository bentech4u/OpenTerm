import Foundation

struct Macro: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, content: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Parse the macro content into executable steps
    func parseSteps() -> [MacroStep] {
        var steps: [MacroStep] = []
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if let step = MacroStep.parse(trimmed) {
                steps.append(step)
            }
        }

        return steps
    }
}

enum MacroStep: Equatable {
    case text(String)           // Regular text to type
    case returnKey              // Press Enter
    case tabKey                 // Press Tab
    case escapeKey              // Press Escape
    case sleep(TimeInterval)    // Wait N seconds
    case waitFor(String, TimeInterval) // Wait for text with timeout
    case controlKey(Character)  // Ctrl+key (e.g., Ctrl+C)

    /// Parse a single line into a MacroStep
    static func parse(_ line: String) -> MacroStep? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }

        // Check for special commands
        let uppercased = trimmed.uppercased()

        if uppercased == "RETURN" || uppercased == "ENTER" {
            return .returnKey
        }

        if uppercased == "TAB" {
            return .tabKey
        }

        if uppercased == "ESCAPE" || uppercased == "ESC" {
            return .escapeKey
        }

        // SLEEP=N
        if uppercased.hasPrefix("SLEEP=") {
            let valueStr = String(trimmed.dropFirst(6))
            if let seconds = Double(valueStr) {
                return .sleep(seconds)
            }
            return nil
        }

        // WAITFOR=text or WAITFOR=text,timeout
        if uppercased.hasPrefix("WAITFOR=") {
            let value = String(trimmed.dropFirst(8))
            // Check if timeout is specified: WAITFOR=text,30
            if let commaIndex = value.lastIndex(of: ",") {
                let text = String(value[..<commaIndex])
                let timeoutStr = String(value[value.index(after: commaIndex)...])
                let timeout = Double(timeoutStr) ?? 30.0
                return .waitFor(text, timeout)
            }
            return .waitFor(value, 30.0) // Default 30 second timeout
        }

        // CTRL+X
        if uppercased.hasPrefix("CTRL+") && trimmed.count == 6 {
            let keyChar = trimmed[trimmed.index(trimmed.startIndex, offsetBy: 5)]
            return .controlKey(Character(keyChar.uppercased()))
        }

        // Regular text
        return .text(trimmed)
    }

    /// Convert step to display string
    var displayString: String {
        switch self {
        case .text(let str):
            return str
        case .returnKey:
            return "RETURN"
        case .tabKey:
            return "TAB"
        case .escapeKey:
            return "ESCAPE"
        case .sleep(let seconds):
            return "SLEEP=\(Int(seconds))"
        case .waitFor(let text, let timeout):
            if timeout == 30.0 {
                return "WAITFOR=\(text)"
            }
            return "WAITFOR=\(text),\(Int(timeout))"
        case .controlKey(let char):
            return "CTRL+\(char)"
        }
    }

    /// Get the bytes to send to terminal
    var terminalBytes: Data? {
        switch self {
        case .text(let str):
            return str.data(using: .utf8)
        case .returnKey:
            return Data([0x0D]) // Carriage return
        case .tabKey:
            return Data([0x09]) // Tab
        case .escapeKey:
            return Data([0x1B]) // Escape
        case .controlKey(let char):
            // Ctrl+A = 0x01, Ctrl+B = 0x02, etc.
            if let ascii = char.asciiValue {
                let ctrlCode = ascii - 64 // A=65, so Ctrl+A = 1
                return Data([ctrlCode])
            }
            return nil
        case .sleep, .waitFor:
            return nil // These are control flow, not bytes
        }
    }
}
