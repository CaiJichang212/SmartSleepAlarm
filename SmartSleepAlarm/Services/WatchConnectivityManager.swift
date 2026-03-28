import Foundation
import WatchConnectivity

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isSessionActivated = false
    @Published var isWatchReachable = false
    @Published var isWatchPaired = false
    @Published var lastSyncTime: Date?
    @Published var connectionStatus: ConnectionStatusInfo?
    
    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    private let syncQueue = DispatchQueue(label: "com.smartsleep.watchconnectivity.sync", qos: .userInitiated)
    
    var onAlarmStateReceived: ((AlarmStateInfo) -> Void)?
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
    
    func deactivateSession() {
        guard let session = session else { return }
        session.delegate = nil
    }
    
    func sendAlarmsToWatch(_ alarms: [Alarm], reason: SyncReason = .manual) {
        guard let session = session, isSessionActivated else {
            print("Cannot send alarms: session not activated")
            return
        }
        
        let syncData = alarms.map { AlarmSyncData(from: $0) }
        let payload = AlarmsSyncPayload(alarms: syncData, syncReason: reason)
        
        guard let payloadData = try? JSONEncoder().encode(payload) else {
            print("Failed to encode alarms payload")
            return
        }
        
        let message = WatchMessage(type: .alarmDataSync, payload: payloadData)
        
        if session.isReachable {
            sendMessage(message) { success in
                if success {
                    DispatchQueue.main.async {
                        self.lastSyncTime = Date()
                    }
                    print("Alarms sent via immediate message")
                } else {
                    self.transferUserInfo(message)
                }
            }
        } else {
            transferUserInfo(message)
        }
    }
    
    func sendSnoozeSettingsToWatch(_ settings: SnoozeSettings) {
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
    
    func requestAlarmStateFromWatch() {
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
    
    private func transferCurrentComplicationUserInfo(_ message: WatchMessage) {
        guard let session = session, session.isComplicationEnabled else {
            transferUserInfo(message)
            return
        }
        
        guard let dictionary = message.toDictionary() else { return }
        
        session.transferCurrentComplicationUserInfo(dictionary)
        print("Transferred complication user info for: \(message.type.rawValue)")
    }
    
    private func handleReceivedMessage(_ message: WatchMessage) {
        switch message.type {
        case .alarmStateUpdate:
            handleAlarmStateUpdate(message)
        case .alarmTriggered:
            handleAlarmTriggered(message)
        case .alarmDismissed:
            handleAlarmDismissed(message)
        case .alarmSnoozed:
            handleAlarmSnoozed(message)
        case .snoozeSettingsSync:
            handleSnoozeSettingsSync(message)
        case .requestDataSync:
            handleDataSyncRequest()
        case .pong:
            handlePong()
        default:
            print("Received unhandled message type: \(message.type.rawValue)")
        }
    }
    
    private func handleAlarmStateUpdate(_ message: WatchMessage) {
        guard let payload = message.payload,
              let stateInfo = try? JSONDecoder().decode(AlarmStateInfo.self, from: payload) else {
            print("Failed to decode alarm state info")
            return
        }
        
        DispatchQueue.main.async {
            self.onAlarmStateReceived?(stateInfo)
        }
        
        print("Received alarm state update: \(stateInfo.state.rawValue) for alarm: \(stateInfo.alarmId)")
    }
    
    private func handleAlarmTriggered(_ message: WatchMessage) {
        guard let payload = message.payload,
              let stateInfo = try? JSONDecoder().decode(AlarmStateInfo.self, from: payload) else {
            print("Failed to decode alarm triggered info")
            return
        }
        
        DispatchQueue.main.async {
            self.onAlarmStateReceived?(stateInfo)
        }
        
        print("Alarm triggered on watch: \(stateInfo.alarmId)")
    }
    
    private func handleAlarmDismissed(_ message: WatchMessage) {
        guard let payload = message.payload,
              let stateInfo = try? JSONDecoder().decode(AlarmStateInfo.self, from: payload) else {
            print("Failed to decode alarm dismissed info")
            return
        }
        
        DispatchQueue.main.async {
            self.onAlarmStateReceived?(stateInfo)
        }
        
        print("Alarm dismissed on watch: \(stateInfo.alarmId)")
    }
    
    private func handleAlarmSnoozed(_ message: WatchMessage) {
        guard let payload = message.payload,
              let stateInfo = try? JSONDecoder().decode(AlarmStateInfo.self, from: payload) else {
            print("Failed to decode alarm snoozed info")
            return
        }
        
        DispatchQueue.main.async {
            self.onAlarmStateReceived?(stateInfo)
        }
        
        print("Alarm snoozed on watch: \(stateInfo.alarmId)")
    }
    
    private func handleSnoozeSettingsSync(_ message: WatchMessage) {
        guard let payload = message.payload,
              let settings = try? JSONDecoder().decode(SnoozeSettings.self, from: payload) else {
            print("Failed to decode snooze settings")
            return
        }
        
        DispatchQueue.main.async {
            self.onSnoozeSettingsReceived?(settings)
        }
        
        print("Received snooze settings from watch")
    }
    
    private func handleDataSyncRequest() {
        DispatchQueue.main.async {
            self.onDataSyncRequested?()
        }
        print("Data sync requested from watch")
    }
    
    private func handlePong() {
        DispatchQueue.main.async {
            self.lastSyncTime = Date()
        }
        print("Received pong from watch")
    }
    
    func sendPing() {
        let message = WatchMessage(type: .ping)
        sendMessage(message) { _ in }
    }
    
    func getConnectionStatus() -> ConnectionStatusInfo {
        guard let session = session else {
            return ConnectionStatusInfo(isConnected: false, isReachable: false)
        }
        
        return ConnectionStatusInfo(
            isConnected: session.activationState == .activated,
            isReachable: session.isReachable,
            lastActiveDate: lastSyncTime,
            pairedDeviceName: session.isPaired ? "Apple Watch" : nil
        )
    }
    
    func updateApplicationContext(alarms: [Alarm]) {
        guard let session = session else { return }
        
        let syncData = alarms.map { AlarmSyncData(from: $0) }
        let payload = AlarmsSyncPayload(alarms: syncData, syncReason: .automatic)
        
        guard let payloadData = try? JSONEncoder().encode(payload),
              let context = try? JSONDecoder().decode([String: Data].self, from: payloadData) else {
            return
        }
        
        do {
            try session.updateApplicationContext(["alarmsContext": payloadData])
            print("Updated application context")
        } catch {
            print("Failed to update application context: \(error)")
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isSessionActivated = activationState == .activated
            self.isWatchPaired = session.isPaired
            self.isWatchReachable = session.isReachable
            
            if let error = error {
                print("WCSession activation failed: \(error.localizedDescription)")
            } else {
                print("WCSession activated with state: \(activationState.rawValue)")
                
                if activationState == .activated {
                    self.connectionStatus = self.getConnectionStatus()
                }
            }
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self.isSessionActivated = false
            print("WCSession became inactive")
        }
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            self.isSessionActivated = false
            print("WCSession deactivated")
            
            self.session?.activate()
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
            print("Watch reachability changed: \(session.isReachable)")
            
            if session.isReachable {
                self.sendPing()
            }
        }
    }
    
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchPaired = session.isPaired
            self.isWatchReachable = session.isReachable
            print("Watch state changed - paired: \(session.isPaired), reachable: \(session.isReachable)")
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
            self.lastSyncTime = Date()
            print("Received application context with \(payload.alarms.count) alarms")
        }
    }
}

extension AlarmSyncData {
    init(from alarm: Alarm) {
        self.id = alarm.id
        self.time = alarm.time
        self.repeatDays = alarm.repeatDays
        self.ringtone = alarm.ringtone
        self.label = alarm.label
        self.isEnabled = alarm.isEnabled
        self.isSmartModeEnabled = alarm.isSmartModeEnabled
        self.snoozeInterval = alarm.snoozeInterval
        self.snoozeGesture = alarm.snoozeGesture
        self.createdAt = alarm.createdAt
        self.updatedAt = alarm.updatedAt
    }
}
