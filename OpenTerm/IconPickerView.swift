import SwiftUI

struct IconPickerView: View {
    @Binding var selectedIcon: String?
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.fixed(32), spacing: 12), count: 8)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Choose an Icon")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    dismiss()
                }
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(IconLibrary.symbols, id: \.self) { symbol in
                        Button {
                            selectedIcon = symbol
                            dismiss()
                        } label: {
                            Image(systemName: symbol)
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(selectedIcon == symbol ? Color.accentColor.opacity(0.2) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 320)
    }
}

enum IconLibrary {
    static let symbols: [String] = [
        "terminal",
        "server.rack",
        "server.rack.with.led",
        "desktopcomputer",
        "laptopcomputer",
        "externaldrive",
        "externaldrive.connected.to.line.below",
        "folder",
        "folder.fill",
        "folder.badge.plus",
        "folder.badge.gear",
        "lock",
        "lock.shield",
        "key",
        "key.fill",
        "shield",
        "shield.lefthalf.filled",
        "globe",
        "globe.europe.africa",
        "cloud",
        "cloud.fill",
        "antenna.radiowaves.left.and.right",
        "network",
        "link",
        "bolt",
        "bolt.fill",
        "leaf",
        "gear",
        "gearshape",
        "slider.horizontal.3",
        "wrench",
        "hammer",
        "sparkles",
        "star",
        "star.fill",
        "flag",
        "flag.fill",
        "bookmark",
        "bookmark.fill",
        "tag",
        "tag.fill",
        "paperclip",
        "doc",
        "doc.fill",
        "doc.text",
        "tray",
        "tray.fill",
        "envelope",
        "person",
        "person.fill",
        "person.2",
        "person.2.fill",
        "house",
        "house.fill",
        "building.2",
        "building.2.fill",
        "safari",
        "antenna.radiowaves.left.and.right.circle",
        "cube",
        "cube.fill",
        "shippingbox",
        "shippingbox.fill"
    ]
}
