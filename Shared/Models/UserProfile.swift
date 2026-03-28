import Foundation

struct UserProfile: Codable {
    var id: UUID
    var name: String
    var targetSleepDuration: TimeInterval
    var preferredBedtime: Date?
    var preferredWakeTime: Date?
    var healthKitEnabled: Bool
    var notificationsEnabled: Bool
    
    init(
        id: UUID = UUID(),
        name: String = "",
        targetSleepDuration: TimeInterval = 8 * 60 * 60,
        preferredBedtime: Date? = nil,
        preferredWakeTime: Date? = nil,
        healthKitEnabled: Bool = false,
        notificationsEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.targetSleepDuration = targetSleepDuration
        self.preferredBedtime = preferredBedtime
        self.preferredWakeTime = preferredWakeTime
        self.healthKitEnabled = healthKitEnabled
        self.notificationsEnabled = notificationsEnabled
    }
}
