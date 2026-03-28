import WatchKit
import Foundation

enum SessionState {
    case notStarted
    case running
    case ended
    
    var displayName: String {
        switch self {
        case .notStarted: return "未开始"
        case .running: return "运行中"
        case .ended: return "已结束"
        }
    }
}

enum SessionEndReason {
    case expired
    case userInitiated
    case systemTerminated
    case error
}

class BackgroundSessionManager: NSObject, ObservableObject {
    static let shared = BackgroundSessionManager()
    
    @Published var sessionState: SessionState = .notStarted
    @Published var sessionStartDate: Date?
    @Published var lastHeartbeatDate: Date?
    @Published var sessionDuration: TimeInterval = 0
    
    private var extendedSession: WKExtendedRuntimeSession?
    private var heartbeatTimer: Timer?
    private var durationUpdateTimer: Timer?
    
    private let heartbeatInterval: TimeInterval = 60
    private let maxSessionDuration: TimeInterval = 60 * 60
    
    var onSessionStarted: (() -> Void)?
    var onSessionEnded: ((SessionEndReason) -> Void)?
    var onSessionWillExpire: (() -> Void)?
    
    private override init() {
        super.init()
    }
    
    var isSessionActive: Bool {
        return sessionState == .running && extendedSession != nil
    }
    
    var remainingTime: TimeInterval? {
        guard let startDate = sessionStartDate else { return nil }
        let elapsed = Date().timeIntervalSince(startDate)
        return max(0, maxSessionDuration - elapsed)
    }
    
    func startSession() {
        guard sessionState != .running else {
            print("Session already running")
            return
        }
        
        stopSession(reason: .userInitiated)
        
        extendedSession = WKExtendedRuntimeSession()
        extendedSession?.delegate = self
        extendedSession?.start()
        
        print("Background session start requested")
    }
    
    func stopSession(reason: SessionEndReason = .userInitiated) {
        guard sessionState == .running else { return }
        
        invalidateTimers()
        
        extendedSession?.invalidate()
        extendedSession = nil
        
        sessionState = .ended
        sessionDuration = Date().timeIntervalSince(sessionStartDate ?? Date())
        sessionStartDate = nil
        
        onSessionEnded?(reason)
        print("Background session stopped with reason: \(reason)")
    }
    
    private func startHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            self?.performHeartbeat()
        }
        
        RunLoop.current.add(heartbeatTimer!, forMode: .default)
    }
    
    private func startDurationTimer() {
        durationUpdateTimer?.invalidate()
        
        durationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDuration()
        }
        
        RunLoop.current.add(durationUpdateTimer!, forMode: .default)
    }
    
    private func invalidateTimers() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        durationUpdateTimer?.invalidate()
        durationUpdateTimer = nil
    }
    
    private func performHeartbeat() {
        lastHeartbeatDate = Date()
        
        if let remaining = remainingTime, remaining < 300 {
            onSessionWillExpire?()
        }
        
        print("Heartbeat at \(lastHeartbeatDate ?? Date())")
    }
    
    private func updateDuration() {
        if let startDate = sessionStartDate {
            sessionDuration = Date().timeIntervalSince(startDate)
        }
    }
    
    func scheduleSessionBeforeAlarm(alarmTime: Date, windowMinutes: Int = 30) {
        let calendar = Calendar.current
        let monitorStartTime = calendar.date(byAdding: .minute, value: -windowMinutes, to: alarmTime) ?? alarmTime
        
        let now = Date()
        guard monitorStartTime > now else {
            print("Monitor start time is in the past, starting immediately")
            startSession()
            return
        }
        
        let timeUntilStart = monitorStartTime.timeIntervalSince(now)
        print("Scheduling session to start in \(timeUntilStart) seconds")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + timeUntilStart) { [weak self] in
            self?.startSession()
        }
    }
    
    func extendSessionIfNeeded() {
        guard sessionState == .running else { return }
        
        if let remaining = remainingTime, remaining < 600 {
            print("Session expiring soon, requesting extension")
        }
    }
}

extension BackgroundSessionManager: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        DispatchQueue.main.async { [weak self] in
            self?.sessionState = .running
            self?.sessionStartDate = Date()
            self?.lastHeartbeatDate = Date()
            
            self?.startHeartbeatTimer()
            self?.startDurationTimer()
            
            self?.onSessionStarted?()
            print("Extended runtime session started successfully")
        }
    }
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        DispatchQueue.main.async { [weak self] in
            print("Extended runtime session will expire soon")
            self?.onSessionWillExpire?()
        }
    }
    
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.invalidateTimers()
            
            let endReason: SessionEndReason
            switch reason {
            case .expired:
                endReason = .expired
            case .sessionInProgress:
                endReason = .error
            @unknown default:
                endReason = .systemTerminated
            }
            
            self?.sessionState = .ended
            self?.sessionDuration = Date().timeIntervalSince(self?.sessionStartDate ?? Date())
            self?.sessionStartDate = nil
            self?.extendedSession = nil
            
            self?.onSessionEnded?(endReason)
            
            if let error = error {
                print("Extended runtime session invalidated with error: \(error.localizedDescription)")
            }
            print("Extended runtime session invalidated with reason: \(reason.rawValue)")
        }
    }
}
