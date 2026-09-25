import SwiftUI

struct LevelSlider: View {
    let symbol: String
    let value: Float
    let onChange: (Float) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            Slider(value: Binding(get: { Double(value) }, set: { onChange(Float($0)) }), in: 0...1)
                .controlSize(.small)
        }
    }
}
