import Foundation
import Combine

enum AlarmState: Equatable {
    case idle
    case scheduled(nextAlarmTime: Date)
    case triggered(alarmId: UUID, triggerTime: Date)
    case snoozed(alarmId: UUID, snoozeEndTime: Date, snoozeCount: Int)
    case dismissed
    
    var displayName: String {
        switch self {
        case .idle: return "空闲"
        case .scheduled(let time): return "已计划 (\(time.formatted(date: .omitted, time: .shortened)))"
        case .triggered: return "闹铃中"
        case .snoozed(_, let endTime, let count): return "贪睡中 (\(count)次, 至 \(endTime.formatted(date: .omitted, time: .shortened)))"
        case .dismissed: return "已关闭"
        }
    }
    
    var isAlarmActive: Bool {
        switch self {
        case .triggered, .snoozed: return true
        default: return false
        }
    }
}

enum AlarmTriggerReason {
    case scheduledTime
    case optimalWakeWindow
    case snoozeEnded
    case manual
}

struct SnoozeInfo {
    let startTime: Date
    let duration: TimeInterval
    let gesture: SnoozeGesture
    let count: Int
}

struct AlarmTriggerInfo {
    let alarmId: UUID
    let triggerTime: Date
    let reason: AlarmTriggerReason
    let isSmartWake: Bool
    let detectedPhase: SleepPhaseDetection?
}

class WatchAlarmManager: ObservableObject {
    static let shared = WatchAlarmManager()
    
    @Published var alarmState: AlarmState = .idle
    @Published var currentAlarm: Alarm?
    @Published var snoozeHistory: [SnoozeInfo] = []
    @Published var lastTriggerInfo: AlarmTriggerInfo?
    @Published var maxSnoozeCount: Int = 3
    
    private let alarmPlayer = AlarmPlayer.shared
    private let sleepMonitor = SleepMonitorManager.shared
    private let sensorService = SensorService.shared
    
    private var snoozeTimer: Timer?
    private var alarmCheckTimer: Timer?
    private var wakefulnessCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private let wakefulnessThreshold: Double = 0.7
    private let gestureDetectionWindow: TimeInterval = 30.0
    
    var onAlarmTriggered: ((AlarmTriggerInfo) -> Void)?
    var onAlarmDismissed: ((UUID) -> Void)?
    var onSnoozeStarted: ((SnoozeInfo) -> Void)?
    var onWakefulnessDetected: (() -> Void)?
    
    private override init() {
        super.init()
        setupBindings()
        setupCallbacks()
        startAlarmChecking()
    }
    
    private func setupBindings() {
        sleepMonitor.$optimalWakeWindow
            .receive(on: DispatchQueue.main)
            .sink { [weak self] window in
                self?.handleOptimalWakeWindow(window)
            }
            .store(in: &cancellables)
        
        sleepMonitor.$currentPhase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                self?.handleSleepPhaseChange(phase)
            }
            .store(in: &cancellables)
        
        alarmPlayer.$playbackState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handlePlaybackStateChange(state)
            }
            .store(in: &cancellables)
    }
    
    private func setupCallbacks() {
        sleepMonitor.onOptimalWakeTimeDetected = { [weak self] window in
            self?.triggerOptimalWakeAlarm(window: window)
        }
        
        sleepMonitor.onAlarmTriggered = { [weak self] in
            self?.triggerScheduledAlarm()
        }
    }
    
    private func startAlarmChecking() {
        alarmCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkForAlarms()
        }
        
        RunLoop.current.add(alarmCheckTimer!, forMode: .default)
    }
    
    func scheduleAlarm(_ alarm: Alarm) {
        currentAlarm = alarm
        
        if let nextFireDate = alarm.nextFireDate {
            alarmState = .scheduled(nextAlarmTime: nextFireDate)
            
            if alarm.isSmartModeEnabled {
                sleepMonitor.scheduleMonitoring(for: nextFireDate)
            }
            
            print("Alarm scheduled for \(nextFireDate)")
        }
    }
    
    func triggerAlarm(alarm: Alarm, reason: AlarmTriggerReason, isSmartWake: Bool = false, detectedPhase: SleepPhaseDetection? = nil) {
        currentAlarm = alarm
        let triggerInfo = AlarmTriggerInfo(
            alarmId: alarm.id,
            triggerTime: Date(),
            reason: reason,
            isSmartWake: isSmartWake,
            detectedPhase: detectedPhase
        )
        lastTriggerInfo = triggerInfo
        alarmState = .triggered(alarmId: alarm.id, triggerTime: Date())
        
        let playbackConfig = createPlaybackConfig(for: alarm, isSmartWake: isSmartWake)
        alarmPlayer.playAlarm(config: playbackConfig)
        
        startWakefulnessMonitoring()
        
        onAlarmTriggered?(triggerInfo)
        print("Alarm triggered: \(alarm.id), reason: \(reason), smartWake: \(isSmartWake)")
    }
    
    private func triggerScheduledAlarm() {
        guard let alarm = currentAlarm else { return }
        triggerAlarm(alarm: alarm, reason: .scheduledTime, isSmartWake: false)
    }
    
    private func triggerOptimalWakeAlarm(window: OptimalWakeWindow) {
        guard let alarm = currentAlarm, alarm.isSmartModeEnabled else { return }
        
        triggerAlarm(
            alarm: alarm,
            reason: .optimalWakeWindow,
            isSmartWake: true,
            detectedPhase: window.detectedPhase
        )
    }
    
    private func triggerSnoozeAlarm() {
        guard let alarm = currentAlarm else { return }
        triggerAlarm(alarm: alarm, reason: .snoozeEnded, isSmartWake: false)
    }
    
    private func createPlaybackConfig(for alarm: Alarm, isSmartWake: Bool) -> AlarmPlaybackConfig {
        if isSmartWake {
            return AlarmPlaybackConfig(
                soundId: alarm.ringtone,
                volume: 0.6,
                vibrationEnabled: true,
                fadeInEnabled: true,
                fadeInDuration: 20.0,
                repeatCount: 3,
                repeatInterval: 8.0
            )
        } else {
            return AlarmPlaybackConfig(
                soundId: alarm.ringtone,
                volume: 0.8,
                vibrationEnabled: true,
                fadeInEnabled: false,
                fadeInDuration: 0,
                repeatCount: 5,
                repeatInterval: 5.0
            )
        }
    }
    
    func dismissAlarm() {
        guard case .triggered(let alarmId, _) = alarmState else { return }
        
        alarmPlayer.stopAlarm()
        stopWakefulnessMonitoring()
        
        alarmState = .dismissed
        onAlarmDismissed?(alarmId)
        
        print("Alarm dismissed: \(alarmId)")
    }
    
    func snoozeAlarm(gesture: SnoozeGesture? = nil) {
        guard case .triggered(let alarmId, _) = alarmState,
              let alarm = currentAlarm else { return }
        
        let snoozeCount = snoozeHistory.count
        guard snoozeCount < maxSnoozeCount else {
            print("Max snooze count reached")
            dismissAlarm()
            return
        }
        
        alarmPlayer.snooze()
        
        provideSnoozeHapticFeedback()
        
        let snoozeDuration = TimeInterval(alarm.snoozeInterval * 60)
        let snoozeEndTime = Date().addingTimeInterval(snoozeDuration)
        
        let snoozeInfo = SnoozeInfo(
            startTime: Date(),
            duration: snoozeDuration,
            gesture: gesture ?? alarm.snoozeGesture,
            count: snoozeCount + 1
        )
        
        snoozeHistory.append(snoozeInfo)
        alarmState = .snoozed(alarmId: alarmId, snoozeEndTime: snoozeEndTime, snoozeCount: snoozeCount + 1)
        
        scheduleSnoozeEnd(endTime: snoozeEndTime)
        
        continueSleepMonitoringDuringSnooze()
        
        onSnoozeStarted?(snoozeInfo)
        print("Snooze started: count \(snoozeCount + 1), ends at \(snoozeEndTime)")
    }
    
    private func provideSnoozeHapticFeedback() {
        let device = WKInterfaceDevice.current()
        
        device.play(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            device.play(.click)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            device.play(.click)
        }
    }
    
    private func continueSleepMonitoringDuringSnooze() {
        if !sleepMonitor.monitorState.isMonitoring {
            sleepMonitor.startMonitoringImmediately()
        }
        
        print("Continuing sleep monitoring during snooze period")
    }
    
    private func scheduleSnoozeEnd(endTime: Date) {
        snoozeTimer?.invalidate()
        
        let timeUntilEnd = endTime.timeIntervalSince(Date())
        
        snoozeTimer = Timer.scheduledTimer(withTimeInterval: timeUntilEnd, repeats: false) { [weak self] _ in
            self?.handleSnoozeEnd()
        }
        
        RunLoop.current.add(snoozeTimer!, forMode: .default)
    }
    
    private func handleSnoozeEnd() {
        guard case .snoozed(let alarmId, _, let count) = alarmState else { return }
        
        print("Snooze ended, re-triggering alarm (count was \(count))")
        
        triggerSnoozeAlarm()
    }
    
    func handleGestureSnooze(_ gesture: SnoozeGesture) {
        guard alarmState.isAlarmActive else { return }
        
        if case .triggered = alarmState {
            snoozeAlarm(gesture: gesture)
        }
    }
    
    private func startWakefulnessMonitoring() {
        wakefulnessCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkWakefulness()
        }
        
        RunLoop.current.add(wakefulnessCheckTimer!, forMode: .default)
    }
    
    private func stopWakefulnessMonitoring() {
        wakefulnessCheckTimer?.invalidate()
        wakefulnessCheckTimer = nil
    }
    
    private func checkWakefulness() {
        guard alarmState.isAlarmActive else { return }
        
        let motionLevel = sensorService.getMotionActivityLevel(forLast: 1)
        let heartRate = sensorService.currentHeartRate
        
        var wakefulnessScore = 0.0
        
        if let motion = motionLevel, motion > 0.2 {
            wakefulnessScore += 0.4
        }
        
        if let hr = heartRate, hr > 70 {
            wakefulnessScore += 0.3
        }
        
        if sleepMonitor.currentPhase == .awake {
            wakefulnessScore += 0.3
        }
        
        if wakefulnessScore >= wakefulnessThreshold {
            handleWakefulnessDetected()
        }
    }
    
    private func handleWakefulnessDetected() {
        print("Wakefulness detected during alarm")
        onWakefulnessDetected?()
    }
    
    private func handleOptimalWakeWindow(_ window: OptimalWakeWindow?) {
        guard let window = window, window.confidence > 0.7 else { return }
        
        if case .scheduled = alarmState {
            triggerOptimalWakeAlarm(window: window)
        }
    }
    
    private func handleSleepPhaseChange(_ phase: SleepPhaseDetection) {
        guard alarmState.isAlarmActive else { return }
        
        if phase == .awake {
            handleWakefulnessDetected()
        }
    }
    
    private func handlePlaybackStateChange(_ state: AlarmPlaybackState) {
        if state == .idle && alarmState.isAlarmActive {
            if case .triggered = alarmState {
                print("Playback stopped while alarm was active")
            }
        }
    }
    
    private func checkForAlarms() {
        guard case .scheduled(let nextTime) = alarmState else { return }
        
        let now = Date()
        if now >= nextTime {
            triggerScheduledAlarm()
        }
    }
    
    func reset() {
        alarmPlayer.stopAlarm()
        stopWakefulnessMonitoring()
        snoozeTimer?.invalidate()
        snoozeTimer = nil
        
        alarmState = .idle
        currentAlarm = nil
        snoozeHistory.removeAll()
        lastTriggerInfo = nil
    }
    
    func getSnoozeRemainingTime() -> TimeInterval? {
        guard case .snoozed(_, let endTime, _) = alarmState else { return nil }
        return max(0, endTime.timeIntervalSince(Date()))
    }
    
    func canSnooze() -> Bool {
        guard alarmState.isAlarmActive else { return false }
        return snoozeHistory.count < maxSnoozeCount
    }
    
    func getRemainingSnoozeCount() -> Int {
        return max(0, maxSnoozeCount - snoozeHistory.count)
    }
}

extension WatchAlarmManager {
    func handleGestureDetected(_ gesture: SnoozeGesture) {
        guard alarmState.isAlarmActive else { return }
        
        if case .triggered = alarmState {
            snoozeAlarm(gesture: gesture)
        }
    }
    
    func handleSnapGesture() {
        handleGestureDetected(.snap)
    }
    
    func handleWristFlipGesture() {
        handleGestureDetected(.wristFlip)
    }
}

extension WatchAlarmManager {
    func triggerTestAlarm() {
        let testAlarm = Alarm(
            time: Date(),
            ringtone: "default",
            label: "测试闹铃",
            snoozeInterval: 1
        )
        
        triggerAlarm(alarm: testAlarm, reason: .manual)
    }
    
    func triggerTestSnooze() {
        snoozeAlarm(gesture: .snap)
    }
}
