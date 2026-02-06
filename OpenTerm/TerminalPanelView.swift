import SwiftUI

struct TerminalPanelView: View {
    let connection: Connection

    @State private var isActive = false
    @State private var sessionId = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(isActive ? "Reconnect" : "Connect") {
                    startSession()
                }
                .disabled(isConnectDisabled)

                if isActive {
                    Button("Close") {
                        closeSession()
                    }
                }

                Spacer()

                Text("Runs /usr/bin/ssh inside the app")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }

            if isActive {
                Text("Embedded terminal moved to the main Sessions tabs.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
            } else {
                Text("Embedded terminal moved to the main Sessions tabs.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
            }
        }
        .onChange(of: connection.id) { _, _ in
            closeSession()
        }
    }

    private var isConnectDisabled: Bool {
        connection.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        connection.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func startSession() {
        isActive = true
        sessionId = UUID()
    }

    private func closeSession() {
        isActive = false
        sessionId = UUID()
    }
}
