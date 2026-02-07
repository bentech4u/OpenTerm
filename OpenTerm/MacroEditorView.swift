import SwiftUI

struct MacroEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: MacroStore

    let existingMacro: Macro?
    let onSave: (Macro) -> Void

    @State private var name: String = ""
    @State private var content: String = ""
    @State private var showHelp = false

    init(store: MacroStore, macro: Macro? = nil, onSave: @escaping (Macro) -> Void) {
        self.store = store
        self.existingMacro = macro
        self.onSave = onSave
        _name = State(initialValue: macro?.name ?? "")
        _content = State(initialValue: macro?.content ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(existingMacro == nil ? "New Macro" : "Edit Macro")
                    .font(.headline)
                Spacer()
                Button {
                    showHelp.toggle()
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.plain)
                .help("Show syntax help")
            }
            .padding()

            Divider()

            // Name field
            HStack {
                Text("Name:")
                    .frame(width: 60, alignment: .leading)
                TextField("Macro name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // Content editor
            VStack(alignment: .leading, spacing: 4) {
                Text("Macro Content:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: $content)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .border(Color.gray.opacity(0.3), width: 1)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Quick insert buttons
            quickInsertBar
                .padding(.horizontal)
                .padding(.top, 8)

            Spacer()

            Divider()

            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveMacro()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 450)
        .sheet(isPresented: $showHelp) {
            MacroHelpView()
        }
    }

    private var quickInsertBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("Insert:")
                    .foregroundColor(.secondary)
                    .font(.caption)

                quickButton("RETURN", "Press Enter")
                quickButton("TAB", "Press Tab")
                quickButton("ESCAPE", "Press Escape")
                quickButton("SLEEP=1", "Wait 1 second")
                quickButton("WAITFOR=", "Wait for text")
                quickButton("CTRL+C", "Ctrl+C")
                quickButton("CTRL+D", "Ctrl+D")
            }
        }
    }

    private func quickButton(_ text: String, _ tooltip: String) -> some View {
        Button(text) {
            insertText(text)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(tooltip)
    }

    private func insertText(_ text: String) {
        if content.isEmpty || content.hasSuffix("\n") {
            content += text
        } else {
            content += "\n" + text
        }
    }

    private func saveMacro() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        var macro: Macro
        if let existing = existingMacro {
            macro = existing
            macro.name = trimmedName
            macro.content = content
            macro.updatedAt = Date()
        } else {
            macro = Macro(name: trimmedName, content: content)
        }

        onSave(macro)
        dismiss()
    }
}

struct MacroHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Macro Syntax Help")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    dismiss()
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    helpSection("Text Input", """
                    Any line that isn't a special command will be typed as text.
                    Example: echo "Hello World"
                    """)

                    helpSection("RETURN / ENTER", """
                    Presses the Enter/Return key.
                    Example:
                    ls -la
                    RETURN
                    """)

                    helpSection("TAB", """
                    Presses the Tab key (useful for auto-completion).
                    """)

                    helpSection("ESCAPE / ESC", """
                    Presses the Escape key.
                    """)

                    helpSection("SLEEP=N", """
                    Waits N seconds before continuing.
                    Example: SLEEP=3 (waits 3 seconds)
                    """)

                    helpSection("WAITFOR=text", """
                    Waits until the specified text appears in the terminal.
                    Default timeout is 30 seconds.
                    Example: WAITFOR=password

                    With custom timeout:
                    WAITFOR=password,60 (waits up to 60 seconds)
                    """)

                    helpSection("CTRL+X", """
                    Sends a control character.
                    Examples:
                    CTRL+C (interrupt)
                    CTRL+D (end of input)
                    CTRL+Z (suspend)
                    """)

                    Divider()

                    helpSection("Example Macro", """
                    SLEEP=2
                    su - root
                    RETURN
                    WAITFOR=password
                    mypassword
                    RETURN
                    cd /var/log
                    RETURN
                    tail -f syslog
                    RETURN
                    """)
                }
            }
        }
        .padding()
        .frame(width: 450, height: 500)
    }

    private func helpSection(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(content)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}
