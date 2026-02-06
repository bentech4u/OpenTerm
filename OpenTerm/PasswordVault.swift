import Foundation
import CryptoKit
import Security
import Combine

@MainActor
final class PasswordVault: ObservableObject {
    @Published private(set) var isConfigured: Bool = false
    @Published private(set) var isUnlocked: Bool = false
    @Published private(set) var savedConnectionIds: [UUID] = []

    private let iterations = 50_000
    private var key: SymmetricKey?
    private var entries: [String: String] = [:]

    init() {
        loadConfigurationState()
    }

    func configureMasterPassword(password: String, confirm: String) -> Bool {
        guard !password.isEmpty, password == confirm else { return false }
        let salt = Self.randomSalt()
        let newKey = Self.deriveKey(password: password, salt: salt, rounds: iterations)
        let payload = VaultPayload(passwords: [:])

        do {
            let file = try Self.encrypt(payload: payload, key: newKey, salt: salt, iterations: iterations)
            try Self.writeVaultFile(file)
            key = newKey
            entries = [:]
            isConfigured = true
            isUnlocked = true
            updateSavedConnectionIds(from: file)
            return true
        } catch {
            NSLog("Failed to configure vault: \(error)")
            return false
        }
    }

    func unlock(password: String) -> Bool {
        do {
            let file = try Self.readVaultFile()
            let derived = Self.deriveKey(password: password, salt: file.salt, rounds: file.iterations)
            let payload = try Self.decrypt(file: file, key: derived)
            key = derived
            entries = payload.passwords
            isConfigured = true
            isUnlocked = true
            updateSavedConnectionIds(from: file)
            return true
        } catch {
            NSLog("Failed to unlock vault: \(error)")
            return false
        }
    }

    func lock() {
        key = nil
        entries = [:]
        isUnlocked = false
    }

    func password(for connectionId: UUID) -> String? {
        guard isUnlocked else { return nil }
        return entries[connectionId.uuidString]
    }

    func allPasswords() -> [String: String] {
        guard isUnlocked else { return [:] }
        return entries
    }

    func storePassword(_ password: String, for connectionId: UUID) {
        guard let key, isUnlocked else { return }
        entries[connectionId.uuidString] = password
        do {
            let file = try Self.encrypt(payload: VaultPayload(passwords: entries), key: key, salt: currentSalt(), iterations: iterations)
            try Self.writeVaultFile(file)
            updateSavedConnectionIds(from: file)
        } catch {
            NSLog("Failed to store password: \(error)")
        }
    }

    func removePassword(for connectionId: UUID) {
        guard let key, isUnlocked else { return }
        entries.removeValue(forKey: connectionId.uuidString)
        do {
            let file = try Self.encrypt(payload: VaultPayload(passwords: entries), key: key, salt: currentSalt(), iterations: iterations)
            try Self.writeVaultFile(file)
            updateSavedConnectionIds(from: file)
        } catch {
            NSLog("Failed to remove password: \(error)")
        }
    }

    private func loadConfigurationState() {
        do {
            let file = try Self.readVaultFile()
            isConfigured = true
            updateSavedConnectionIds(from: file)
        } catch {
            isConfigured = false
        }
    }

    private func updateSavedConnectionIds(from file: VaultFile? = nil) {
        if let file, let ids = file.connectionIds {
            savedConnectionIds = ids.compactMap { UUID(uuidString: $0) }.sorted { $0.uuidString < $1.uuidString }
            return
        }

        if isUnlocked {
            savedConnectionIds = entries.keys.compactMap { UUID(uuidString: $0) }.sorted { $0.uuidString < $1.uuidString }
        }
    }

    private func currentSalt() -> Data {
        if let file = try? Self.readVaultFile() {
            return file.salt
        }
        return Self.randomSalt()
    }

    func changeMasterPassword(current: String, new: String, confirm: String) -> Bool {
        guard !new.isEmpty, new == confirm else { return false }
        do {
            let file = try Self.readVaultFile()
            let currentKey = Self.deriveKey(password: current, salt: file.salt, rounds: file.iterations)
            let payload = try Self.decrypt(file: file, key: currentKey)

            let newSalt = Self.randomSalt()
            let newKey = Self.deriveKey(password: new, salt: newSalt, rounds: iterations)
            let newFile = try Self.encrypt(payload: payload, key: newKey, salt: newSalt, iterations: iterations)
            try Self.writeVaultFile(newFile)

            key = newKey
            entries = payload.passwords
            isConfigured = true
            isUnlocked = true
            updateSavedConnectionIds(from: newFile)
            return true
        } catch {
            NSLog("Failed to change master password: \(error)")
            return false
        }
    }

    func removeAllPasswords() {
        guard let key, isUnlocked else { return }
        entries.removeAll()
        do {
            let file = try Self.encrypt(payload: VaultPayload(passwords: entries), key: key, salt: currentSalt(), iterations: iterations)
            try Self.writeVaultFile(file)
            updateSavedConnectionIds(from: file)
        } catch {
            NSLog("Failed to remove all passwords: \(error)")
        }
    }

    func exportPasswords(masterPassword: String) -> PasswordExport? {
        do {
            let file = try Self.readVaultFile()
            let derived = Self.deriveKey(password: masterPassword, salt: file.salt, rounds: file.iterations)
            let payload = try Self.decrypt(file: file, key: derived)
            return PasswordExport(passwords: payload.passwords)
        } catch {
            NSLog("Failed to export passwords: \(error)")
            return nil
        }
    }

    func importPasswords(_ export: PasswordExport, masterPassword: String) -> Bool {
        if !isConfigured {
            let ok = configureMasterPassword(password: masterPassword, confirm: masterPassword)
            if !ok { return false }
        } else if !isUnlocked {
            guard unlock(password: masterPassword) else { return false }
        } else {
            guard verifyMasterPassword(masterPassword) else { return false }
        }

        guard let key else { return false }
        entries.merge(export.passwords) { _, new in new }
        do {
            let file = try Self.encrypt(payload: VaultPayload(passwords: entries), key: key, salt: currentSalt(), iterations: iterations)
            try Self.writeVaultFile(file)
            updateSavedConnectionIds(from: file)
            return true
        } catch {
            NSLog("Failed to import passwords: \(error)")
            return false
        }
    }

    private func verifyMasterPassword(_ password: String) -> Bool {
        do {
            let file = try Self.readVaultFile()
            let derived = Self.deriveKey(password: password, salt: file.salt, rounds: file.iterations)
            _ = try Self.decrypt(file: file, key: derived)
            return true
        } catch {
            return false
        }
    }
}

private struct VaultPayload: Codable {
    let passwords: [String: String]
}

struct PasswordExport: Codable {
    let passwords: [String: String]
}

private struct VaultFile: Codable {
    let salt: Data
    let iterations: Int
    let connectionIds: [String]?
    let nonce: Data
    let ciphertext: Data
    let tag: Data
}

private extension PasswordVault {
    static func vaultURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent("OpenTerm", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("vault.json")
    }

    static func readVaultFile() throws -> VaultFile {
        let url = try vaultURL()
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(VaultFile.self, from: data)
    }

    static func writeVaultFile(_ file: VaultFile) throws {
        let url = try vaultURL()
        let data = try JSONEncoder().encode(file)
        try data.write(to: url, options: [.atomic])
    }

    static func deriveKey(password: String, salt: Data, rounds: Int) -> SymmetricKey {
        var data = Data(password.utf8) + salt
        for _ in 0..<rounds {
            data = Data(SHA256.hash(data: data))
        }
        return SymmetricKey(data: data)
    }

    static func encrypt(payload: VaultPayload, key: SymmetricKey, salt: Data, iterations: Int) throws -> VaultFile {
        let data = try JSONEncoder().encode(payload)
        let sealedBox = try AES.GCM.seal(data, using: key)
        return VaultFile(
            salt: salt,
            iterations: iterations,
            connectionIds: Array(payload.passwords.keys),
            nonce: Data(sealedBox.nonce),
            ciphertext: sealedBox.ciphertext,
            tag: sealedBox.tag
        )
    }

    static func decrypt(file: VaultFile, key: SymmetricKey) throws -> VaultPayload {
        let nonce = try AES.GCM.Nonce(data: file.nonce)
        let sealed = try AES.GCM.SealedBox(nonce: nonce, ciphertext: file.ciphertext, tag: file.tag)
        let data = try AES.GCM.open(sealed, using: key)
        return try JSONDecoder().decode(VaultPayload.self, from: data)
    }

    static func randomSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }
}
