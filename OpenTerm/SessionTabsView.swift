import SwiftUI

struct SessionTabsView: View {
    @ObservedObject var sessionStore: SessionStore

    var body: some View {
        VStack(spacing: 0) {
            tabsBar
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tabsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sessionStore.sessions) { session in
                    TabItemView(
                        title: session.title,
                        isActive: session.id == sessionStore.activeSessionId,
                        onSelect: { sessionStore.activate(sessionId: session.id) },
                        onClose: { sessionStore.close(sessionId: session.id) }
                    )
                }

                if sessionStore.sessions.isEmpty {
                    Text("No active sessions")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let session = sessionStore.activeSession {
            switch session {
            case .ssh(let sshSession):
                EmbeddedTerminalView(terminalView: sshSession.terminalView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .rdp(let rdpSession):
                EmbeddedRdpView(session: rdpSession)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "terminal")
                    .font(.largeTitle)
                Text("Open a session to start")
                    .font(.headline)
                Text("Double-click a saved host on the left to open a tab.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct TabItemView: View {
    let title: String
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onSelect) {
                Text(title)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }
}
