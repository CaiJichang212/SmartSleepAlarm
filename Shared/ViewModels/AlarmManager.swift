import Foundation
import SwiftData
import Combine

@MainActor
class AlarmManager: ObservableObject {
    @Published var alarms: [Alarm] = []
    @Published var lastReceivedAlarmState: AlarmStateInfo?
    
    private let modelContext: ModelContext
    private let sharedDataManager = SharedDataManager.shared
    private let watchConnectivity = WatchConnectivityManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(modelContext: ModelContext = SwiftDataConfig.modelContext) {
        self.modelContext = modelContext
        fetchAlarms()
        setupWatchConnectivityCallbacks()
    }
    
    private func setupWatchConnectivityCallbacks() {
        watchConnectivity.onAlarmStateReceived = { [weak self] stateInfo in
            self?.handleAlarmStateReceived(stateInfo)
        }
        
        watchConnectivity.onDataSyncRequested = { [weak self] in
            self?.syncWithWatch()
        }
        
        watchConnectivity.$isWatchReachable
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReachable in
                if isReachable {
                    self?.syncWithWatch()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleAlarmStateReceived(_ stateInfo: AlarmStateInfo) {
        lastReceivedAlarmState = stateInfo
        
        switch stateInfo.state {
        case .triggered:
            print("Alarm \(stateInfo.alarmId) triggered on Watch")
            NotificationCenter.default.post(
                name: .alarmDidTriggerOnWatch,
                object: nil,
                userInfo: ["alarmId": stateInfo.alarmId, "isSmartWake": stateInfo.isSmartWake ?? false]
            )
        case .dismissed:
            print("Alarm \(stateInfo.alarmId) dismissed on Watch")
            NotificationCenter.default.post(
                name: .alarmDidDismissOnWatch,
                object: nil,
                userInfo: ["alarmId": stateInfo.alarmId]
            )
        case .snoozed:
            print("Alarm \(stateInfo.alarmId) snoozed on Watch (count: \(stateInfo.snoozeCount ?? 0))")
            NotificationCenter.default.post(
                name: .alarmDidSnoozeOnWatch,
                object: nil,
                userInfo: [
                    "alarmId": stateInfo.alarmId,
                    "snoozeCount": stateInfo.snoozeCount ?? 0,
                    "snoozeEndTime": stateInfo.snoozeEndTime ?? Date()
                ]
            )
        default:
            break
        }
    }
    
    func fetchAlarms() {
        let descriptor = FetchDescriptor<Alarm>(sortBy: [SortDescriptor(\.time)])
        do {
            alarms = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch alarms: \(error)")
        }
    }
    
    func addAlarm(
        time: Date,
        repeatDays: [Int] = [],
        ringtone: String = "default",
        label: String = "",
        isEnabled: Bool = true,
        isSmartModeEnabled: Bool = false,
        snoozeInterval: Int = 5,
        snoozeGesture: SnoozeGesture = .snap
    ) -> Alarm {
        let alarm = Alarm(
            time: time,
            repeatDays: repeatDays,
            ringtone: ringtone,
            label: label,
            isEnabled: isEnabled,
            isSmartModeEnabled: isSmartModeEnabled,
            snoozeInterval: snoozeInterval,
            snoozeGesture: snoozeGesture
        )
        
        modelContext.insert(alarm)
        saveAndSync()
        
        sharedDataManager.addPendingChange(AlarmChange(type: .add, alarm: alarm))
        
        return alarm
    }
    
    func updateAlarm(_ alarm: Alarm) {
        alarm.updateTimestamp()
        saveAndSync()
        
        sharedDataManager.addPendingChange(AlarmChange(type: .update, alarm: alarm))
    }
    
    func deleteAlarm(_ alarm: Alarm) {
        modelContext.delete(alarm)
        saveAndSync()
        
        sharedDataManager.addPendingChange(AlarmChange(deleteAlarmId: alarm.id))
    }
    
    func deleteAlarm(at offsets: IndexSet) {
        for index in offsets {
            let alarm = alarms[index]
            deleteAlarm(alarm)
        }
    }
    
    func toggleAlarm(_ alarm: Alarm) {
        alarm.isEnabled.toggle()
        updateAlarm(alarm)
    }
    
    func toggleSmartMode(_ alarm: Alarm) {
        alarm.isSmartModeEnabled.toggle()
        updateAlarm(alarm)
    }
    
    func syncWithWatch() {
        sharedDataManager.syncAlarms(alarms)
        
        watchConnectivity.sendAlarmsToWatch(alarms, reason: .onAlarmChange)
        watchConnectivity.updateApplicationContext(alarms: alarms)
    }
    
    func syncWithWatch(reason: SyncReason) {
        sharedDataManager.syncAlarms(alarms)
        
        watchConnectivity.sendAlarmsToWatch(alarms, reason: reason)
        watchConnectivity.updateApplicationContext(alarms: alarms)
    }
    
    func sendSnoozeSettingsToWatch(settings: SnoozeSettings) {
        watchConnectivity.sendSnoozeSettingsToWatch(settings)
    }
    
    func importFromWatch() {
        guard let syncedAlarms = sharedDataManager.loadSyncedAlarms() else { return }
        
        for syncData in syncedAlarms {
            let existingAlarm = alarms.first { $0.id == syncData.id }
            
            if let existing = existingAlarm {
                if syncData.updatedAt > existing.updatedAt {
                    existing.time = syncData.time
                    existing.repeatDays = syncData.repeatDays
                    existing.ringtone = syncData.ringtone
                    existing.label = syncData.label
                    existing.isEnabled = syncData.isEnabled
                    existing.isSmartModeEnabled = syncData.isSmartModeEnabled
                    existing.snoozeInterval = syncData.snoozeInterval
                    existing.snoozeGesture = syncData.snoozeGesture
                    existing.updatedAt = syncData.updatedAt
                }
            } else {
                let newAlarm = syncData.toAlarm()
                modelContext.insert(newAlarm)
            }
        }
        
        saveAndSync()
    }
    
    func applyPendingChanges() {
        guard let pendingChanges = sharedDataManager.loadPendingChanges() else { return }
        
        for change in pendingChanges {
            switch change.type {
            case .add, .update:
                if let alarmData = change.alarmData {
                    if let existingAlarm = alarms.first(where: { $0.id == alarmData.id }) {
                        if alarmData.updatedAt > existingAlarm.updatedAt {
                            existingAlarm.time = alarmData.time
                            existingAlarm.repeatDays = alarmData.repeatDays
                            existingAlarm.ringtone = alarmData.ringtone
                            existingAlarm.label = alarmData.label
                            existingAlarm.isEnabled = alarmData.isEnabled
                            existingAlarm.isSmartModeEnabled = alarmData.isSmartModeEnabled
                            existingAlarm.snoozeInterval = alarmData.snoozeInterval
                            existingAlarm.snoozeGesture = alarmData.snoozeGesture
                            existingAlarm.updatedAt = alarmData.updatedAt
                        }
                    } else {
                        let newAlarm = alarmData.toAlarm()
                        modelContext.insert(newAlarm)
                    }
                }
            case .delete:
                if let alarmToDelete = alarms.first(where: { $0.id == change.id }) {
                    modelContext.delete(alarmToDelete)
                }
            }
        }
        
        sharedDataManager.clearPendingChanges()
        saveAndSync()
    }
    
    var enabledAlarms: [Alarm] {
        alarms.filter { $0.isEnabled }
    }
    
    var nextAlarm: Alarm? {
        enabledAlarms
            .compactMap { alarm -> (Alarm, Date)? in
                guard let fireDate = alarm.nextFireDate else { return nil }
                return (alarm, fireDate)
            }
            .sorted { $0.1 < $1.1 }
            .first?.0
    }
    
    private func saveAndSync() {
        do {
            try modelContext.save()
            fetchAlarms()
            syncWithWatch()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}
