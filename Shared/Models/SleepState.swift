import Foundation

enum SleepState: String, Codable, CaseIterable {
    case asleep = "睡眠"
    case awake = "清醒"
    case unknown = "未知"
    
    var displayName: String {
        rawValue
    }
    
    var icon: String {
        switch self {
        case .asleep: return "moon.zzz"
        case .awake: return "sun.max"
        case .unknown: return "questionmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .asleep: return "blue"
        case .awake: return "orange"
        case .unknown: return "gray"
        }
    }
}
