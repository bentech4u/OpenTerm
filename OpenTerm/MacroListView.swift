import SwiftUI

struct MacroListView: View {
    @ObservedObject var store: MacroStore
    @ObservedObject var player: MacroPlayer

    let onPlay: (Macro) -> Void
    let onEdit: (Macro) -> Void

    @State private var showNewMacro = false
    @State private var editingMacro: Macro?
    @State private var selectedMacroId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header with add button
            HStack {
                Text("Macros")
                    .font(.headline)
                Spacer()
                Button {
                    showNewMacro = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("New Macro")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Player status
            if player.isPlaying {
                playerStatusBar
            }

            // Macro list
            if store.macros.isEmpty {
                emptyState
            } else {
                macroList
            }
        }
        .sheet(isPresented: $showNewMacro) {
            MacroEditorView(store: store) { macro in
                store.add(macro)
            }
        }
        .sheet(item: $editingMacro) { macro in
            MacroEditorView(store: store, macro: macro) { updated in
                store.update(updated)
            }
        }
    }

    private var playerStatusBar: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.6)

            Text(player.statusMessage ?? "Playing...")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer()

            Text("\(player.currentStep)/\(player.totalSteps)")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                player.stop()
            } label: {
                Image(systemName: "stop.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("Stop Macro")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.1))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("No macros yet")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Create Macro") {
                showNewMacro = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var macroList: some View {
        List(selection: $selectedMacroId) {
            ForEach(store.macros) { macro in
                MacroRowView(
                    macro: macro,
                    isPlaying: player.isPlaying,
                    onPlay: { onPlay(macro) },
                    onEdit: { editingMacro = macro }
                )
                .tag(macro.id)
                .contextMenu {
                    Button("Play") {
                        onPlay(macro)
                    }
                    .disabled(player.isPlaying)

                    Button("Edit") {
                        editingMacro = macro
                    }

                    Button("Duplicate") {
                        store.duplicate(macro)
                    }

                    Divider()

                    Button("Delete", role: .destructive) {
                        store.delete(macro)
                    }
                }
            }
            .onDelete { offsets in
                store.delete(at: offsets)
            }
        }
        .listStyle(.plain)
    }
}

struct MacroRowView: View {
    let macro: Macro
    let isPlaying: Bool
    let onPlay: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "play.rectangle")
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(macro.name)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(stepCountText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                onPlay()
            } label: {
                Image(systemName: "play.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(isPlaying)
            .help("Play Macro")
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onEdit()
        }
    }

    private var stepCountText: String {
        let steps = macro.parseSteps()
        return "\(steps.count) step\(steps.count == 1 ? "" : "s")"
    }
}
