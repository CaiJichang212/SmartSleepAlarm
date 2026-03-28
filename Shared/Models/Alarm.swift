import Foundation
import SwiftData

@Model
final class Alarm {
    var id: UUID
    var time: Date
    var repeatDays: [Int]
    var ringtone: String
    var label: String
    var isEnabled: Bool
    var isSmartModeEnabled: Bool
    var snoozeInterval: Int
    var snoozeGesture: SnoozeGesture
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        time: Date,
        repeatDays: [Int] = [],
        ringtone: String = "default",
        label: String = "",
        isEnabled: Bool = true,
        isSmartModeEnabled: Bool = false,
        snoozeInterval: Int = 5,
        snoozeGesture: SnoozeGesture = .snap,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.time = time
        self.repeatDays = repeatDays
        self.ringtone = ringtone
        self.label = label
        self.isEnabled = isEnabled
        self.isSmartModeEnabled = isSmartModeEnabled
        self.snoozeInterval = max(1, min(30, snoozeInterval))
        self.snoozeGesture = snoozeGesture
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    var repeatDaysDescription: String {
        if repeatDays.isEmpty {
            return "永不"
        } else if repeatDays.count == 7 {
            return "每天"
        } else if Set(repeatDays) == Set([1, 2, 3, 4, 5]) {
            return "工作日"
        } else if Set(repeatDays) == Set([0, 6]) {
            return "周末"
        } else {
            let dayNames = ["日", "一", "二", "三", "四", "五", "六"]
            return repeatDays.sorted().map { dayNames[$0] }.joined(separator: "、")
        }
    }
    
    var nextFireDate: Date? {
        let calendar = Calendar.current
        let now = Date()
        
        var alarmComponents = calendar.dateComponents([.year, .month, .day], from: time)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        alarmComponents.hour = timeComponents.hour
        alarmComponents.minute = timeComponents.minute
        alarmComponents.second = 0
        
        guard var nextDate = calendar.date(from: alarmComponents) else {
            return nil
        }
        
        if repeatDays.isEmpty {
            if nextDate <= now {
                nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
            }
            return nextDate
        }
        
        let currentWeekday = calendar.component(.weekday, from: now)
        let currentWeekdayIndex = currentWeekday - 1
        
        for offset in 0..<7 {
            let checkWeekday = (currentWeekdayIndex + offset) % 7
            if repeatDays.contains(checkWeekday) {
                var candidateDate = calendar.date(byAdding: .day, value: offset, to: nextDate) ?? nextDate
                if offset == 0 {
                    let adjustedComponents = calendar.dateComponents([.year, .month, .day], from: now)
                    var candidateComponents = calendar.dateComponents([.hour, .minute], from: time)
                    candidateComponents.year = adjustedComponents.year
                    candidateComponents.month = adjustedComponents.month
                    candidateComponents.day = adjustedComponents.day
                    candidateDate = calendar.date(from: candidateComponents) ?? nextDate
                    
                    if candidateDate <= now {
                        continue
                    }
                }
                return candidateDate
            }
        }
        
        return nil
    }
    
    var timeUntilFire: String? {
        guard let fireDate = nextFireDate else { return nil }
        let interval = fireDate.timeIntervalSinceNow
        
        if interval < 0 { return nil }
        
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 24 {
            let days = hours / 24
            return "\(days) 天后"
        } else if hours > 0 {
            return "\(hours) 小时 \(minutes) 分钟后"
        } else {
            return "\(minutes) 分钟后"
        }
    }
    
    func updateTimestamp() {
        updatedAt = Date()
    }
}

extension Alarm {
    static let defaultRingtones = [
        "default": "默认铃声",
        "gentle": "轻柔铃声",
        "nature": "自然之声",
        "classic": "经典闹铃",
        "digital": "数字铃声"
    ]
}
