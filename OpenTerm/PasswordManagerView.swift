import SwiftUI

struct PasswordManagerView: View {
    @EnvironmentObject var vault: PasswordVault
    @EnvironmentObject var store: ConnectionStore
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var masterPassword = ""
    @State private var confirmPassword = ""
    @State private var statusMessage: String?

    @State private var showPasswords = false
    @State private var showUnlockPrompt = false
    @State private var unlockPassword = ""
    @State private var unlockError: String?

    @State private var changeCurrentPassword = ""
    @State private var changeNewPassword = ""
    @State private var changeConfirmPassword = ""
    @State private var changeStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if !vault.isConfigured {
                setupSection
            } else {
                settingsSection
                managerSection
                changePasswordSection
            }

            if let statusMessage {
                Text(statusMessage)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 380)
        .onAppear {
            if vault.isUnlocked {
                vault.lock()
                showPasswords = false
            }
        }
        .sheet(isPresented: $showUnlockPrompt) {
            UnlockPrompt(password: $unlockPassword, errorMessage: $unlockError) {
                let success = vault.unlock(password: unlockPassword)
                if success {
                    showPasswords = true
                    unlockPassword = ""
                    unlockError = nil
                    showUnlockPrompt = false
                } else {
                    unlockError = "Invalid master password."
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Password Manager")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Button("Close") {
                dismiss()
            }
        }
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set a master password")
                .font(.headline)
            SecureField("Master password", text: $masterPassword)
            SecureField("Confirm password", text: $confirmPassword)

            Button("Create Vault") {
                let success = vault.configureMasterPassword(password: masterPassword, confirm: confirmPassword)
                if !success {
                    statusMessage = "Passwords do not match or could not create vault."
                } else {
                    statusMessage = nil
                    masterPassword = ""
                    confirmPassword = ""
                }
            }
            .disabled(masterPassword.isEmpty || confirmPassword.isEmpty)
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save session passwords")
                .font(.headline)
            HStack(spacing: 16) {
                ForEach(PasswordSavePolicy.allCases) { policy in
                    HStack(spacing: 6) {
                        Image(systemName: settings.passwordSavePolicy == policy ? "largecircle.fill.circle" : "circle")
                        Text(policy.displayName)
                    }
                    .onTapGesture {
                        settings.passwordSavePolicy = policy
                    }
                }
            }
            Text("Ask: always prompt. Never: use saved passwords automatically. Always: save without asking.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var managerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved passwords")
                    .font(.headline)
                Spacer()
                if vault.isUnlocked {
                    Button("Lock") {
                        vault.lock()
                        showPasswords = false
                    }
                }
            }

            if vault.savedConnectionIds.isEmpty {
                Text("No saved passwords yet.")
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 12) {
                    Button(showPasswords ? "Hide passwords" : "Show passwords") {
                        if showPasswords {
                            showPasswords = false
                        } else if vault.isUnlocked {
                            showPasswords = true
                        } else {
                            showUnlockPrompt = true
                        }
                    }

                    if !vault.isUnlocked {
                        Text("Vault locked")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Delete all") {
                        if vault.isUnlocked {
                            vault.removeAllPasswords()
                        } else {
                            showUnlockPrompt = true
                        }
                    }
                    .disabled(vault.savedConnectionIds.isEmpty)
                }

                List {
                    ForEach(vault.savedConnectionIds, id: \.self) { id in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(connectionName(for: id))
                                Text(connectionDetail(for: id))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(passwordDisplay(for: id))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Button("Remove") {
                                if vault.isUnlocked {
                                    vault.removePassword(for: id)
                                } else {
                                    showUnlockPrompt = true
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .frame(height: 220)
            }
        }
    }

    private var changePasswordSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Change master password")
                .font(.headline)

            SecureField("Current master password", text: $changeCurrentPassword)
            SecureField("New master password", text: $changeNewPassword)
            SecureField("Confirm new master password", text: $changeConfirmPassword)

            HStack {
                Button("Change") {
                    let success = vault.changeMasterPassword(
                        current: changeCurrentPassword,
                        new: changeNewPassword,
                        confirm: changeConfirmPassword
                    )
                    if success {
                        changeStatus = "Master password updated."
                        changeCurrentPassword = ""
                        changeNewPassword = ""
                        changeConfirmPassword = ""
                    } else {
                        changeStatus = "Could not change master password."
                    }
                }
                .disabled(changeCurrentPassword.isEmpty || changeNewPassword.isEmpty || changeConfirmPassword.isEmpty)

                if let changeStatus {
                    Text(changeStatus)
                        .font(.footnote)
                        .foregroundStyle(changeStatus.contains("updated") ? .green : .red)
                }
            }
        }
    }

    private func connectionName(for id: UUID) -> String {
        if let connection = store.connection(id: id) {
            return connection.displayName
        }
        return id.uuidString
    }

    private func connectionDetail(for id: UUID) -> String {
        if let connection = store.connection(id: id) {
            return "\(connection.username) @ \(connection.host)"
        }
        return "Unknown connection"
    }

    private func passwordDisplay(for id: UUID) -> String {
        if showPasswords, vault.isUnlocked {
            return vault.password(for: id) ?? ""
        }
        return "••••••••"
    }
}

private struct UnlockPrompt: View {
    @Binding var password: String
    @Binding var errorMessage: String?
    let onUnlock: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Unlock Password Manager")
                .font(.headline)
            SecureField("Master password", text: $password)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Spacer()
                Button("Unlock") {
                    onUnlock()
                }
                .disabled(password.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
