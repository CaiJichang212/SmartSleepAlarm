import Foundation
import Combine

protocol AlarmControllable {
    func silenceAlarm()
    func triggerAlarm()
    func isAlarmRinging() -> Bool
}

class AwakeDetectionService: ObservableObject {
    static let shared = AwakeDetectionService()
    
    @Published var detectionState: AwakeDetectionState = .idle
    @Published var currentConfig: AwakeDetectionConfig = .default
    @Published var detectionMode: AwakeDetectionMode = .default
    @Published var lastDetectionResult: AwakeDetectionResult?
    @Published var antiSleepStatus: AntiSleepMonitorStatus?
    @Published var baselineHeartRate: Double?
    
    private let sensorService = SensorService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private var confirmationTimer: Timer?
    private var antiSleepTimer: Timer?
    private var reAlarmTimer: Timer?
    
    private var confirmationSignals: [AwakeSignal] = []
    private var confirmationStartTime: Date?
    
    private var recentHeartRates: [(timestamp: Date, value: Double)] = []
    private var recentMotionData: [(timestamp: Date, magnitude: Double)] = []
    
    private let maxHeartRateHistory = 100
    private let maxMotionHistory = 200
    
    var alarmController: AlarmControllable?
    
    var onAwakeDetected: ((AwakeDetectionResult) -> Void)?
    var onAlarmSilenced: ((Date) -> Void)?
    var onReAlarmTriggered: ((String) -> Void)?
    var onAntiSleepStatusUpdate: ((AntiSleepMonitorStatus) -> Void)?
    var onDetectionStateChanged: ((AwakeDetectionState) -> Void)?
    
    private override init() {
        super.init()
        setupBindings()
        currentConfig = detectionMode.config
    }
    
    private func setupBindings() {
        sensorService.onSensorData = { [weak self] data in
            self?.processSensorData(data)
        }
        
        sensorService.$currentHeartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] heartRate in
                if let hr = heartRate {
                    self?.updateHeartRateHistory(hr)
                }
            }
            .store(in: &cancellables)
    }
    
    func setDetectionMode(_ mode: AwakeDetectionMode) {
        detectionMode = mode
        currentConfig = mode.config
    }
    
    func setCustomConfig(_ config: AwakeDetectionConfig) {
        currentConfig = config
    }
    
    func startMonitoring() {
        guard case .idle = detectionState else {
            print("Cannot start monitoring: current state is \(detectionState.displayName)")
            return
        }
        
        detectionState = .monitoring
        clearHistory()
        
        print("Awake detection monitoring started with mode: \(detectionMode.displayName)")
    }
    
    func stopMonitoring() {
        invalidateAllTimers()
        detectionState = .idle
        clearHistory()
        
        print("Awake detection monitoring stopped")
    }
    
    func handleAlarmTriggered() {
        guard case .monitoring = detectionState else { return }
        
        let now = Date()
        detectionState = .alarmRinging(startTime: now)
        
        startConfirmationWindow()
        
        print("Alarm triggered, starting awake confirmation window")
    }
    
    private func processSensorData(_ data: SensorData) {
        switch detectionState {
        case .monitoring:
            updateBaselineHeartRate()
            
        case .alarmRinging, .confirmingAwake:
            analyzeForAwakeSignals(data)
            
        case .antiSleepMonitoring:
            analyzeForReSleep(data)
            
        default:
            break
        }
        
        if let motion = data.accelerationMagnitude {
            updateMotionHistory(motion)
        }
    }
    
    private func updateHeartRateHistory(_ heartRate: Double) {
        let now = Date()
        recentHeartRates.append((timestamp: now, value: heartRate))
        
        if recentHeartRates.count > maxHeartRateHistory {
            recentHeartRates.removeFirst()
        }
        
        updateBaselineHeartRate()
    }
    
    private func updateMotionHistory(_ magnitude: Double) {
        let now = Date()
        recentMotionData.append((timestamp: now, magnitude: magnitude))
        
        if recentMotionData.count > maxMotionHistory {
            recentMotionData.removeFirst()
        }
    }
    
    private func updateBaselineHeartRate() {
        let cutoffTime = Date().addingTimeInterval(-TimeInterval(currentConfig.baselineHeartRateWindowMinutes * 60))
        let recentRates = recentHeartRates.filter { $0.timestamp >= cutoffTime }
        
        guard recentRates.count >= currentConfig.minHeartRateSamples else { return }
        
        let values = recentRates.map { $0.value }
        let mean = values.reduce(0, +) / Double(values.count)
        
        baselineHeartRate = mean
    }
    
    private func startConfirmationWindow() {
        confirmationSignals.removeAll()
        confirmationStartTime = Date()
        
        detectionState = .confirmingAwake(signals: [], startTime: Date())
        
        confirmationTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
            self?.checkConfirmationWindow()
        }
        
        if let timer = confirmationTimer {
            RunLoop.current.add(timer, forMode: .default)
        }
    }
    
    private func analyzeForAwakeSignals(_ data: SensorData) {
        var signals: [AwakeSignal] = []
        
        if let heartRateSignal = detectHeartRateSignal(data) {
            signals.append(heartRateSignal)
        }
        
        if let motionSignal = detectMotionSignal(data) {
            signals.append(motionSignal)
        }
        
        if let combinedSignal = detectCombinedSignal(signals: signals) {
            signals.append(combinedSignal)
        }
        
        confirmationSignals.append(contentsOf: signals)
        
        if let startTime = confirmationStartTime {
            detectionState = .confirmingAwake(signals: confirmationSignals, startTime: startTime)
        }
    }
    
    private func detectHeartRateSignal(_ data: SensorData) -> AwakeSignal? {
        guard let heartRate = data.heartRate,
              let baseline = baselineHeartRate,
              baseline > 0 else {
            return nil
        }
        
        let increaseRatio = (heartRate - baseline) / baseline
        let threshold = currentConfig.heartRateThresholdPercentage
        
        let confidence: Double
        if increaseRatio >= threshold {
            confidence = min(1.0, increaseRatio / threshold)
        } else {
            confidence = 0.0
        }
        
        return AwakeSignal(
            timestamp: data.timestamp,
            type: .heartRateIncrease,
            confidence: confidence,
            rawValue: heartRate,
            threshold: baseline * (1 + threshold)
        )
    }
    
    private func detectMotionSignal(_ data: SensorData) -> AwakeSignal? {
        guard let magnitude = data.accelerationMagnitude else {
            return nil
        }
        
        let windowStart = Date().addingTimeInterval(-currentConfig.motionAnalysisWindowSeconds)
        let recentMotion = recentMotionData.filter { $0.timestamp >= windowStart }
        
        guard recentMotion.count >= currentConfig.minMotionSamples else {
            return nil
        }
        
        let magnitudes = recentMotion.map { $0.magnitude }
        let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let variance = magnitudes.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(magnitudes.count)
        let stdDev = sqrt(variance)
        
        let threshold = currentConfig.motionThresholdStdDev
        let confidence: Double
        
        if stdDev >= threshold {
            confidence = min(1.0, stdDev / threshold)
        } else {
            confidence = stdDev / threshold
        }
        
        return AwakeSignal(
            timestamp: data.timestamp,
            type: .motionActivity,
            confidence: confidence,
            rawValue: stdDev,
            threshold: threshold
        )
    }
    
    private func detectCombinedSignal(signals: [AwakeSignal]) -> AwakeSignal? {
        let significantSignals = signals.filter { $0.isSignificant }
        guard significantSignals.count >= 2 else { return nil }
        
        let avgConfidence = significantSignals.map { $0.confidence }.reduce(0, +) / Double(significantSignals.count)
        
        return AwakeSignal(
            timestamp: Date(),
            type: .combined,
            confidence: avgConfidence,
            rawValue: Double(significantSignals.count),
            threshold: 2.0
        )
    }
    
    private func checkConfirmationWindow() {
        guard case .confirmingAwake(let signals, let startTime) = detectionState else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        let significantSignals = signals.filter { $0.isSignificant }
        let hasHeartRateSignal = significantSignals.contains { $0.type == .heartRateIncrease }
        let hasMotionSignal = significantSignals.contains { $0.type == .motionActivity }
        let hasCombinedSignal = significantSignals.contains { $0.type == .combined }
        
        let isAwake = (hasHeartRateSignal && hasMotionSignal) || hasCombinedSignal
        
        if isAwake && elapsed >= currentConfig.confirmationWindowSeconds {
            handleAwakeConfirmed(signals: signals)
        } else if elapsed >= currentConfig.alarmSilenceMaxDelaySeconds {
            if significantSignals.count >= 1 {
                handleAwakeConfirmed(signals: signals)
            }
        }
    }
    
    private func handleAwakeConfirmed(signals: [AwakeSignal]) {
        invalidateAllTimers()
        
        let result = AwakeDetectionResult(
            timestamp: Date(),
            isAwake: true,
            confidence: calculateConfidence(from: signals),
            signals: signals,
            heartRateValue: signals.first { $0.type == .heartRateIncrease }?.rawValue,
            motionValue: signals.first { $0.type == .motionActivity }?.rawValue,
            baselineHeartRate: baselineHeartRate
        )
        
        lastDetectionResult = result
        
        silenceAlarm()
        
        let now = Date()
        detectionState = .alarmSilenced(silenceTime: now)
        
        onAwakeDetected?(result)
        onAlarmSilenced?(now)
        
        print("Awake confirmed: \(result.summary)")
        
        startAntiSleepMonitoring()
    }
    
    private func calculateConfidence(from signals: [AwakeSignal]) -> Double {
        guard !signals.isEmpty else { return 0.0 }
        
        let significantSignals = signals.filter { $0.isSignificant }
        let signalScore = Double(significantSignals.count) / Double(signals.count)
        
        let avgConfidence = signals.map { $0.confidence }.reduce(0, +) / Double(signals.count)
        
        let typeBonus = Double(Set(significantSignals.map { $0.type }).count) * 0.15
        
        return min(1.0, signalScore * 0.4 + avgConfidence * 0.4 + typeBonus + 0.2)
    }
    
    private func silenceAlarm() {
        alarmController?.silenceAlarm()
        
        print("Alarm silenced")
    }
    
    private func startAntiSleepMonitoring() {
        let now = Date()
        antiSleepStatus = AntiSleepMonitorStatus(
            startTime: now,
            awakeSignalsCount: 0,
            sleepSignalsCount: 0,
            lastCheckTime: nil
        )
        
        detectionState = .antiSleepMonitoring(startTime: now)
        
        antiSleepTimer = Timer.scheduledTimer(
            withTimeInterval: 5.0,
            repeats: true
        ) { [weak self] _ in
            self?.performAntiSleepCheck()
        }
        
        if let timer = antiSleepTimer {
            RunLoop.current.add(timer, forMode: .default)
        }
        
        print("Anti-sleep monitoring started for \(currentConfig.antiSleepMonitorDurationSeconds) seconds")
    }
    
    private func performAntiSleepCheck() {
        guard case .antiSleepMonitoring = detectionState,
              var status = antiSleepStatus else { return }
        
        let elapsed = Date().timeIntervalSince(status.startTime)
        
        if elapsed >= currentConfig.antiSleepMonitorDurationSeconds {
            completeAntiSleepMonitoring()
            return
        }
        
        let result = analyzeCurrentAwakeState()
        
        if result.isAwake {
            status.awakeSignalsCount += 1
        } else {
            status.sleepSignalsCount += 1
        }
        
        status.lastCheckTime = Date()
        antiSleepStatus = status
        
        onAntiSleepStatusUpdate?(status)
        
        let sleepRatio = Double(status.sleepSignalsCount) / Double(status.awakeSignalsCount + status.sleepSignalsCount)
        
        if sleepRatio >= currentConfig.reAlarmThreshold && status.sleepSignalsCount >= 3 {
            triggerReAlarm(reason: "检测到再次入睡")
        }
        
        print("Anti-sleep check: awake=\(result.isAwake), sleepRatio=\(sleepRatio)")
    }
    
    private func analyzeCurrentAwakeState() -> AwakeDetectionResult {
        var signals: [AwakeSignal] = []
        
        if let hr = sensorService.currentHeartRate,
           let baseline = baselineHeartRate,
           baseline > 0 {
            let increaseRatio = (hr - baseline) / baseline
            let threshold = currentConfig.heartRateThresholdPercentage
            let confidence = increaseRatio >= threshold ? min(1.0, increaseRatio / threshold) : 0.0
            
            signals.append(AwakeSignal(
                timestamp: Date(),
                type: .heartRateIncrease,
                confidence: confidence,
                rawValue: hr,
                threshold: baseline * (1 + threshold)
            ))
        }
        
        let windowStart = Date().addingTimeInterval(-currentConfig.motionAnalysisWindowSeconds)
        let recentMotion = recentMotionData.filter { $0.timestamp >= windowStart }
        
        if recentMotion.count >= currentConfig.minMotionSamples {
            let magnitudes = recentMotion.map { $0.magnitude }
            let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
            let variance = magnitudes.reduce(0) { $0, $1 in $0 + ($1 - mean) * ($1 - mean) } / Double(magnitudes.count)
            let stdDev = sqrt(variance)
            
            let threshold = currentConfig.motionThresholdStdDev
            let confidence = stdDev >= threshold ? min(1.0, stdDev / threshold) : stdDev / threshold
            
            signals.append(AwakeSignal(
                timestamp: Date(),
                type: .motionActivity,
                confidence: confidence,
                rawValue: stdDev,
                threshold: threshold
            ))
        }
        
        let significantSignals = signals.filter { $0.isSignificant }
        let isAwake = significantSignals.count >= 1
        let confidence = calculateConfidence(from: signals)
        
        return AwakeDetectionResult(
            timestamp: Date(),
            isAwake: isAwake,
            confidence: confidence,
            signals: signals,
            heartRateValue: signals.first { $0.type == .heartRateIncrease }?.rawValue,
            motionValue: signals.first { $0.type == .motionActivity }?.rawValue,
            baselineHeartRate: baselineHeartRate
        )
    }
    
    private func analyzeForReSleep(_ data: SensorData) {
    }
    
    private func triggerReAlarm(reason: String) {
        guard case .antiSleepMonitoring = detectionState else { return }
        
        invalidateAllTimers()
        
        detectionState = .reAlarmPending(reason: reason)
        
        alarmController?.triggerAlarm()
        
        onReAlarmTriggered?(reason)
        
        print("Re-alarm triggered: \(reason)")
        
        reAlarmTimer = Timer.scheduledTimer(
            withTimeInterval: currentConfig.reAlarmCooldownSeconds,
            repeats: false
        ) { [weak self] _ in
            self?.restartConfirmationAfterReAlarm()
        }
        
        if let timer = reAlarmTimer {
            RunLoop.current.add(timer, forMode: .default)
        }
    }
    
    private func restartConfirmationAfterReAlarm() {
        guard case .reAlarmPending = detectionState else { return }
        
        detectionState = .alarmRinging(startTime: Date())
        startConfirmationWindow()
        
        print("Restarting confirmation window after re-alarm")
    }
    
    private func completeAntiSleepMonitoring() {
        invalidateAllTimers()
        
        if let status = antiSleepStatus {
            print("Anti-sleep monitoring completed: awake=\(status.awakeSignalsCount), sleep=\(status.sleepSignalsCount)")
        }
        
        detectionState = .idle
        antiSleepStatus = nil
    }
    
    private func invalidateAllTimers() {
        confirmationTimer?.invalidate()
        confirmationTimer = nil
        
        antiSleepTimer?.invalidate()
        antiSleepTimer = nil
        
        reAlarmTimer?.invalidate()
        reAlarmTimer = nil
    }
    
    private func clearHistory() {
        confirmationSignals.removeAll()
        confirmationStartTime = nil
        recentHeartRates.removeAll()
        recentMotionData.removeAll()
        baselineHeartRate = nil
    }
    
    func forceSilenceAlarm() {
        guard detectionState.isAlarmActive else { return }
        
        silenceAlarm()
        
        let now = Date()
        detectionState = .alarmSilenced(silenceTime: now)
        onAlarmSilenced?(now)
        
        startAntiSleepMonitoring()
    }
    
    func getCurrentHeartRate() -> Double? {
        return sensorService.currentHeartRate
    }
    
    func getCurrentMotionLevel() -> Double? {
        let windowStart = Date().addingTimeInterval(-currentConfig.motionAnalysisWindowSeconds)
        let recentMotion = recentMotionData.filter { $0.timestamp >= windowStart }
        
        guard !recentMotion.isEmpty else { return nil }
        
        return recentMotion.map { $0.magnitude }.reduce(0, +) / Double(recentMotion.count)
    }
    
    func getDetectionStatistics() -> (heartRateSamples: Int, motionSamples: Int, baselineHR: Double?, state: String) {
        return (
            heartRateSamples: recentHeartRates.count,
            motionSamples: recentMotionData.count,
            baselineHR: baselineHeartRate,
            state: detectionState.displayName
        )
    }
}
