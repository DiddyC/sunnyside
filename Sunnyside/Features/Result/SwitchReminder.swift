import Foundation
import UserNotifications

/// Schedules a one-off local notification shortly before the sun changes sides.
enum SwitchReminder {
    static let leadTime: TimeInterval = 5 * 60

    static func schedule(at switchTime: Date, journey: Journey, newShadySide: SeatSide) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }

        let fire = max(Date().addingTimeInterval(5), switchTime.addingTimeInterval(-leadTime))
        let content = UNMutableNotificationContent()
        content.title = "Coolside: the sun is about to switch sides"
        content.body = "In about 5 minutes the shade moves to the \(newShadySide == .left ? "left" : "right") on your \(journey.vehicle.displayName.lowercased()) to \(journey.destination.name)."
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "sunnyside.switch.\(Int(switchTime.timeIntervalSince1970))", content: content, trigger: trigger)
        do { try await center.add(request); return true } catch { return false }
    }
}
