import Foundation

struct SleepData: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let sleepQuality: Double
    let sleepPhase: SleepPhase
    
    init(id: UUID = UUID(), startTime: Date, endTime: Date, sleepQuality: Double, sleepPhase: SleepPhase) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.sleepQuality = sleepQuality
        self.sleepPhase = sleepPhase
    }
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

enum SleepPhase: String, Codable, CaseIterable {
    case awake = "清醒"
    case light = "浅睡"
    case deep = "深睡"
    case rem = "REM"
    
    var displayName: String {
        rawValue
    }
    
    var icon: String {
        switch self {
        case .awake: return "eye"
        case .light: return "moon"
        case .deep: return "bed.double"
        case .rem: return "brain"
        }
    }
}
