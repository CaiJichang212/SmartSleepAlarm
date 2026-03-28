import Foundation
import WatchConnectivity
import Combine

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isSessionActivated = false
    @Published var isPhoneReachable = false
    @Published var isPhonePaired = false
    @Published var lastSyncTime: Date?
    @Published var connectionStatus: ConnectionStatusInfo?
    @Published var syncedAlarms: [AlarmSyncData] = []
    @Published var snoozeSettings: SnoozeSettings = SnoozeSettings()
    
    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    private let syncQueue = DispatchQueue(label: "com.smartsleep.watchconnectivity.watch.sync", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    
    var onAlarmsReceived: (([AlarmSyncData]) -> Void)?
    var onSnoozeSettingsReceived: ((SnoozeSettings) -> Void)?
    var onDataSyncRequested: (() -> Void)?
    
    private override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        guard let session = session else {
            print("WatchConnectivity is not supported on this device")
            return
        }
        
        session.delegate = self
        session.activate()
    }
    
    func activateSession() {
        guard let session = session else { return }
        
        if session.activationState != .activated {
            session.activate()
        }
    }
    
    func sendAlarmStateToPhone(_ stateInfo: AlarmStateInfo) {
        guard let session = session, isSessionActivated else {
            print("Cannot send alarm state: session not activated")
            return
        }
        
        guard let payloadData = try? JSONEncoder().encode(stateInfo) else {
            print("Failed to encode alarm state info")
            return
        }
        
        let message = WatchMessage(type: .alarmStateUpdate, payload: payloadData)
        
        if session.isReachable {
            sendMessage(message) { success in
                if success {
                    print("Alarm state sent to phone: \(stateInfo.state.rawValue)")
                }
            }
        } else {
            transferUserInfo(message)
        }
    }
    
    func sendAlarmTriggered(alarmId: UUID, isSmartWake: Bool = false, triggerReason: String = "scheduled") {
        let stateInfo = AlarmStateInfo(
            alarmId: alarmId,
            state: .triggered,
            triggerReason: triggerReason,
            isSmartWake: isSmartWake
        )
        sendAlarmStateToPhone(stateInfo)
    }
    
    func sendAlarmDismissed(alarmId: UUID) {
        let stateInfo = AlarmStateInfo(
            alarmId: alarmId,
            state: .dismissed
        )
        sendAlarmStateToPhone(stateInfo)
    }
    
    func sendAlarmSnoozed(alarmId: UUID, snoozeCount: Int, snoozeEndTime: Date) {
        let stateInfo = AlarmStateInfo(
            alarmId: alarmId,
            state: .snoozed,
            snoozeCount: snoozeCount,
            snoozeEndTime: snoozeEndTime
        )
        sendAlarmStateToPhone(stateInfo)
    }
    
    func sendSnoozeSettingsToPhone(_ settings: SnoozeSettings) {
        guard let session = session, isSessionActivated else {
            print("Cannot send snooze settings: session not activated")
            return
        }
        
        guard let payloadData = try? JSONEncoder().encode(settings) else {
            print("Failed to encode snooze settings")
            return
        }
        
        let message = WatchMessage(type: .snoozeSettingsSync, payload: payloadData)
        
        if session.isReachable {
            sendMessage(message) { _ in }
        } else {
            transferUserInfo(message)
        }
    }
    
    func requestDataSyncFromPhone() {
        guard let session = session, isSessionActivated else { return }
        
        let message = WatchMessage(type: .requestDataSync)
        
        if session.isReachable {
            sendMessage(message) { _ in }
        }
    }
    
    private func sendMessage(_ message: WatchMessage, completion: @escaping (Bool) -> Void) {
        guard let session = session, session.isReachable else {
            completion(false)
            return
        }
        
        guard let dictionary = message.toDictionary() else {
            completion(false)
            return
        }
        
        session.sendMessage(dictionary) { replyHandler in
            print("Message sent successfully: \(message.type.rawValue)")
            completion(true)
        } errorHandler: { error in
            print("Failed to send message: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    private func transferUserInfo(_ message: WatchMessage) {
        guard let session = session else { return }
        
        guard let dictionary = message.toDictionary() else {
            print("Failed to create user info dictionary")
            return
        }
        
        session.transferUserInfo(dictionary)
        print("Transferred user info for: \(message.type.rawValue)")
    }
    
    private func handleReceivedMessage(_ message: WatchMessage) {
        switch message.type {
        case .alarmDataSync:
            handleAlarmDataSync(message)
        case .snoozeSettingsSync:
            handleSnoozeSettingsSync(message)
        case .requestDataSync:
            handleDataSyncRequest()
        case .ping:
            handlePing()
        case .pong:
            handlePong()
        default:
            print("Received unhandled message type: \(message.type.rawValue)")
        }
    }
    
    private func handleAlarmDataSync(_ message: WatchMessage) {
        guard let payload = message.payload,
              let syncPayload = try? JSONDecoder().decode(AlarmsSyncPayload.self, from: payload) else {
            print("Failed to decode alarm data sync")
            return
        }
        
        DispatchQueue.main.async {
            self.syncedAlarms = syncPayload.alarms
            self.lastSyncTime = Date()
            self.onAlarmsReceived?(syncPayload.alarms)
        }
        
        print("Received \(syncPayload.alarms.count) alarms from phone, reason: \(syncPayload.syncReason.rawValue)")
    }
    
    private func handleSnoozeSettingsSync(_ message: WatchMessage) {
        guard let payload = message.payload,
              let settings = try? JSONDecoder().decode(SnoozeSettings.self, from: payload) else {
            print("Failed to decode snooze settings")
            return
        }
        
        DispatchQueue.main.async {
            self.snoozeSettings = settings
            self.onSnoozeSettingsReceived?(settings)
        }
        
        print("Received snooze settings from phone")
    }
    
    private func handleDataSyncRequest() {
        DispatchQueue.main.async {
            self.onDataSyncRequested?()
        }
        print("Data sync requested from phone")
    }
    
    private func handlePing() {
        let pongMessage = WatchMessage(type: .pong)
        sendMessage(pongMessage) { _ in }
        print("Received ping, sent pong")
    }
    
    private func handlePong() {
        DispatchQueue.main.async {
            self.lastSyncTime = Date()
        }
        print("Received pong from phone")
    }
    
    func getConnectionStatus() -> ConnectionStatusInfo {
        guard let session = session else {
            return ConnectionStatusInfo(isConnected: false, isReachable: false)
        }
        
        return ConnectionStatusInfo(
            isConnected: session.activationState == .activated,
            isReachable: session.isReachable,
            lastActiveDate: lastSyncTime,
            pairedDeviceName: session.isPaired ? "iPhone" : nil
        )
    }
    
    func getAlarm(by id: UUID) -> AlarmSyncData? {
        return syncedAlarms.first { $0.id == id }
    }
    
    func getEnabledAlarms() -> [AlarmSyncData] {
        return syncedAlarms.filter { $0.isEnabled }
    }
    
    func getNextAlarm() -> AlarmSyncData? {
        let enabledAlarms = getEnabledAlarms()
        let now = Date()
        let calendar = Calendar.current
        
        return enabledAlarms.compactMap { alarm -> (AlarmSyncData, Date)? in
            var alarmComponents = calendar.dateComponents([.hour, .minute], from: alarm.time)
            let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
            alarmComponents.year = todayComponents.year
            alarmComponents.month = todayComponents.month
            alarmComponents.day = todayComponents.day
            
            guard var nextDate = calendar.date(from: alarmComponents) else { return nil }
            
            if nextDate <= now {
                nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
            }
            
            return (alarm, nextDate)
        }
        .sorted { $0.1 < $1.1 }
        .first?.0
    }
    
    func clearSyncedAlarms() {
        syncedAlarms.removeAll()
        lastSyncTime = nil
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isSessionActivated = activationState == .activated
            self.isPhonePaired = session.isPaired
            self.isPhoneReachable = session.isReachable
            
            if let error = error {
                print("WCSession activation failed: \(error.localizedDescription)")
            } else {
                print("WCSession activated with state: \(activationState.rawValue)")
                
                if activationState == .activated {
                    self.connectionStatus = self.getConnectionStatus()
                    self.requestDataSyncFromPhone()
                }
            }
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
            print("Phone reachability changed: \(session.isReachable)")
            
            if session.isReachable {
                self.requestDataSyncFromPhone()
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let watchMessage = WatchMessage.from(dictionary: message) else {
            print("Failed to parse received message")
            return
        }
        
        Task { @MainActor in
            self.handleReceivedMessage(watchMessage)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let watchMessage = WatchMessage.from(dictionary: message) else {
            replyHandler([:])
            return
        }
        
        Task { @MainActor in
            self.handleReceivedMessage(watchMessage)
            
            let reply = WatchMessage(type: .pong)
            replyHandler(reply.toDictionary() ?? [:])
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let watchMessage = WatchMessage.from(dictionary: userInfo) else {
            print("Failed to parse received user info")
            return
        }
        
        Task { @MainActor in
            self.handleReceivedMessage(watchMessage)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let alarmsData = applicationContext["alarmsContext"] as? Data,
              let payload = try? JSONDecoder().decode(AlarmsSyncPayload.self, from: alarmsData) else {
            print("Failed to parse application context")
            return
        }
        
        Task { @MainActor in
            self.syncedAlarms = payload.alarms
            self.lastSyncTime = Date()
            self.onAlarmsReceived?(payload.alarms)
            print("Received application context with \(payload.alarms.count) alarms")
        }
    }
}
