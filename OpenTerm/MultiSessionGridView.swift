import SwiftUI
import AppKit

struct MultiSessionGridView: View {
    @ObservedObject var sessionStore: SessionStore
    let onExitMultiSession: () -> Void
    @State private var showPasteConfirmation = false
    @State private var clipboardContent = ""

    private var terminalSessions: [SessionKind] {
        sessionStore.terminalSessions
    }

    private var columns: Int {
        let count = terminalSessions.count
        if count <= 1 { return 1 }
        if count <= 4 { return 2 }
        return 3
    }

    private var rows: Int {
        let count = terminalSessions.count
        return (count + columns - 1) / columns
    }

    var body: some View {
        VStack(spacing: 0) {
            multiSessionToolbar
            Divider()

            if terminalSessions.isEmpty {
                emptyState
            } else {
                ZStack {
                    terminalGridContent
                    // Invisible keyboard capture overlay
                    KeyboardBroadcastOverlay(
                        onKeyPress: { text in
                            sessionStore.broadcastToTerminals(text)
                        }
                    )
                }
            }
        }
        .alert("Multi-paste to all terminals?", isPresented: $showPasteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Paste") {
                sessionStore.broadcastToTerminals(clipboardContent)
            }
        } message: {
            Text(truncatedClipboard)
        }
    }

    private var multiSessionToolbar: some View {
        HStack {
            Image(systemName: "keyboard")
                .foregroundStyle(.secondary)
            Text("Commands are typed to all terminals")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
                    clipboardContent = text
                    showPasteConfirmation = true
                } else {
                    NSSound.beep()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.clipboard")
                    Text("Multi-paste")
                }
            }
            .buttonStyle(.bordered)
            .help("Paste clipboard content to all terminals")

            Button {
                onExitMultiSession()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle")
                    Text("Exit multi-session")
                }
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .help("Return to normal tabbed view")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.split.3x1")
                .font(.largeTitle)
            Text("No terminal sessions")
                .font(.headline)
            Text("Open SSH or local terminals to use multi-session mode.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var terminalGridContent: some View {
        GeometryReader { geometry in
            let cellWidth = geometry.size.width / CGFloat(columns)
            let cellHeight = geometry.size.height / CGFloat(rows)

            VStack(spacing: 1) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 1) {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = row * columns + col
                            if index < terminalSessions.count {
                                let session = terminalSessions[index]
                                MultiSessionTerminalCell(
                                    session: session,
                                    isExcluded: sessionStore.isExcludedFromMultiExec(sessionId: session.id),
                                    onToggleExclude: {
                                        sessionStore.toggleExcludeFromMultiExec(sessionId: session.id)
                                    }
                                )
                                .frame(width: cellWidth - 1, height: cellHeight - 1)
                            } else {
                                Color.clear
                                    .frame(width: cellWidth - 1, height: cellHeight - 1)
                            }
                        }
                    }
                }
            }
        }
    }

    private var truncatedClipboard: String {
        let limit = 500
        if clipboardContent.count <= limit {
            return clipboardContent
        }
        return String(clipboardContent.prefix(limit)) + "\n\n... (truncated, \(clipboardContent.count) total characters)"
    }
}

private struct MultiSessionTerminalCell: View {
    let session: SessionKind
    let isExcluded: Bool
    let onToggleExclude: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            cellHeader
            terminalContent
            cellFooter
        }
        .background(Color(NSColor.windowBackgroundColor))
        .border(Color.secondary.opacity(0.3), width: 1)
    }

    private var cellHeader: some View {
        HStack {
            if session.localSession != nil {
                Image(systemName: "terminal")
                    .font(.caption)
            } else {
                Image(systemName: "network")
                    .font(.caption)
            }
            Text(session.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var terminalContent: some View {
        Group {
            if let sshSession = session.terminalSession {
                EmbeddedTerminalView(terminalView: sshSession.terminalView)
            } else if let localSession = session.localSession {
                EmbeddedTerminalView(terminalView: localSession.terminalView)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(isExcluded ? 0.5 : 1.0)
        .allowsHitTesting(false) // Prevent terminals from capturing keyboard
    }

    private var cellFooter: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { isExcluded },
                set: { _ in onToggleExclude() }
            )) {
                Text("Exclude from input")
                    .font(.caption2)
            }
            .toggleStyle(.checkbox)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Keyboard Broadcast Overlay

struct KeyboardBroadcastOverlay: NSViewRepresentable {
    let onKeyPress: (String) -> Void

    func makeNSView(context: Context) -> KeyboardCaptureView {
        let view = KeyboardCaptureView()
        view.onKeyPress = onKeyPress
        return view
    }

    func updateNSView(_ nsView: KeyboardCaptureView, context: Context) {
        nsView.onKeyPress = onKeyPress
    }
}

final class KeyboardCaptureView: NSView {
    var onKeyPress: ((String) -> Void)?
    private var mouseMonitor: Any?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Become first responder when added to window
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self)
        }

        // Monitor mouse clicks to reclaim focus after checkbox interactions
        if mouseMonitor == nil {
            mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
                // Reclaim focus after any mouse click
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.window?.makeFirstResponder(self)
                }
                return event
            }
        }
    }

    override func removeFromSuperview() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        super.removeFromSuperview()
    }

    deinit {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    override func becomeFirstResponder() -> Bool {
        return true
    }

    override func resignFirstResponder() -> Bool {
        // Allow resignation but try to reclaim focus shortly after
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self, self.window != nil else { return }
            self.window?.makeFirstResponder(self)
        }
        return true
    }

    override func keyDown(with event: NSEvent) {
        // Handle special keys
        if let characters = event.characters {
            onKeyPress?(characters)
        } else if event.keyCode == 36 { // Return
            onKeyPress?("\r")
        } else if event.keyCode == 51 { // Delete/Backspace
            onKeyPress?("\u{7f}")
        } else if event.keyCode == 53 { // Escape
            onKeyPress?("\u{1b}")
        } else if event.keyCode == 48 { // Tab
            onKeyPress?("\t")
        }
    }

    override func flagsChanged(with event: NSEvent) {
        // Ignore modifier-only key presses
    }

    // Handle paste shortcut (Cmd+V)
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            if event.charactersIgnoringModifiers == "v" {
                // Let the Multi-paste button handle this
                return false
            }
            if event.charactersIgnoringModifiers == "c" {
                // Allow copy to work normally
                return false
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    // Make the view transparent but still capture events
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        // Don't draw anything - completely transparent
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Return nil to let all mouse clicks pass through to underlying views
        // Keyboard events are captured via first responder, not hit testing
        return nil
    }

    override func mouseDown(with event: NSEvent) {
        // This won't be called since hitTest returns nil
        // but keep for safety
        window?.makeFirstResponder(self)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return false
    }
}
