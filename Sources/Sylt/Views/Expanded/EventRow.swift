import SwiftUI

struct EventRow: View {
    let event: CalendarMonitor.Event

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(event.start, format: .dateTime.hour().minute())
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(event.end, format: .dateTime.hour().minute())
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .monospacedDigit()
            }
            .frame(width: 40, alignment: .leading)
            Text(event.title).lineLimit(1)
            Spacer()
            if let url = event.joinURL {
                Button {
                    NSWorkspace.shared.open(url)
                    Haptics.press()
                } label: {
                    Label("Join", systemImage: "video.fill")
                }
                .buttonStyle(Pill(tint: .green.opacity(0.9)))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: IslandLayout.eventRowHeight)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            NSWorkspace.shared.open(URL(string: "ical://ekevent/\(event.id)") ?? URL(fileURLWithPath: "/System/Applications/Calendar.app"))
            Haptics.press()
        }
    }
}
