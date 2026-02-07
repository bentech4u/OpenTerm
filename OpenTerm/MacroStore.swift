import Foundation
import Combine
import SwiftUI

@MainActor
final class MacroStore: ObservableObject {
    @Published private(set) var macros: [Macro] = []

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("OpenTerm", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        self.fileURL = appFolder.appendingPathComponent("macros.json")
        load()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            macros = try JSONDecoder().decode([Macro].self, from: data)
        } catch {
            print("Failed to load macros: \(error)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(macros)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save macros: \(error)")
        }
    }

    func add(_ macro: Macro) {
        macros.append(macro)
        save()
    }

    func update(_ macro: Macro) {
        if let index = macros.firstIndex(where: { $0.id == macro.id }) {
            var updated = macro
            updated.updatedAt = Date()
            macros[index] = updated
            save()
        }
    }

    func delete(_ macro: Macro) {
        macros.removeAll { $0.id == macro.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        macros.remove(atOffsets: offsets)
        save()
    }

    func macro(withId id: UUID?) -> Macro? {
        guard let id else { return nil }
        return macros.first { $0.id == id }
    }

    func duplicate(_ macro: Macro) {
        var newMacro = macro
        newMacro.id = UUID()
        newMacro.name = "\(macro.name) (Copy)"
        newMacro.createdAt = Date()
        newMacro.updatedAt = Date()
        macros.append(newMacro)
        save()
    }
}
