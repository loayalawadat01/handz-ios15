import Foundation

/// Shared formatter so every screen shows schedule info consistently
/// (spec item 9: "Flexible timing" or the exact date/time, same slot).
enum ScheduleDisplay {
    static func text(scheduledAt: Date, isFlexible: Bool) -> String {
        if isFlexible {
            return "Flexible timing"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: scheduledAt)
    }
}
