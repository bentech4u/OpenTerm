import SwiftUI

struct FolderDetailView: View {
    @Binding var folder: Folder

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Folder")
                .font(.title2)
                .fontWeight(.semibold)

            TextField("Name", text: $folder.name)
                .textFieldStyle(.roundedBorder)

            Spacer()
        }
        .padding(20)
    }
}
