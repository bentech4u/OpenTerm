import Foundation
import AppKit
import Combine

@MainActor
final class RdpSession: ObservableObject, Identifiable {
    let id = UUID()
    let connection: Connection
    let title: String

    private let client: OpenTermRdpClient

    init(connection: Connection, password: String?) {
        self.connection = connection
        self.title = connection.displayName

        let config = OpenTermRdpConfig()
        config.hostname = connection.host
        config.port = UInt16(connection.port)
        config.username = connection.username
        config.password = password ?? ""
        config.displayMode = Self.mapDisplayMode(connection.rdpDisplayMode)
        config.width = connection.rdpWidth
        config.height = connection.rdpHeight
        config.clipboardEnabled = connection.rdpClipboardEnabled
        config.soundMode = Self.mapSoundMode(connection.rdpSoundMode)
        config.driveRedirectionEnabled = connection.rdpDriveRedirectionEnabled
        config.performanceProfile = Self.mapPerformanceProfile(connection.rdpPerformanceProfile)

        self.client = OpenTermRdpClient(config: config)
        self.client.connect()
    }

    var view: NSView {
        client.view
    }

    func updateViewport(size: NSSize) {
        client.updateViewportWidth(Int(size.width), height: Int(size.height))
    }

    func disconnect() {
        client.disconnect()
    }

    private static func mapDisplayMode(_ mode: RdpDisplayMode) -> OpenTermRdpDisplayMode {
        switch mode {
        case .fitToWindow:
            return .fitToWindow
        case .fullscreen:
            return .fullscreen
        case .fixed:
            return .fixed
        }
    }

    private static func mapSoundMode(_ mode: RdpSoundMode) -> OpenTermRdpSoundMode {
        switch mode {
        case .off:
            return .off
        case .local:
            return .local
        case .remote:
            return .remote
        }
    }

    private static func mapPerformanceProfile(_ profile: RdpPerformanceProfile) -> OpenTermRdpPerformanceProfile {
        switch profile {
        case .bestQuality:
            return .bestQuality
        case .balanced:
            return .balanced
        case .bestPerformance:
            return .bestPerformance
        }
    }
}
