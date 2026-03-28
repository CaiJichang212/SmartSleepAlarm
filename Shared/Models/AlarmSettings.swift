import Foundation

struct AlarmSettings: Codable, Identifiable {
    let id: UUID
    var isEnabled: Bool
    var targetWakeTime: Date
    var smartAlarmWindow: TimeInterval
    var alarmSound: String
    var vibrationEnabled: Bool
    var snoozeEnabled: Bool
    var snoozeDuration: TimeInterval
    
    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        targetWakeTime: Date,
        smartAlarmWindow: TimeInterval = 30 * 60,
        alarmSound: String = "default",
        vibrationEnabled: Bool = true,
        snoozeEnabled: Bool = true,
        snoozeDuration: TimeInterval = 5 * 60
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.targetWakeTime = targetWakeTime
        self.smartAlarmWindow = smartAlarmWindow
        self.alarmSound = alarmSound
        self.vibrationEnabled = vibrationEnabled
        self.snoozeEnabled = snoozeEnabled
        self.snoozeDuration = snoozeDuration
    }
    
    var smartAlarmStartTime: Date {
        targetWakeTime.addingTimeInterval(-smartAlarmWindow)
    }
}
