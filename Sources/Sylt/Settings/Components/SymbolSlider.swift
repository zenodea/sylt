import SwiftUI

struct SymbolSlider: View {
    let title: String
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let step: Double
    let low: String
    let high: String

    init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double, low: String, high: String) {
        self.title = title
        self.value = value
        self.range = range
        self.step = step
        self.low = low
        self.high = high
    }

    init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double, symbol: String) {
        self.init(title, value: value, in: range, step: step, low: symbol, high: symbol)
    }

    var body: some View {
        Slider(value: value, in: range, step: step) {
            Text(title)
        } minimumValueLabel: {
            Image(systemName: low).imageScale(.small)
        } maximumValueLabel: {
            Image(systemName: high).imageScale(.large)
        }
    }
}
