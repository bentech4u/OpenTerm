import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)

            Text("OpenTerm")
                .font(.title)
                .fontWeight(.bold)

            Text("Version \(appVersion) (Build \(buildNumber))")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("A native macOS terminal with SSH & RDP")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 8)

            Text("© 2026 bentech4u")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                Button("GitHub") {
                    if let url = URL(string: "https://github.com/bentech4u/OpenTerm") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)

                Button("Buy Me a Coffee") {
                    if let url = URL(string: "https://buymeacoffee.com/bentech4u") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
            }

            Spacer().frame(height: 8)

            Button("OK") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(width: 320)
    }
}

#Preview {
    AboutView()
}
