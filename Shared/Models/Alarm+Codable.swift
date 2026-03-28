import Foundation

extension Alarm: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case time
        case repeatDays
        case ringtone
        case label
        case isEnabled
        case isSmartModeEnabled
        case snoozeInterval
        case snoozeGesture
        case createdAt
        case updatedAt
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let gestureRawValue = try container.decode(String.self, forKey: .snoozeGesture)
        let snoozeGesture = SnoozeGesture(rawValue: gestureRawValue) ?? .snap
        
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            time: try container.decode(Date.self, forKey: .time),
            repeatDays: try container.decode([Int].self, forKey: .repeatDays),
            ringtone: try container.decode(String.self, forKey: .ringtone),
            label: try container.decode(String.self, forKey: .label),
            isEnabled: try container.decode(Bool.self, forKey: .isEnabled),
            isSmartModeEnabled: try container.decode(Bool.self, forKey: .isSmartModeEnabled),
            snoozeInterval: try container.decode(Int.self, forKey: .snoozeInterval),
            snoozeGesture: snoozeGesture,
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt)
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(time, forKey: .time)
        try container.encode(repeatDays, forKey: .repeatDays)
        try container.encode(ringtone, forKey: .ringtone)
        try container.encode(label, forKey: .label)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(isSmartModeEnabled, forKey: .isSmartModeEnabled)
        try container.encode(snoozeInterval, forKey: .snoozeInterval)
        try container.encode(snoozeGesture.rawValue, forKey: .snoozeGesture)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}
