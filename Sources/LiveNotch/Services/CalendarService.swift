import AppKit
import EventKit
import Combine

// ═══════════════════════════════════════════════════
// MARK: - 📅 Calendar Service
// ═══════════════════════════════════════════════════
// Extracted from SystemServices.swift — EventKit integration

final class CalendarService: ObservableObject {
    static let shared = CalendarService()
    
    struct CalEvent: Identifiable {
        let id: String
        let title: String
        let startDate: Date
        let endDate: Date
        let calendarColor: NSColor?
        let isAllDay: Bool
        
        var timeString: String {
            if isAllDay { return "All day" }
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: startDate)
        }
        
        var minutesUntil: Int {
            Int(startDate.timeIntervalSince(Date()) / 60)
        }
        
        var urgencyColor: NSColor {
            let m = minutesUntil
            if m < 5 { return .systemRed }
            if m < 15 { return .systemOrange }
            if m < 60 { return .systemYellow }
            return .systemGreen
        }
        
        /// Attempt to extract a meeting join URL from the event title
        var meetingURL: URL? {
            // Common patterns: zoom.us, teams.microsoft.com, meet.google.com
            let patterns = ["zoom.us", "teams.microsoft.com", "meet.google.com", "webex.com"]
            for pattern in patterns {
                if title.contains(pattern), let range = title.range(of: "https://[^ ]+", options: .regularExpression) {
                    return URL(string: String(title[range]))
                }
            }
            return nil
        }
    }
    
    @Published var nextEvent: CalEvent? = nil
    @Published var todayEvents: [CalEvent] = []
    @Published var hasAccess = false
    
    private let store = EKEventStore()
    private var timer: Timer?
    
    private init() {
        requestAccess()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func requestAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.hasAccess = granted
                    if granted { self?.fetchEvents() }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.hasAccess = granted
                    if granted { self?.fetchEvents() }
                }
            }
        }
        
        // Refresh every 60 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.fetchEvents()
        }
    }
    
    func fetchEvents() {
        guard hasAccess else { return }
        
        let now = Date()
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
        
        let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .prefix(5)
            .map { event in
                CalEvent(
                    id: event.eventIdentifier,
                    title: event.title ?? "Event",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    calendarColor: event.calendar.color,
                    isAllDay: event.isAllDay
                )
            }
        
        DispatchQueue.main.async { [weak self] in
            self?.todayEvents = Array(events)
            self?.nextEvent = events.first
        }
    }
}
