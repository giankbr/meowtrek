import UserNotifications

enum Notifier {
    static func requestAuth() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(_ s: AppState) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard s.remindersOn else { return }
        let cal = Calendar.current
        let now = Date()
        for offset in 0..<7 {
            if offset == 0 && s.remaining == 0 { continue }
            var dc = cal.dateComponents([.year, .month, .day], from: cal.date(byAdding: .day, value: offset, to: now)!)
            dc.hour = s.reminderHour
            guard let fire = cal.date(from: dc), fire > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = loc("\(s.petName) wants a walk")
            content.body = offset == 0
                ? loc("\(s.remaining.formatted()) steps to go today. The light won't wait.")
                : s.streak > 0 ? loc("Your streak is \(s.streak) days. Let's keep it going!") : loc("A short walk makes a happy cat.")
            content.sound = .default
            center.add(UNNotificationRequest(identifier: "remind-\(offset)", content: content,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)))
        }
        if let a = s.activeEvent, let last = cal.date(byAdding: .day, value: -1, to: a.end) {
            var dc = cal.dateComponents([.year, .month, .day], from: last)
            dc.hour = 10
            if let fire = cal.date(from: dc), fire > now {
                let content = UNMutableNotificationContent()
                content.title = loc("\(a.event.name) ends tomorrow")
                content.body = loc("Collect your last \(a.event.token) and claim your rewards.")
                center.add(UNNotificationRequest(identifier: "event-end", content: content,
                                                 trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)))
            }
        }
    }
}
