import SwiftUI
import AppKit

struct SFTPTextEditorView: View {
    let fileName: String
    let remotePath: String
    let hostInfo: String
    @ObservedObject var manager: SFTPManager
    @ObservedObject var editorState: SFTPEditorState
    let onDismiss: () -> Void

    @State private var content: String = ""
    @State private var originalContent: String = ""
    @State private var isLoading: Bool = true
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @State private var showSaveConfirmation: Bool = false
    @State private var cursorLine: Int = 1
    @State private var cursorColumn: Int = 1
    @State private var wordWrap: Bool = true
    @State private var showFindReplace: Bool = false
    @State private var showUnsavedAlert: Bool = false

    private var isModified: Bool {
        content != originalContent
    }

    init(fileName: String, remotePath: String, hostInfo: String, manager: SFTPManager, editorState: SFTPEditorState? = nil, onDismiss: @escaping () -> Void) {
        self.fileName = fileName
        self.remotePath = remotePath
        self.hostInfo = hostInfo
        self.manager = manager
        self.editorState = editorState ?? SFTPEditorState()
        self.onDismiss = onDismiss
    }

    private var lineCount: Int {
        content.components(separatedBy: .newlines).count
    }

    private var byteCount: Int {
        content.utf8.count
    }

    private var editorFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Title bar - fixed 40pt
                titleBar
                    .frame(width: geometry.size.width, height: 40)

                Divider()

                // Toolbar - fixed 44pt
                toolbar
                    .frame(width: geometry.size.width, height: 44)

                Divider()

                // Editor content area - remaining space minus status bar
                ZStack {
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else {
                        editorView
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height - 40 - 44 - 28 - 4) // 4 for dividers
                .clipped()

                Divider()

                // Status bar - fixed 28pt
                statusBar
                    .frame(width: geometry.size.width, height: 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadFile()
        }
        .alert("Unsaved Changes", isPresented: $showUnsavedAlert) {
            Button("Don't Save", role: .destructive) {
                if let onConfirmClose = editorState.onConfirmClose {
                    onConfirmClose()
                } else {
                    onDismiss()
                }
            }
            Button("Cancel", role: .cancel) {
                editorState.onConfirmClose = nil
            }
            Button("Save") {
                saveFile {
                    if let onConfirmClose = editorState.onConfirmClose {
                        onConfirmClose()
                    } else {
                        onDismiss()
                    }
                }
            }
        } message: {
            Text("Do you want to save the changes you made to \"\(fileName)\"?")
        }
        .alert("File Saved", isPresented: $showSaveConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Changes uploaded to: \(remotePath)")
        }
        .onChange(of: content) { _, _ in
            editorState.isModified = isModified
        }
        .onChange(of: originalContent) { _, _ in
            editorState.isModified = isModified
        }
        .onChange(of: editorState.shouldPromptClose) { _, shouldPrompt in
            if shouldPrompt {
                editorState.shouldPromptClose = false
                showUnsavedAlert = true
            }
        }
    }

    private var titleBar: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.secondary)
            Text(fileName)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            if isModified {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .help("Unsaved changes")
            }
            Text("-")
                .foregroundColor(.secondary)
            Text(hostInfo)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                saveFile()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save")
                }
            }
            .buttonStyle(.bordered)
            .disabled(!isModified || isSaving)
            .keyboardShortcut("s", modifiers: .command)

            Divider()
                .frame(height: 20)

            Button {
                triggerFind()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.bordered)
            .help("Find (⌘F)")
            .keyboardShortcut("f", modifiers: .command)

            Divider()
                .frame(height: 20)

            Toggle(isOn: $wordWrap) {
                HStack(spacing: 4) {
                    Image(systemName: "text.alignleft")
                    Text("Wrap")
                }
            }
            .toggleStyle(.button)
            .help("Word Wrap")

            Spacer()

            if isSaving {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Saving...")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .background(Color(NSColor.underPageBackgroundColor))
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading file...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("Failed to load file")
                .font(.headline)
            Text(error)
                .foregroundStyle(.secondary)
            Button("Retry") {
                loadFile()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var editorView: some View {
        HStack(spacing: 0) {
            // Line numbers
            ScrollView {
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(1...max(lineCount, 1), id: \.self) { lineNum in
                        Text("\(lineNum)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                            .frame(height: 18)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
            }
            .frame(width: 50)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Text editor
            TextEditor(text: $content)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(white: 0.15))
                .foregroundColor(.white)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 16) {
            Text("Ln \(cursorLine), Col \(cursorColumn)")
                .monospacedDigit()

            Divider()
                .frame(height: 14)

            Text("UTF-8")

            Divider()
                .frame(height: 14)

            Text("\(lineCount) lines")

            Divider()
                .frame(height: 14)

            Text(formattedByteCount)

            Spacer()

            if isModified {
                Text("Modified")
                    .foregroundColor(.orange)
            } else {
                Text("Saved")
                    .foregroundColor(.green)
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var formattedByteCount: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(byteCount))
    }

    private func loadFile() {
        isLoading = true
        errorMessage = nil

        let entry = RemoteEntry(name: remotePath, isDirectory: false, size: nil, rawLine: remotePath)
        manager.downloadToMemory(entry: entry) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        content = text
                        originalContent = text
                    } else if let text = String(data: data, encoding: .ascii) {
                        content = text
                        originalContent = text
                    } else {
                        errorMessage = "Unable to decode file as text. The file may be binary."
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func saveFile(completion: (() -> Void)? = nil) {
        isSaving = true

        guard let data = content.data(using: .utf8) else {
            errorMessage = "Failed to encode content"
            isSaving = false
            return
        }

        manager.uploadFromMemory(data: data, remotePath: remotePath) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success:
                    originalContent = content
                    if completion == nil {
                        showSaveConfirmation = true
                    }
                    completion?()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func handleClose() {
        if isModified {
            showUnsavedAlert = true
        } else {
            onDismiss()
        }
    }

    private func triggerFind() {
        NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: NSMenuItem(title: "", action: nil, keyEquivalent: ""))
    }
}

struct SFTPEditorSheet: View {
    let fileName: String
    let remotePath: String
    let hostInfo: String
    @ObservedObject var manager: SFTPManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SFTPTextEditorView(
            fileName: fileName,
            remotePath: remotePath,
            hostInfo: hostInfo,
            manager: manager,
            editorState: nil,
            onDismiss: { dismiss() }
        )
        .frame(minWidth: 700, idealWidth: 900, minHeight: 500, idealHeight: 700)
    }
}
