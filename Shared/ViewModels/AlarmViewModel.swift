import Foundation

class AlarmViewModel: ObservableObject {
    @Published var alarms: [AlarmSettings] = []
    @Published var selectedAlarm: AlarmSettings?
    
    private let alarmsKey = "savedAlarms"
    
    init() {
        loadAlarms()
    }
    
    func addAlarm(_ alarm: AlarmSettings) {
        alarms.append(alarm)
        saveAlarms()
    }
    
    func updateAlarm(_ alarm: AlarmSettings) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
            saveAlarms()
        }
    }
    
    func deleteAlarm(_ alarm: AlarmSettings) {
        alarms.removeAll { $0.id == alarm.id }
        saveAlarms()
    }
    
    func toggleAlarm(_ alarm: AlarmSettings) {
        var updatedAlarm = alarm
        updatedAlarm.isEnabled.toggle()
        updateAlarm(updatedAlarm)
    }
    
    private func saveAlarms() {
        if let data = try? JSONEncoder().encode(alarms) {
            UserDefaults(suiteName: AppConstants.appGroupIdentifier)?.set(data, forKey: alarmsKey)
        }
    }
    
    private func loadAlarms() {
        guard let data = UserDefaults(suiteName: AppConstants.appGroupIdentifier)?.data(forKey: alarmsKey),
              let savedAlarms = try? JSONDecoder().decode([AlarmSettings].self, from: data) else {
            return
        }
        alarms = savedAlarms
    }
}
