import Foundation
import Combine

class SmartAlarmCoordinator: ObservableObject {
    static let shared = SmartAlarmCoordinator()
    
    @Published var isActive: Bool = false
    @Published var currentAlarm: Alarm?
    @Published var statusMessage: String = ""
    @Published var detectionProgress: Double = 0.0
    
    private let awakeDetectionService = AwakeDetectionService.shared
    private let alarmController = AlarmController.shared
    private let sensorService = SensorService.shared
    private let sleepMonitorManager = SleepMonitorManager.shared
    private let backgroundSessionManager = BackgroundSessionManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    private var alarmTriggerTime: Date?
    
    private override init() {
        super.init()
        setupBindings()
        configureServices()
    }
    
    private func setupBindings() {
        awakeDetectionService.$detectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleDetectionStateChange(state)
            }
            .store(in: &cancellables)
        
        awakeDetectionService.$antiSleepStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleAntiSleepStatusUpdate(status)
            }
            .store(in: &cancellables)
        
        alarmController.$isRinging
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRinging in
                if isRinging {
                    self?.handleAlarmStarted()
                }
            }
            .store(in: &cancellables)
    }
    
    private func configureServices() {
        awakeDetectionService.alarmController = alarmController
        
        awakeDetectionService.onAwakeDetected = { [weak self] result in
            self?.handleAwakeDetected(result)
        }
        
        awakeDetectionService.onAlarmSilenced = { [weak self] time in
            self?.handleAlarmSilenced(time)
        }
        
        awakeDetectionService.onReAlarmTriggered = { [weak self] reason in
            self?.handleReAlarmTriggered(reason)
        }
        
        alarmController.onAlarmTriggered = { [weak self] alarm in
            self?.handleAlarmTriggered(alarm)
        }
    }
    
    func startSmartAlarm(for alarm: Alarm) {
        guard !isActive else {
            print("Smart alarm already active")
            return
        }
        
        currentAlarm = alarm
        isActive = true
        statusMessage = "智能闹铃已启动"
        
        awakeDetectionService.startMonitoring()
        sensorService.startMonitoring()
        
        if alarm.isSmartModeEnabled {
            sleepMonitorManager.scheduleMonitoring(for: alarm.time)
        }
        
        print("Smart alarm started for: \(alarm.formattedTime)")
    }
    
    func stopSmartAlarm() {
        guard isActive else { return }
        
        awakeDetectionService.stopMonitoring()
        sensorService.stopMonitoring()
        alarmController.silenceAlarm()
        
        isActive = false
        currentAlarm = nil
        statusMessage = "智能闹铃已停止"
        detectionProgress = 0.0
        
        print("Smart alarm stopped")
    }
    
    func triggerAlarmNow() {
        guard let alarm = currentAlarm else {
            alarmController.triggerAlarm()
            return
        }
        
        alarmController.triggerAlarm(for: alarm)
    }
    
    func silenceAlarmManually() {
        alarmController.silenceAlarm()
        awakeDetectionService.forceSilenceAlarm()
        
        statusMessage = "闹铃已手动关闭"
    }
    
    private func handleAlarmStarted() {
        alarmTriggerTime = Date()
        awakeDetectionService.handleAlarmTriggered()
        
        statusMessage = "闹铃响铃中，检测清醒状态..."
    }
    
    private func handleAlarmTriggered(_ alarm: Alarm?) {
        alarmTriggerTime = Date()
        statusMessage = "闹铃已触发"
    }
    
    private func handleDetectionStateChange(_ state: AwakeDetectionState) {
        switch state {
        case .idle:
            statusMessage = "等待中"
            detectionProgress = 0.0
            
        case .monitoring:
            statusMessage = "监测中"
            detectionProgress = 0.0
            
        case .alarmRinging:
            statusMessage = "闹铃响铃中"
            detectionProgress = 0.0
            
        case .confirmingAwake(_, let startTime):
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(1.0, elapsed / awakeDetectionService.currentConfig.confirmationWindowSeconds)
            detectionProgress = progress
            statusMessage = "确认清醒中 (\(Int(progress * 100))%)"
            
        case .alarmSilenced:
            statusMessage = "闹铃已静音"
            detectionProgress = 1.0
            
        case .antiSleepMonitoring:
            statusMessage = "防再睡监测中"
            
        case .reAlarmPending(let reason):
            statusMessage = "重响: \(reason)"
            detectionProgress = 0.0
        }
    }
    
    private func handleAntiSleepStatusUpdate(_ status: AntiSleepMonitorStatus?) {
        guard let status = status else {
            detectionProgress = 0.0
            return
        }
        
        detectionProgress = status.progress
        
        let remainingSeconds = Int(status.remainingTime)
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        
        if status.isUserAwake {
            statusMessage = "保持清醒 (\(minutes):\(String(format: "%02d", seconds)))"
        } else {
            statusMessage = "监测中... (\(minutes):\(String(format: "%02d", seconds)))"
        }
    }
    
    private func handleAwakeDetected(_ result: AwakeDetectionResult) {
        statusMessage = "检测到清醒，静音闹铃"
        
        if let triggerTime = alarmTriggerTime {
            let responseTime = Date().timeIntervalSince(triggerTime)
            print("Alarm silenced in \(String(format: "%.2f", responseTime)) seconds after trigger")
        }
    }
    
    private func handleAlarmSilenced(_ time: Date) {
        statusMessage = "闹铃已静音，开始防再睡监测"
    }
    
    private func handleReAlarmTriggered(_ reason: String) {
        statusMessage = "重响闹铃: \(reason)"
        
        print("Re-alarm triggered: \(reason)")
    }
    
    func updateDetectionMode(_ mode: AwakeDetectionMode) {
        awakeDetectionService.setDetectionMode(mode)
        statusMessage = "检测模式: \(mode.displayName)"
    }
    
    func getCurrentStatus() -> SmartAlarmStatus {
        return SmartAlarmStatus(
            isActive: isActive,
            isAlarmRinging: alarmController.isRinging,
            detectionState: awakeDetectionService.detectionState.displayName,
            currentHeartRate: awakeDetectionService.getCurrentHeartRate(),
            currentMotionLevel: awakeDetectionService.getCurrentMotionLevel(),
            baselineHeartRate: awakeDetectionService.baselineHeartRate,
            antiSleepProgress: awakeDetectionService.antiSleepStatus?.progress ?? 0
        )
    }
}

struct SmartAlarmStatus {
    let isActive: Bool
    let isAlarmRinging: Bool
    let detectionState: String
    let currentHeartRate: Double?
    let currentMotionLevel: Double?
    let baselineHeartRate: Double?
    let antiSleepProgress: Double
    
    var summary: String {
        var parts: [String] = []
        
        parts.append("状态: \(detectionState)")
        
        if let hr = currentHeartRate {
            parts.append("心率: \(Int(hr)) BPM")
        }
        
        if let baseline = baselineHeartRate {
            parts.append("基准: \(Int(baseline)) BPM")
        }
        
        if let motion = currentMotionLevel {
            parts.append("体动: \(String(format: "%.2f", motion))")
        }
        
        if antiSleepProgress > 0 {
            parts.append("防再睡: \(Int(antiSleepProgress * 100))%")
        }
        
        return parts.joined(separator: " | ")
    }
}
