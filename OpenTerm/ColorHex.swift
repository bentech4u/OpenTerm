import SwiftUI
import AppKit

enum ColorHex {
    static func toHex(_ color: Color) -> String {
        let nsColor = NSColor(color)
        guard let rgb = nsColor.usingColorSpace(.deviceRGB) else {
            return "#000000"
        }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    static func toColor(_ hex: String, fallback: Color = .black) -> Color {
        guard let nsColor = toNSColor(hex) else { return fallback }
        return Color(nsColor)
    }

    static func toNSColor(_ hex: String) -> NSColor? {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let value = cleaned.hasPrefix("#") ? String(cleaned.dropFirst()) : cleaned
        guard value.count == 6, let rgb = Int(value, radix: 16) else { return nil }
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
