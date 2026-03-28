import Foundation

enum WatchMessageType: String, Codable {
    case alarmDataSync
    case alarmStateUpdate
    case snoozeSettingsSync
    case alarmTriggered
    case alarmDismissed
    case alarmSnoozed
    case connectionStatus
    case requestDataSync
    case ping
    case pong
}

struct WatchMessage: Codable {
    let type: WatchMessageType
    let timestamp: Date
    let payload: Data?
    
    init(type: WatchMessageType, payload: Data? = nil) {
        self.type = type
        self.timestamp = Date()
        self.payload = payload
    }
    
    func toDictionary() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return ["messageData": data]
    }
    
    static func from(dictionary: [String: Any]) -> WatchMessage? {
        guard let data = dictionary["messageData"] as? Data,
              let message = try? JSONDecoder().decode(WatchMessage.self, from: data) else {
            return nil
        }
        return message
    }
}

struct AlarmStateInfo: Codable {
    let alarmId: UUID
    let state: AlarmSyncState
    let timestamp: Date
    let snoozeCount: Int?
    let snoozeEndTime: Date?
    let triggerReason: String?
    let isSmartWake: Bool?
    
    init(
        alarmId: UUID,
        state: AlarmSyncState,
        snoozeCount: Int? = nil,
        snoozeEndTime: Date? = nil,
        triggerReason: String? = nil,
        isSmartWake: Bool? = nil
    ) {
        self.alarmId = alarmId
        self.state = state
        self.timestamp = Date()
        self.snoozeCount = snoozeCount
        self.snoozeEndTime = snoozeEndTime
        self.triggerReason = triggerReason
        self.isSmartWake = isSmartWake
    }
}

enum AlarmSyncState: String, Codable {
    case idle
    case scheduled
    case triggered
    case snoozed
    case dismissed
}

struct SnoozeSettings: Codable {
    let maxSnoozeCount: Int
    let defaultSnoozeInterval: Int
    let snoozeGesture: SnoozeGesture
    let snoozeEnabled: Bool
    
    init(
        maxSnoozeCount: Int = 3,
        defaultSnoozeInterval: Int = 5,
        snoozeGesture: SnoozeGesture = .snap,
        snoozeEnabled: Bool = true
    ) {
        self.maxSnoozeCount = maxSnoozeCount
        self.defaultSnoozeInterval = defaultSnoozeInterval
        self.snoozeGesture = snoozeGesture
        self.snoozeEnabled = snoozeEnabled
    }
}

struct AlarmsSyncPayload: Codable {
    let alarms: [AlarmSyncData]
    let syncReason: SyncReason
    
    init(alarms: [AlarmSyncData], syncReason: SyncReason = .manual) {
        self.alarms = alarms
        self.syncReason = syncReason
    }
}

enum SyncReason: String, Codable {
    case manual
    case automatic
    case onConnect
    case onAlarmChange
}

struct ConnectionStatusInfo: Codable {
    let isConnected: Bool
    let isReachable: Bool
    let lastActiveDate: Date?
    let pairedDeviceName: String?
    
    init(isConnected: Bool, isReachable: Bool, lastActiveDate: Date? = nil, pairedDeviceName: String? = nil) {
        self.isConnected = isConnected
        self.isReachable = isReachable
        self.lastActiveDate = lastActiveDate
        self.pairedDeviceName = pairedDeviceName
    }
}

enum WatchConnectivityError: Error, LocalizedError {
    case sessionNotActivated
    case notPaired
    case notReachable
    case transferFailed
    case encodingFailed
    case decodingFailed
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .sessionNotActivated:
            return "WatchConnectivity 会话未激活"
        case .notPaired:
            return "Apple Watch 未配对"
        case .notReachable:
            return "Apple Watch 不可达"
        case .transferFailed:
            return "数据传输失败"
        case .encodingFailed:
            return "数据编码失败"
        case .decodingFailed:
            return "数据解码失败"
        case .timeout:
            return "操作超时"
        }
    }
}
