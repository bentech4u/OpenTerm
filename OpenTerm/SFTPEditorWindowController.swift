import SwiftUI
import AppKit
import Combine

final class SFTPEditorState: ObservableObject {
    @Published var isModified: Bool = false
    @Published var shouldPromptClose: Bool = false
    var onConfirmClose: (() -> Void)?
}

final class SFTPEditorWindowController {
    private var window: NSWindow?
    private var hostingView: NSHostingView<AnyView>?
    private var editorState: SFTPEditorState?
    private var windowDelegate: WindowDelegate?

    static let shared = SFTPEditorWindowController()

    private init() {}

    func openEditor(entry: RemoteEntry, connection: Connection, manager: SFTPManager) {
        // Close existing window if open
        window?.close()

        let state = SFTPEditorState()
        self.editorState = state

        // Build the remote path - use simple filename if in home/current directory
        let currentDir = manager.currentPath
        let fullRemotePath: String
        if currentDir.isEmpty || currentDir == "." || currentDir == "~" {
            // In home directory, just use the filename
            fullRemotePath = entry.name
        } else {
            fullRemotePath = "\(currentDir)/\(entry.name)"
        }

        let editorView = SFTPTextEditorView(
            fileName: entry.name,
            remotePath: fullRemotePath,
            hostInfo: "\(connection.username)@\(connection.host)",
            manager: manager,
            editorState: state,
            onDismiss: { [weak self] in
                self?.closeWindow()
            }
        )

        let hostingView = NSHostingView(rootView: AnyView(editorView))
        self.hostingView = hostingView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "\(entry.name) - \(connection.username)@\(connection.host)"
        window.contentView = hostingView
        window.minSize = NSSize(width: 600, height: 400)
        window.setFrameAutosaveName("SFTPEditor")
        window.center()
        window.isReleasedWhenClosed = false

        // Set up window delegate to handle close button
        let delegate = WindowDelegate(
            state: state,
            onShouldClose: { [weak self] in
                self?.handleWindowShouldClose() ?? true
            },
            onClose: { [weak self] in
                self?.handleWindowClose()
            }
        )
        self.windowDelegate = delegate
        window.delegate = delegate

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    private func handleWindowShouldClose() -> Bool {
        guard let state = editorState else { return true }

        if state.isModified {
            // Trigger the unsaved changes prompt in the view
            state.shouldPromptClose = true
            state.onConfirmClose = { [weak self] in
                self?.forceClose()
            }
            return false
        }
        return true
    }

    private func handleWindowClose() {
        editorState = nil
        windowDelegate = nil
    }

    func closeWindow() {
        window?.close()
        window = nil
        hostingView = nil
        editorState = nil
        windowDelegate = nil
    }

    private func forceClose() {
        editorState?.isModified = false
        closeWindow()
    }
}

private class WindowDelegate: NSObject, NSWindowDelegate {
    let state: SFTPEditorState
    let onShouldClose: () -> Bool
    let onClose: () -> Void

    init(state: SFTPEditorState, onShouldClose: @escaping () -> Bool, onClose: @escaping () -> Void) {
        self.state = state
        self.onShouldClose = onShouldClose
        self.onClose = onClose
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return onShouldClose()
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
