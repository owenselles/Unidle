import Foundation

/// A recurring weekly window, stored as minutes from midnight so it survives
/// timezone changes without dragging absolute dates around.
struct WorkSchedule: Equatable {
    /// `Calendar` weekday numbers: 1 = Sunday ... 7 = Saturday.
    var days: Set<Int>
    var startMinutes: Int
    var endMinutes: Int

    static let `default` = WorkSchedule(days: [2, 3, 4, 5, 6], startMinutes: 9 * 60, endMinutes: 17 * 60)

    /// Windows that end before they start are treated as running overnight,
    /// so 22:00–06:00 covers the small hours of the *following* day.
    var isOvernight: Bool { endMinutes <= startMinutes }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = parts.weekday, let hour = parts.hour, let minute = parts.minute else { return false }
        let nowMinutes = hour * 60 + minute

        if isOvernight {
            if days.contains(weekday) && nowMinutes >= startMinutes { return true }
            let previousDay = weekday == 1 ? 7 : weekday - 1
            return days.contains(previousDay) && nowMinutes < endMinutes
        }
        return days.contains(weekday) && nowMinutes >= startMinutes && nowMinutes < endMinutes
    }

    var summary: String {
        guard !days.isEmpty else { return "No days selected" }
        return "\(Self.dayList(days)) · \(Self.timeLabel(startMinutes))–\(Self.timeLabel(endMinutes))"
    }

    static func timeLabel(_ minutes: Int) -> String {
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private static func dayList(_ days: Set<Int>) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        if days == [2, 3, 4, 5, 6] { return "Weekdays" }
        if days.count == 7 { return "Every day" }
        return days.sorted().map { symbols[$0 - 1] }.joined(separator: " ")
    }
}
