import Foundation
import SwiftData

enum AlarmSyncKey: String {
    case alarms = "synced_alarms"
    case lastSyncTime = "last_sync_time"
    case pendingChanges = "pending_changes"
}

class SharedDataManager {
    static let shared = SharedDataManager()
    
    private let defaults: UserDefaults?
    private let syncQueue = DispatchQueue(label: "com.smartsleep.alarm.sync", qos: .userInitiated)
    
    private init() {
        defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
    }
    
    func save<T: Codable>(_ value: T, forKey key: String) {
        syncQueue.async { [weak self] in
            if let data = try? JSONEncoder().encode(value) {
                self?.defaults?.set(data, forKey: key)
            }
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults?.data(forKey: key),
              let value = try? JSONDecoder().decode(T.self, from: data) else {
            return nil
        }
        return value
    }
    
    func remove(forKey key: String) {
        defaults?.removeObject(forKey: key)
    }
    
    func syncAlarms(_ alarms: [AlarmSyncData]) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            if let data = try? JSONEncoder().encode(alarms) {
                self.defaults?.set(data, forKey: AlarmSyncKey.alarms.rawValue)
                self.defaults?.set(Date(), forKey: AlarmSyncKey.lastSyncTime.rawValue)
            }
        }
    }
    
    func loadSyncedAlarms() -> [AlarmSyncData]? {
        guard let data = defaults?.data(forKey: AlarmSyncKey.alarms.rawValue),
              let alarms = try? JSONDecoder().decode([AlarmSyncData].self, from: data) else {
            return nil
        }
        return alarms
    }
    
    func getLastSyncTime() -> Date? {
        defaults?.object(forKey: AlarmSyncKey.lastSyncTime.rawValue) as? Date
    }
    
    func addPendingChange(_ change: AlarmChange) {
        var pendingChanges = loadPendingChanges() ?? []
        pendingChanges.append(change)
        save(pendingChanges, forKey: AlarmSyncKey.pendingChanges.rawValue)
    }
    
    func loadPendingChanges() -> [AlarmChange]? {
        load([AlarmChange].self, forKey: AlarmSyncKey.pendingChanges.rawValue)
    }
    
    func clearPendingChanges() {
        remove(forKey: AlarmSyncKey.pendingChanges.rawValue)
    }
    
    func clearAllSyncData() {
        remove(forKey: AlarmSyncKey.alarms.rawValue)
        remove(forKey: AlarmSyncKey.lastSyncTime.rawValue)
        remove(forKey: AlarmSyncKey.pendingChanges.rawValue)
    }
}

struct AlarmSyncData: Codable, Identifiable {
    let id: UUID
    let time: Date
    let repeatDays: [Int]
    let ringtone: String
    let label: String
    let isEnabled: Bool
    let isSmartModeEnabled: Bool
    let snoozeInterval: Int
    let snoozeGestureRawValue: String
    let createdAt: Date
    let updatedAt: Date
    
    var snoozeGesture: SnoozeGesture {
        SnoozeGesture(rawValue: snoozeGestureRawValue) ?? .snap
    }
    
    init(
        id: UUID,
        time: Date,
        repeatDays: [Int],
        ringtone: String,
        label: String,
        isEnabled: Bool,
        isSmartModeEnabled: Bool,
        snoozeInterval: Int,
        snoozeGesture: SnoozeGesture,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.time = time
        self.repeatDays = repeatDays
        self.ringtone = ringtone
        self.label = label
        self.isEnabled = isEnabled
        self.isSmartModeEnabled = isSmartModeEnabled
        self.snoozeInterval = snoozeInterval
        self.snoozeGestureRawValue = snoozeGesture.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum AlarmChangeType: String, Codable {
    case add
    case update
    case delete
}

struct AlarmChange: Codable {
    let id: UUID
    let type: AlarmChangeType
    let timestamp: Date
    let alarmData: AlarmSyncData?
    
    init(from syncData: AlarmSyncData, type: AlarmChangeType) {
        self.id = syncData.id
        self.type = type
        self.timestamp = Date()
        self.alarmData = syncData
    }
    
    init(deleteAlarmId id: UUID) {
        self.id = id
        self.type = .delete
        self.timestamp = Date()
        self.alarmData = nil
    }
}
