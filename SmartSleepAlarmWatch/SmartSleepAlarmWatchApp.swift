import SwiftUI

@main
struct SmartSleepAlarmWatchApp: App {
    @StateObject private var monitorManager = SleepMonitorManager.shared
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @StateObject private var alarmManager = WatchAlarmManager.shared
    
    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(watchConnectivity)
                .environmentObject(alarmManager)
                .onAppear {
                    setupMonitoring()
                    setupWatchConnectivity()
                }
        }
    }
    
    private func setupMonitoring() {
        Task {
            let sensorService = SensorService.shared
            _ = await sensorService.requestPermissions()
            
            let availabilities = sensorService.checkAvailability()
            print("Sensor availabilities: \(availabilities)")
        }
    }
    
    private func setupWatchConnectivity() {
        watchConnectivity.onAlarmsReceived = { alarms in
            handleReceivedAlarms(alarms)
        }
        
        watchConnectivity.onSnoozeSettingsReceived = { settings in
            handleReceivedSnoozeSettings(settings)
        }
        
        alarmManager.onAlarmTriggered = { triggerInfo in
            handleAlarmTriggered(triggerInfo)
        }
        
        alarmManager.onAlarmDismissed = { alarmId in
            handleAlarmDismissed(alarmId)
        }
        
        alarmManager.onSnoozeStarted = { snoozeInfo in
            handleSnoozeStarted(snoozeInfo)
        }
    }
    
    private func handleReceivedAlarms(_ alarms: [AlarmSyncData]) {
        print("Received \(alarms.count) alarms from iPhone")
        
        if let nextAlarmData = alarms.filter({ $0.isEnabled }).first {
            let alarm = nextAlarmData.toAlarm()
            alarmManager.scheduleAlarm(alarm)
        }
    }
    
    private func handleReceivedSnoozeSettings(_ settings: SnoozeSettings) {
        alarmManager.maxSnoozeCount = settings.maxSnoozeCount
        print("Updated snooze settings: maxCount=\(settings.maxSnoozeCount)")
    }
    
    private func handleAlarmTriggered(_ triggerInfo: AlarmTriggerInfo) {
        watchConnectivity.sendAlarmTriggered(
            alarmId: triggerInfo.alarmId,
            isSmartWake: triggerInfo.isSmartWake,
            triggerReason: triggerInfo.reason.rawValue
        )
    }
    
    private func handleAlarmDismissed(_ alarmId: UUID) {
        watchConnectivity.sendAlarmDismissed(alarmId: alarmId)
    }
    
    private func handleSnoozeStarted(_ snoozeInfo: SnoozeInfo) {
        guard let alarm = alarmManager.currentAlarm else { return }
        watchConnectivity.sendAlarmSnoozed(
            alarmId: alarm.id,
            snoozeCount: snoozeInfo.count,
            snoozeEndTime: snoozeInfo.startTime.addingTimeInterval(snoozeInfo.duration)
        )
    }
}
