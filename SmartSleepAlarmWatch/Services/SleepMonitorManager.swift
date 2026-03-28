import Foundation
import Combine

enum MonitorState {
    case idle
    case scheduled(alarmTime: Date)
    case monitoring(startTime: Date)
    case paused
    case error(String)
    
    var displayName: String {
        switch self {
        case .idle: return "空闲"
        case .scheduled(let alarmTime): return "已计划 (\(alarmTime.formatted(date: .omitted, time: .shortened)))"
        case .monitoring: return "监测中"
        case .paused: return "已暂停"
        case .error(let message): return "错误: \(message)"
        }
    }
    
    var isMonitoring: Bool {
        if case .monitoring = self { return true }
        return false
    }
}

enum SleepPhaseDetection {
    case light
    case deep
    case rem
    case awake
    case unknown
    
    var optimalForWaking: Bool {
        switch self {
        case .light, .rem: return true
        case .deep, .awake, .unknown: return false
        }
    }
    
    var displayName: String {
        switch self {
        case .light: return "浅睡"
        case .deep: return "深睡"
        case .rem: return "REM"
        case .awake: return "清醒"
        case .unknown: return "未知"
        }
    }
}

struct MonitoringSession {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    let targetAlarmTime: Date
    var detectedPhases: [SleepPhaseDetection]
    var sensorDataPoints: Int
    var degradedPeriods: Int
    
    var duration: TimeInterval {
        endTime.map { $0.timeIntervalSince(startTime) } ?? Date().timeIntervalSince(startTime)
    }
}

struct OptimalWakeWindow {
    let startTime: Date
    let endTime: Date
    let confidence: Double
    let detectedPhase: SleepPhaseDetection
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

class SleepMonitorManager: ObservableObject {
    static let shared = SleepMonitorManager()
    
    @Published var monitorState: MonitorState = .idle
    @Published var currentSession: MonitoringSession?
    @Published var currentPhase: SleepPhaseDetection = .unknown
    @Published var optimalWakeWindow: OptimalWakeWindow?
    @Published var batteryLevel: Float = 1.0
    @Published var estimatedBatteryDrain: Double = 0.0
    
    private let backgroundSessionManager = BackgroundSessionManager.shared
    private let sensorService = SensorService.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    private var phaseAnalysisTimer: Timer?
    
    private let preAlarmWindowMinutes: Int = 30
    private let batteryOptimalThreshold: Float = 0.2
    private let targetBatteryDrainPerHour: Double = 0.05
    
    private var recentHeartRates: [Double] = []
    private var recentMotionLevels: [Double] = []
    private let analysisWindowSize = 10
    
    var onOptimalWakeTimeDetected: ((OptimalWakeWindow) -> Void)?
    var onAlarmTriggered: (() -> Void)?
    var onBatteryWarning: ((Float) -> Void)?
    var onDegradedModeActivated: (([SensorType]) -> Void)?
    
    private override init() {
        super.init()
        setupBindings()
        setupSessionCallbacks()
    }
    
    private func setupBindings() {
        sensorService.$degradedMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isDegraded in
                if isDegraded {
                    let degradedTypes = self?.sensorService.getDegradedSensorTypes() ?? []
                    self?.handleDegradedMode(degradedTypes)
                }
            }
            .store(in: &cancellables)
        
        sensorService.$currentHeartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] heartRate in
                if let hr = heartRate {
                    self?.updateHeartRateBuffer(hr)
                }
            }
            .store(in: &cancellables)
        
        backgroundSessionManager.$sessionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleSessionStateChange(state)
            }
            .store(in: &cancellables)
    }
    
    private func setupSessionCallbacks() {
        backgroundSessionManager.onSessionStarted = { [weak self] in
            self?.startMonitoringInternal()
        }
        
        backgroundSessionManager.onSessionEnded = { [weak self] reason in
            self?.stopMonitoringInternal(reason: reason)
        }
        
        backgroundSessionManager.onSessionWillExpire = { [weak self] in
            self?.handleSessionExpiring()
        }
        
        sensorService.onSensorData = { [weak self] data in
            self?.processSensorData(data)
        }
        
        sensorService.onSensorDegraded = { [weak self] types in
            self?.handleDegradedMode(types)
        }
        
        sensorService.onSensorRecovered = { [weak self] type in
            self?.handleSensorRecovered(type)
        }
    }
    
    func scheduleMonitoring(for alarmTime: Date) {
        guard case .idle = monitorState || case .scheduled = monitorState else {
            print("Cannot schedule monitoring: current state is \(monitorState.displayName)")
            return
        }
        
        let calendar = Calendar.current
        let monitorStartTime = calendar.date(byAdding: .minute, value: -preAlarmWindowMinutes, to: alarmTime) ?? alarmTime
        
        currentSession = MonitoringSession(
            id: UUID(),
            startTime: monitorStartTime,
            endTime: nil,
            targetAlarmTime: alarmTime,
            detectedPhases: [],
            sensorDataPoints: 0,
            degradedPeriods: 0
        )
        
        monitorState = .scheduled(alarmTime: alarmTime)
        
        backgroundSessionManager.scheduleSessionBeforeAlarm(
            alarmTime: alarmTime,
            windowMinutes: preAlarmWindowMinutes
        )
        
        print("Monitoring scheduled for alarm at \(alarmTime), starting at \(monitorStartTime)")
    }
    
    func startMonitoringImmediately() {
        guard !monitorState.isMonitoring else {
            print("Already monitoring")
            return
        }
        
        backgroundSessionManager.startSession()
    }
    
    func stopMonitoring() {
        backgroundSessionManager.stopSession(reason: .userInitiated)
    }
    
    private func startMonitoringInternal() {
        sensorService.startMonitoring()
        
        startPhaseAnalysisTimer()
        startBatteryMonitoring()
        
        if currentSession == nil {
            currentSession = MonitoringSession(
                id: UUID(),
                startTime: Date(),
                endTime: nil,
                targetAlarmTime: Date().addingTimeInterval(TimeInterval(preAlarmWindowMinutes * 60)),
                detectedPhases: [],
                sensorDataPoints: 0,
                degradedPeriods: 0
            )
        }
        
        monitorState = .monitoring(startTime: Date())
        print("Monitoring started internally")
    }
    
    private func stopMonitoringInternal(reason: SessionEndReason) {
        sensorService.stopMonitoring()
        
        stopTimers()
        
        currentSession?.endTime = Date()
        
        switch reason {
        case .expired, .systemTerminated:
            monitorState = .idle
        case .userInitiated:
            monitorState = .idle
        case .error:
            monitorState = .error("Session ended with error")
        }
        
        print("Monitoring stopped with reason: \(reason)")
    }
    
    private func handleSessionStateChange(_ state: SessionState) {
        switch state {
        case .running:
            break
        case .ended:
            if case .monitoring = monitorState {
                monitorState = .idle
            }
        case .notStarted:
            break
        }
    }
    
    private func handleSessionExpiring() {
        print("Session is about to expire")
        
        if let window = optimalWakeWindow, window.optimalForWaking {
            onOptimalWakeTimeDetected?(window)
        }
    }
    
    private func processSensorData(_ data: SensorData) {
        currentSession?.sensorDataPoints += 1
        
        if let motion = data.accelerationMagnitude {
            updateMotionBuffer(motion)
        }
        
        analyzeCurrentPhase()
    }
    
    private func updateHeartRateBuffer(_ heartRate: Double) {
        recentHeartRates.append(heartRate)
        if recentHeartRates.count > analysisWindowSize {
            recentHeartRates.removeFirst()
        }
    }
    
    private func updateMotionBuffer(_ motion: Double) {
        recentMotionLevels.append(motion)
        if recentMotionLevels.count > analysisWindowSize {
            recentMotionLevels.removeFirst()
        }
    }
    
    private func startPhaseAnalysisTimer() {
        phaseAnalysisTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.analyzeCurrentPhase()
        }
        
        RunLoop.current.add(phaseAnalysisTimer!, forMode: .default)
    }
    
    private func startBatteryMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkBatteryLevel()
        }
    }
    
    private func stopTimers() {
        phaseAnalysisTimer?.invalidate()
        phaseAnalysisTimer = nil
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func analyzeCurrentPhase() {
        guard recentHeartRates.count >= 3 || recentMotionLevels.count >= 3 else {
            currentPhase = .unknown
            return
        }
        
        let avgHeartRate = recentHeartRates.isEmpty ? nil : recentHeartRates.reduce(0, +) / Double(recentHeartRates.count)
        let avgMotion = recentMotionLevels.isEmpty ? nil : recentMotionLevels.reduce(0, +) / Double(recentMotionLevels.count)
        let heartRateVariability = calculateHeartRateVariability()
        
        let detectedPhase = detectSleepPhase(
            heartRate: avgHeartRate,
            motion: avgMotion,
            hrv: heartRateVariability
        )
        
        currentPhase = detectedPhase
        currentSession?.detectedPhases.append(detectedPhase)
        
        checkForOptimalWakeWindow()
    }
    
    private func detectSleepPhase(heartRate: Double?, motion: Double?, hrv: Double?) -> SleepPhaseDetection {
        if let motion = motion, motion > 0.3 {
            return .awake
        }
        
        guard let hr = heartRate else {
            return .unknown
        }
        
        let baseHR = 60.0
        
        if hr < baseHR - 10 {
            if let m = motion, m < 0.05 {
                return .deep
            }
        }
        
        if let hrvValue = hrv, hrvValue > 50 {
            return .rem
        }
        
        if hr > baseHR + 5 {
            return .light
        }
        
        return .light
    }
    
    private func calculateHeartRateVariability() -> Double? {
        guard recentHeartRates.count >= 3 else { return nil }
        
        let mean = recentHeartRates.reduce(0, +) / Double(recentHeartRates.count)
        let variance = recentHeartRates.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(recentHeartRates.count)
        
        return sqrt(variance)
    }
    
    private func checkForOptimalWakeWindow() {
        guard let session = currentSession else { return }
        
        let now = Date()
        let timeToAlarm = session.targetAlarmTime.timeIntervalSince(now)
        
        guard timeToAlarm > 0 && timeToAlarm <= TimeInterval(preAlarmWindowMinutes * 60) else {
            return
        }
        
        if currentPhase.optimalForWaking {
            let windowDuration: TimeInterval = 5 * 60
            let window = OptimalWakeWindow(
                startTime: now,
                endTime: min(now.addingTimeInterval(windowDuration), session.targetAlarmTime),
                confidence: calculateWakeConfidence(),
                detectedPhase: currentPhase
            )
            
            optimalWakeWindow = window
            
            if window.confidence > 0.7 {
                onOptimalWakeTimeDetected?(window)
            }
        }
    }
    
    private func calculateWakeConfidence() -> Double {
        var confidence = 0.5
        
        if currentPhase.optimalForWaking {
            confidence += 0.2
        }
        
        if sensorService.getAvailableSensorCount() >= 3 {
            confidence += 0.1
        }
        
        if let session = currentSession, session.degradedPeriods == 0 {
            confidence += 0.1
        }
        
        if !sensorService.degradedMode {
            confidence += 0.1
        }
        
        return min(1.0, confidence)
    }
    
    private func handleDegradedMode(_ degradedTypes: [SensorType]) {
        currentSession?.degradedPeriods += 1
        
        onDegradedModeActivated?(degradedTypes)
        
        print("Degraded mode activated for: \(degradedTypes.map { $0.displayName })")
        
        applyDegradedStrategy(degradedTypes)
    }
    
    private func handleSensorRecovered(_ type: SensorType) {
        print("Sensor recovered: \(type.displayName)")
    }
    
    private func applyDegradedStrategy(_ degradedTypes: [SensorType]) {
        let hasHeartRateIssue = degradedTypes.contains(.heartRate)
        let hasMotionIssue = degradedTypes.contains(.accelerometer) || degradedTypes.contains(.gyroscope)
        
        if hasHeartRateIssue && hasMotionIssue {
            print("Critical: Both heart rate and motion sensors degraded")
            monitorState = .error("传感器数据严重缺失")
        } else if hasHeartRateIssue {
            print("Using motion-only sleep phase detection")
        } else if hasMotionIssue {
            print("Using heart-rate-only sleep phase detection")
        }
    }
    
    private func checkBatteryLevel() {
        let level = getBatteryLevel()
        batteryLevel = level
        
        if let startTime = currentSession?.startTime {
            let hours = Date().timeIntervalSince(startTime) / 3600
            let drain = 1.0 - Double(level)
            estimatedBatteryDrain = hours > 0 ? drain / hours : 0
        }
        
        if level < batteryOptimalThreshold {
            onBatteryWarning?(level)
            print("Battery warning: \(Int(level * 100))%")
            
            if estimatedBatteryDrain > targetBatteryDrainPerHour * 2 {
                optimizeBatteryUsage()
            }
        }
    }
    
    private func getBatteryLevel() -> Float {
        return 0.8
    }
    
    private func optimizeBatteryUsage() {
        print("Optimizing battery usage")
        
        if sensorService.degradedMode {
            let degraded = sensorService.getDegradedSensorTypes()
            if degraded.contains(.gyroscope) {
                print("Gyroscope already disabled")
            }
        }
    }
    
    func getMonitoringStatistics() -> (duration: TimeInterval, dataPoints: Int, phases: [SleepPhaseDetection: Int]) {
        guard let session = currentSession else {
            return (0, 0, [:])
        }
        
        let phaseCounts = Dictionary(grouping: session.detectedPhases, by: { $0 })
            .mapValues { $0.count }
        
        return (session.duration, session.sensorDataPoints, phaseCounts)
    }
    
    func cancelScheduledMonitoring() {
        guard case .scheduled = monitorState else { return }
        
        monitorState = .idle
        currentSession = nil
        
        print("Scheduled monitoring cancelled")
    }
}
