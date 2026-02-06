import Foundation
import Combine

enum PasswordSavePolicy: String, CaseIterable, Identifiable {
    case always
    case never
    case ask

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .always:
            return "Always"
        case .never:
            return "Never"
        case .ask:
            return "Ask"
        }
    }
}

struct SettingsSnapshot: Codable {
    var passwordSavePolicy: String
    var defaultTerminalFontName: String
    var defaultTerminalFontSize: Double
    var defaultTerminalFontBold: Bool
    var defaultTerminalForegroundHex: String
    var defaultTerminalBackgroundHex: String
    var pasteOnRightClick: Bool
    var warnBeforePaste: Bool
    var selectToCopyEnabled: Bool
    var logTerminalEnabled: Bool
    var logTerminalDirectory: String
    var sshBrowserEnabled: Bool
    var sshKeepAliveSeconds: Int
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var passwordSavePolicy: PasswordSavePolicy {
        didSet {
            UserDefaults.standard.set(passwordSavePolicy.rawValue, forKey: Self.policyKey)
        }
    }

    @Published var defaultTerminalFontName: String {
        didSet {
            UserDefaults.standard.set(defaultTerminalFontName, forKey: Self.defaultFontNameKey)
        }
    }

    @Published var defaultTerminalFontSize: Double {
        didSet {
            UserDefaults.standard.set(defaultTerminalFontSize, forKey: Self.defaultFontSizeKey)
        }
    }

    @Published var defaultTerminalFontBold: Bool {
        didSet {
            UserDefaults.standard.set(defaultTerminalFontBold, forKey: Self.defaultFontBoldKey)
        }
    }

    @Published var defaultTerminalForegroundHex: String {
        didSet {
            UserDefaults.standard.set(defaultTerminalForegroundHex, forKey: Self.defaultForegroundKey)
        }
    }

    @Published var defaultTerminalBackgroundHex: String {
        didSet {
            UserDefaults.standard.set(defaultTerminalBackgroundHex, forKey: Self.defaultBackgroundKey)
        }
    }

    @Published var pasteOnRightClick: Bool {
        didSet {
            UserDefaults.standard.set(pasteOnRightClick, forKey: Self.pasteOnRightClickKey)
        }
    }

    @Published var warnBeforePaste: Bool {
        didSet {
            UserDefaults.standard.set(warnBeforePaste, forKey: Self.warnBeforePasteKey)
        }
    }

    @Published var selectToCopyEnabled: Bool {
        didSet {
            UserDefaults.standard.set(selectToCopyEnabled, forKey: Self.selectToCopyKey)
        }
    }

    @Published var logTerminalEnabled: Bool {
        didSet {
            UserDefaults.standard.set(logTerminalEnabled, forKey: Self.logTerminalEnabledKey)
        }
    }

    @Published var logTerminalDirectory: String {
        didSet {
            UserDefaults.standard.set(logTerminalDirectory, forKey: Self.logTerminalDirectoryKey)
        }
    }

    @Published var sshBrowserEnabled: Bool {
        didSet {
            UserDefaults.standard.set(sshBrowserEnabled, forKey: Self.sshBrowserEnabledKey)
        }
    }

    @Published var sshKeepAliveSeconds: Int {
        didSet {
            UserDefaults.standard.set(sshKeepAliveSeconds, forKey: Self.sshKeepAliveSecondsKey)
        }
    }

    private static let policyKey = "passwordSavePolicy"
    private static let defaultFontNameKey = "defaultTerminalFontName"
    private static let defaultFontSizeKey = "defaultTerminalFontSize"
    private static let defaultFontBoldKey = "defaultTerminalFontBold"
    private static let defaultForegroundKey = "defaultTerminalForegroundHex"
    private static let defaultBackgroundKey = "defaultTerminalBackgroundHex"
    private static let pasteOnRightClickKey = "pasteOnRightClick"
    private static let warnBeforePasteKey = "warnBeforePaste"
    private static let selectToCopyKey = "selectToCopyEnabled"
    private static let logTerminalEnabledKey = "logTerminalEnabled"
    private static let logTerminalDirectoryKey = "logTerminalDirectory"
    private static let sshBrowserEnabledKey = "sshBrowserEnabled"
    private static let sshKeepAliveSecondsKey = "sshKeepAliveSeconds"

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.policyKey),
           let policy = PasswordSavePolicy(rawValue: raw) {
            passwordSavePolicy = policy
        } else {
            passwordSavePolicy = .always
        }

        defaultTerminalFontName = UserDefaults.standard.string(forKey: Self.defaultFontNameKey) ?? "Monospaced"

        if let stored = UserDefaults.standard.object(forKey: Self.defaultFontSizeKey) as? NSNumber {
            defaultTerminalFontSize = stored.doubleValue
        } else {
            defaultTerminalFontSize = 12
        }

        if UserDefaults.standard.object(forKey: Self.defaultFontBoldKey) != nil {
            defaultTerminalFontBold = UserDefaults.standard.bool(forKey: Self.defaultFontBoldKey)
        } else {
            defaultTerminalFontBold = false
        }

        defaultTerminalForegroundHex = UserDefaults.standard.string(forKey: Self.defaultForegroundKey) ?? "#E6E6E6"
        defaultTerminalBackgroundHex = UserDefaults.standard.string(forKey: Self.defaultBackgroundKey) ?? "#000000"

        if UserDefaults.standard.object(forKey: Self.pasteOnRightClickKey) != nil {
            pasteOnRightClick = UserDefaults.standard.bool(forKey: Self.pasteOnRightClickKey)
        } else {
            pasteOnRightClick = false
        }

        if UserDefaults.standard.object(forKey: Self.warnBeforePasteKey) != nil {
            warnBeforePaste = UserDefaults.standard.bool(forKey: Self.warnBeforePasteKey)
        } else {
            warnBeforePaste = false
        }

        if UserDefaults.standard.object(forKey: Self.selectToCopyKey) != nil {
            selectToCopyEnabled = UserDefaults.standard.bool(forKey: Self.selectToCopyKey)
        } else {
            selectToCopyEnabled = false
        }

        if UserDefaults.standard.object(forKey: Self.logTerminalEnabledKey) != nil {
            logTerminalEnabled = UserDefaults.standard.bool(forKey: Self.logTerminalEnabledKey)
        } else {
            logTerminalEnabled = false
        }

        logTerminalDirectory = UserDefaults.standard.string(forKey: Self.logTerminalDirectoryKey) ?? ""

        if UserDefaults.standard.object(forKey: Self.sshBrowserEnabledKey) != nil {
            sshBrowserEnabled = UserDefaults.standard.bool(forKey: Self.sshBrowserEnabledKey)
        } else {
            sshBrowserEnabled = true
        }

        if let stored = UserDefaults.standard.object(forKey: Self.sshKeepAliveSecondsKey) as? NSNumber {
            sshKeepAliveSeconds = stored.intValue
        } else {
            sshKeepAliveSeconds = 60
        }
    }

    func snapshot() -> SettingsSnapshot {
        SettingsSnapshot(
            passwordSavePolicy: passwordSavePolicy.rawValue,
            defaultTerminalFontName: defaultTerminalFontName,
            defaultTerminalFontSize: defaultTerminalFontSize,
            defaultTerminalFontBold: defaultTerminalFontBold,
            defaultTerminalForegroundHex: defaultTerminalForegroundHex,
            defaultTerminalBackgroundHex: defaultTerminalBackgroundHex,
            pasteOnRightClick: pasteOnRightClick,
            warnBeforePaste: warnBeforePaste,
            selectToCopyEnabled: selectToCopyEnabled,
            logTerminalEnabled: logTerminalEnabled,
            logTerminalDirectory: logTerminalDirectory,
            sshBrowserEnabled: sshBrowserEnabled,
            sshKeepAliveSeconds: sshKeepAliveSeconds
        )
    }

    func apply(snapshot: SettingsSnapshot) {
        if let policy = PasswordSavePolicy(rawValue: snapshot.passwordSavePolicy) {
            passwordSavePolicy = policy
        }
        defaultTerminalFontName = snapshot.defaultTerminalFontName
        defaultTerminalFontSize = snapshot.defaultTerminalFontSize
        defaultTerminalFontBold = snapshot.defaultTerminalFontBold
        defaultTerminalForegroundHex = snapshot.defaultTerminalForegroundHex
        defaultTerminalBackgroundHex = snapshot.defaultTerminalBackgroundHex
        pasteOnRightClick = snapshot.pasteOnRightClick
        warnBeforePaste = snapshot.warnBeforePaste
        selectToCopyEnabled = snapshot.selectToCopyEnabled
        logTerminalEnabled = snapshot.logTerminalEnabled
        logTerminalDirectory = snapshot.logTerminalDirectory
        sshBrowserEnabled = snapshot.sshBrowserEnabled
        sshKeepAliveSeconds = snapshot.sshKeepAliveSeconds
    }
}
