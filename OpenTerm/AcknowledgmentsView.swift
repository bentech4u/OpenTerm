import SwiftUI

struct AcknowledgmentsView: View {
    @Environment(\.dismiss) private var dismiss

    private let libraries: [(name: String, description: String, license: String, url: String)] = [
        ("SwiftTerm", "Terminal emulator for Swift", "MIT", "https://github.com/migueldeicaza/SwiftTerm"),
        ("FreeRDP", "Free RDP client implementation", "Apache 2.0", "https://github.com/FreeRDP/FreeRDP"),
        ("Shout", "SSH library for Swift", "MIT", "https://github.com/jakeheis/Shout"),
        ("OpenSSL", "Cryptography and TLS toolkit", "Apache 2.0", "https://github.com/openssl/openssl"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("Acknowledgments")
                .font(.title2)
                .fontWeight(.bold)

            Text("OpenTerm is built with these open source libraries:")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(libraries, id: \.name) { library in
                        LibraryRow(library: library)
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 200)

            Button("OK") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 400)
    }
}

private struct LibraryRow: View {
    let library: (name: String, description: String, license: String, url: String)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(library.name)
                    .fontWeight(.semibold)
                Spacer()
                Text(library.license)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            Text(library.description)
                .font(.caption)
                .foregroundColor(.secondary)
            Button(library.url) {
                if let url = URL(string: library.url) {
                    NSWorkspace.shared.open(url)
                }
            }
            .font(.caption)
            .buttonStyle(.link)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    AcknowledgmentsView()
}
