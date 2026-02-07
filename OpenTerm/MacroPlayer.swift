import Foundation
import Combine

/// Protocol for objects that can receive macro input
protocol MacroPlayable: AnyObject {
    func sendMacroInput(_ data: Data)
    func getTerminalContent() -> String?
}

/// Plays back macros to terminal sessions
@MainActor
final class MacroPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentStep: Int = 0
    @Published private(set) var totalSteps: Int = 0
    @Published private(set) var statusMessage: String?

    private var playTask: Task<Void, Never>?
    private var isCancelled = false

    func play(macro: Macro, to targets: [MacroPlayable]) {
        guard !isPlaying else { return }

        let steps = macro.parseSteps()
        guard !steps.isEmpty else {
            statusMessage = "Macro is empty"
            return
        }

        isPlaying = true
        isCancelled = false
        currentStep = 0
        totalSteps = steps.count
        statusMessage = "Playing: \(macro.name)"

        playTask = Task { [weak self] in
            await self?.executeSteps(steps, to: targets)
        }
    }

    func stop() {
        isCancelled = true
        playTask?.cancel()
        playTask = nil
        isPlaying = false
        statusMessage = "Stopped"
    }

    private func executeSteps(_ steps: [MacroStep], to targets: [MacroPlayable]) async {
        for (index, step) in steps.enumerated() {
            guard !isCancelled else { break }

            await MainActor.run {
                self.currentStep = index + 1
            }

            switch step {
            case .text, .returnKey, .tabKey, .escapeKey, .controlKey:
                if let data = step.terminalBytes {
                    await MainActor.run {
                        for target in targets {
                            target.sendMacroInput(data)
                        }
                    }
                }

            case .sleep(let seconds):
                await MainActor.run {
                    self.statusMessage = "Sleeping \(Int(seconds))s..."
                }
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))

            case .waitFor(let text, let timeout):
                await MainActor.run {
                    self.statusMessage = "Waiting for: \(text)"
                }
                let found = await waitForText(text, timeout: timeout, in: targets)
                if !found && !isCancelled {
                    await MainActor.run {
                        self.statusMessage = "Timeout waiting for: \(text)"
                    }
                    // Continue anyway after timeout
                }
            }

            // Small delay between steps to allow terminal to process
            if !isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }

        await MainActor.run {
            self.isPlaying = false
            if !self.isCancelled {
                self.statusMessage = "Completed"
            }
        }
    }

    private func waitForText(_ text: String, timeout: TimeInterval, in targets: [MacroPlayable]) async -> Bool {
        let startTime = Date()
        let pollInterval: TimeInterval = 0.5 // Check every 500ms

        while Date().timeIntervalSince(startTime) < timeout && !isCancelled {
            // Check if any target contains the text
            let found = await MainActor.run {
                targets.contains { target in
                    if let content = target.getTerminalContent() {
                        return content.contains(text)
                    }
                    return false
                }
            }

            if found {
                return true
            }

            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }

        return false
    }
}

/// Extension to execute macro on session start (for attached macros)
extension MacroPlayer {
    func playOnConnect(macro: Macro, to target: MacroPlayable, delay: TimeInterval) {
        Task { [weak self] in
            // Wait for the specified delay
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            await MainActor.run {
                self?.play(macro: macro, to: [target])
            }
        }
    }
}
