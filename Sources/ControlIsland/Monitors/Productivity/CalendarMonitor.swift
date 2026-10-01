import Combine
import EventKit
import Foundation

/// The next timed event in the coming day, with reminders shortly before and at its start.
@MainActor
final class CalendarMonitor: ObservableObject {
    struct Event: Hashable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let joinURL: URL?
    }

    @Published private(set) var next: Event?
    /// The next event starts within half an hour, so it earns a spot in the wing.
    @Published private(set) var imminent = false
    @Published private(set) var authorized = false
    let reminders = PassthroughSubject<Event, Never>()

    static let reminderLead: TimeInterval = 5 * 60

    private let store = EKEventStore()
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    private var reminded: Set<String> = []

    func start() {
        guard timer == nil else { return }
        Task {
            authorized = (try? await store.requestFullAccessToEvents()) ?? false
            refresh()
        }
        timer = .every(20) { [weak self] in self?.refresh() }
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        observer.map(NotificationCenter.default.removeObserver)
        observer = nil
        next = nil
        imminent = false
    }

    private func refresh() {
        guard authorized else { return }
        let now = Date()
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-3600), end: now.addingTimeInterval(86400), calendars: nil)
        let upcoming = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.endDate > now && $0.status != .canceled }
            .sorted { $0.startDate < $1.startDate }
        next = upcoming.first.map { event in
            Event(
                id: event.eventIdentifier ?? "\(event.title ?? "")\(event.startDate.timeIntervalSince1970)",
                title: event.title ?? "Untitled",
                start: event.startDate,
                end: event.endDate,
                joinURL: Self.joinURL(in: event)
            )
        }
        imminent = next.map { $0.start.timeIntervalSince(now) < 30 * 60 } ?? false
        remind(now: now)
    }

    private func remind(now: Date) {
        guard let next else { return }
        let lead = next.start.timeIntervalSince(now)
        let soon = "\(next.id)@soon", starting = "\(next.id)@start"
        if lead > 0, lead <= Self.reminderLead, !reminded.contains(soon) {
            reminded.insert(soon)
            reminders.send(next)
        } else if lead <= 0, lead > -60, !reminded.contains(starting) {
            reminded.insert(starting)
            reminders.send(next)
        }
    }

    /// A video-call link from the event's URL, location or notes.
    private static func joinURL(in event: EKEvent) -> URL? {
        let hosts = ["zoom.us", "meet.google.com", "teams.microsoft.com", "webex.com", "whereby.com", "meet.jit.si"]
        let candidates = [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }
        for text in candidates {
            guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { continue }
            let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
            if let url = matches.compactMap(\.url).first(where: { url in hosts.contains { url.host?.hasSuffix($0) == true } }) {
                return url
            }
        }
        return nil
    }
}
