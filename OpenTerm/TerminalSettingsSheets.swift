import SwiftUI
import AppKit

struct FontSettingsSheet: View {
    @Binding var fontName: String
    @Binding var fontSize: Double
    @Binding var isBold: Bool
    @Environment(\.dismiss) private var dismiss

    private let fonts = ["Monospaced"] + (NSFontManager.shared.availableFontFamilies).sorted()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Terminal Font")
                .font(.headline)

            Picker("Font", selection: $fontName) {
                ForEach(fonts, id: \.self) { font in
                    Text(font).tag(font)
                }
            }
            .frame(width: 320)

            HStack {
                Text("Size")
                Slider(value: $fontSize, in: 8...24, step: 1)
                    .frame(width: 200)
                Text("\(Int(fontSize))")
            }

            Toggle("Bold", isOn: $isBold)

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

struct ColorSettingsSheet: View {
    @Binding var foreground: Color
    @Binding var background: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Terminal Colors")
                .font(.headline)

            ColorPicker("Foreground", selection: $foreground)
            ColorPicker("Background", selection: $background)

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
