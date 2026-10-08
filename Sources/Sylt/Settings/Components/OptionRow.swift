import SwiftUI

/// One line inside a plugin's options box: the title on the left, its control on the right.
struct OptionRow<Control: View>: View {
    let title: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack {
            Text(title).font(.callout)
            Spacer()
            control
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}

struct OptionSwitch: View {
    let isOn: Binding<Bool>

    var body: some View {
        Toggle("", isOn: isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
    }
}
