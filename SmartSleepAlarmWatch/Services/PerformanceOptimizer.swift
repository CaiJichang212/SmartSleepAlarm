import Foundation
import Combine
import WatchKit
import CoreMotion

enum OptimizationProfile {
    case balanced
    case batterySaver
    case highPerformance
    case adaptive
    
    var displayName: String {
        switch self {
        case .balanced: return "均衡模式"
        case .batterySaver: return "省电模式"
        case .highPerformance: return "高性能模式"
        case .adaptive: return "自适应模式"
        }
    }
}

struct SensorSamplingConfig {
    var accelerometerInterval: TimeInterval
    var gyroscopeInterval: TimeInterval
    var heartRateQueryInterval: TimeInterval
    var dataCollectionInterval: TimeInterval
    
    static let balanced = SensorSamplingConfig(
        accelerometerInterval: 0.1,
        gyroscopeInterval: 0.1,
        heartRateQueryInterval: 5.0,
        dataCollectionInterval: 5.0
    )
    
    static let batterySaver = SensorSamplingConfig(
        accelerometerInterval: 0.2,
        gyroscopeInterval: 0.2,
        heartRateQueryInterval: 10.0,
        dataCollectionInterval: 10.0
    )
    
    static let highPerformance = SensorSamplingConfig(
        accelerometerInterval: 0.05,
        gyroscopeInterval: 0.05,
        heartRateQueryInterval: 2.0,
        dataCollectionInterval: 2.0
    )
    
    static func adaptive(for batteryLevel: Float, performanceLevel: PerformanceLevel) -> SensorSamplingConfig {
        if batteryLevel < 0.2 || performanceLevel == .critical {
            return .batterySaver
        } else if batteryLevel > 0.7 && performanceLevel == .excellent {
            return .highPerformance
        } else {
            return .balanced
        }
    }
}

struct BackgroundTaskConfig {
    var monitoringInterval: TimeInterval
    var phaseAnalysisInterval: TimeInterval
    var heartbeatInterval: TimeInterval
    var antiSleepCheckInterval: TimeInterval
    
    static let balanced = BackgroundTaskConfig(
        monitoringInterval: 30.0,
        phaseAnalysisInterval: 30.0,
        heartbeatInterval: 60.0,
        antiSleepCheckInterval: 5.0
    )
    
    static let batterySaver = BackgroundTaskConfig(
        monitoringInterval: 60.0,
        phaseAnalysisInterval: 60.0,
        heartbeatInterval: 120.0,
        antiSleepCheckInterval: 10.0
    )
    
    static let highPerformance = BackgroundTaskConfig(
        monitoringInterval: 15.0,
        phaseAnalysisInterval: 15.0,
        heartbeatInterval: 30.0,
        antiSleepCheckInterval: 3.0
    )
}

struct GestureOptimizationConfig {
    var snapThreshold: Double
    var wristFlipThreshold: Double
    var shakeThreshold: Double
    var gestureCooldown: TimeInterval
    var bufferSize: Int
    var confidenceThreshold: Double
    
    static let `default` = GestureOptimizationConfig(
        snapThreshold: 2.0,
        wristFlipThreshold: 4.0,
        shakeThreshold: 3.0,
        gestureCooldown: 1.0,
        bufferSize: 50,
        confidenceThreshold: 0.95
    )
    
    static let sensitive = GestureOptimizationConfig(
        snapThreshold: 1.5,
        wristFlipThreshold: 3.0,
        shakeThreshold: 2.5,
        gestureCooldown: 0.8,
        bufferSize: 60,
        confidenceThreshold: 0.90
    )
    
    static let strict = GestureOptimizationConfig(
        snapThreshold: 2.5,
        wristFlipThreshold: 5.0,
        shakeThreshold: 3.5,
        gestureCooldown: 1.2,
        bufferSize: 40,
        confidenceThreshold: 0.98
    )
}

struct OptimizationResult {
    let timestamp: Date
    let profile: OptimizationProfile
    let previousConfig: String
    let newConfig: String
    let reason: String
    let expectedImprovement: String
}

class PerformanceOptimizer: ObservableObject {
    static let shared = PerformanceOptimizer()
    
    @Published var currentProfile: OptimizationProfile = .balanced
    @Published var sensorConfig: SensorSamplingConfig = .balanced
    @Published var backgroundConfig: BackgroundTaskConfig = .balanced
    @Published var gestureConfig: GestureOptimizationConfig = .default
    @Published var isOptimizing: Bool = false
    @Published var optimizationHistory: [OptimizationResult] = []
    
    private let performanceMonitor = PerformanceMonitor.shared
    private let sensorService = SensorService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private var adaptiveOptimizationTimer: Timer?
    private let adaptiveCheckInterval: TimeInterval = 30.0
    
    private let targetBatteryDrain: Double = 0.05
    private let targetResponseTime: TimeInterval = 5.0
    private let targetGestureAccuracy: Double = 0.95
    
    private var lastBatteryLevel: Float = 1.0
    private var lastOptimizationTime: Date?
    private let minOptimizationInterval: TimeInterval = 60.0
    
    var onOptimizationApplied: ((OptimizationResult) -> Void)?
    var onProfileChanged: ((OptimizationProfile) -> Void)?
    
    private override init() {
        super.init()
        setupBindings()
    }
    
    private func setupBindings() {
        performanceMonitor.$performanceLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.handlePerformanceLevelChange(level)
            }
            .store(in: &cancellables)
        
        performanceMonitor.$currentMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.handleMetricsUpdate(metrics)
            }
            .store(in: &cancellables)
    }
    
    func startOptimization() {
        isOptimizing = true
        startAdaptiveOptimization()
        
        logOptimizationEvent("性能优化已启动，当前配置: \(currentProfile.displayName)")
    }
    
    func stopOptimization() {
        isOptimizing = false
        adaptiveOptimizationTimer?.invalidate()
        adaptiveOptimizationTimer = nil
        
        logOptimizationEvent("性能优化已停止")
    }
    
    private func startAdaptiveOptimization() {
        adaptiveOptimizationTimer = Timer.scheduledTimer(
            withTimeInterval: adaptiveCheckInterval,
            repeats: true
        ) { [weak self] _ in
            self?.performAdaptiveOptimization()
        }
        
        RunLoop.current.add(adaptiveOptimizationTimer!, forMode: .default)
    }
    
    func setProfile(_ profile: OptimizationProfile) {
        let previousProfile = currentProfile
        currentProfile = profile
        
        switch profile {
        case .balanced:
            applyBalancedConfig()
        case .batterySaver:
            applyBatterySaverConfig()
        case .highPerformance:
            applyHighPerformanceConfig()
        case .adaptive:
            applyAdaptiveConfig()
        }
        
        let result = OptimizationResult(
            timestamp: Date(),
            profile: profile,
            previousConfig: previousProfile.displayName,
            newConfig: profile.displayName,
            reason: "用户手动切换",
            expectedImprovement: getExpectedImprovement(for: profile)
        )
        
        optimizationHistory.append(result)
        onProfileChanged?(profile)
        
        logOptimizationEvent("配置切换: \(previousProfile.displayName) -> \(profile.displayName)")
    }
    
    private func applyBalancedConfig() {
        sensorConfig = .balanced
        backgroundConfig = .balanced
        gestureConfig = .default
        
        applySensorConfig()
        applyBackgroundConfig()
        applyGestureConfig()
    }
    
    private func applyBatterySaverConfig() {
        sensorConfig = .batterySaver
        backgroundConfig = .batterySaver
        gestureConfig = .strict
        
        applySensorConfig()
        applyBackgroundConfig()
        applyGestureConfig()
    }
    
    private func applyHighPerformanceConfig() {
        sensorConfig = .highPerformance
        backgroundConfig = .highPerformance
        gestureConfig = .sensitive
        
        applySensorConfig()
        applyBackgroundConfig()
        applyGestureConfig()
    }
    
    private func applyAdaptiveConfig() {
        let batteryLevel = WKInterfaceDevice.current().batteryLevel
        let performanceLevel = performanceMonitor.performanceLevel
        
        sensorConfig = .adaptive(for: batteryLevel, performanceLevel: performanceLevel)
        
        if batteryLevel < 0.2 || performanceLevel == .critical {
            backgroundConfig = .batterySaver
            gestureConfig = .strict
        } else if batteryLevel > 0.7 && performanceLevel == .excellent {
            backgroundConfig = .highPerformance
            gestureConfig = .sensitive
        } else {
            backgroundConfig = .balanced
            gestureConfig = .default
        }
        
        applySensorConfig()
        applyBackgroundConfig()
        applyGestureConfig()
    }
    
    private func applySensorConfig() {
        let motionManager = CMMotionManager()
        
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = sensorConfig.accelerometerInterval
        }
        
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = sensorConfig.gyroscopeInterval
        }
        
        logOptimizationEvent("传感器配置已更新: 加速度=\(sensorConfig.accelerometerInterval)s, 陀螺仪=\(sensorConfig.gyroscopeInterval)s")
    }
    
    private func applyBackgroundConfig() {
        logOptimizationEvent("后台任务配置已更新: 监控间隔=\(backgroundConfig.monitoringInterval)s")
    }
    
    private func applyGestureConfig() {
        GestureDetectionService.shared.setThresholds(
            snap: gestureConfig.snapThreshold,
            wristFlip: gestureConfig.wristFlipThreshold,
            shake: gestureConfig.shakeThreshold
        )
        
        logOptimizationEvent("手势检测配置已更新: 响指阈值=\(gestureConfig.snapThreshold)")
    }
    
    private func performAdaptiveOptimization() {
        guard currentProfile == .adaptive else { return }
        
        if let lastTime = lastOptimizationTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minOptimizationInterval {
                return
            }
        }
        
        guard let metrics = performanceMonitor.currentMetrics else { return }
        
        var optimizationsNeeded: [String] = []
        
        if metrics.batteryDrainRate > targetBatteryDrain {
            optimizationsNeeded.append("battery")
        }
        
        if metrics.averageResponseTime > targetResponseTime {
            optimizationsNeeded.append("response")
        }
        
        if metrics.gestureAccuracy < targetGestureAccuracy {
            optimizationsNeeded.append("gesture")
        }
        
        if !optimizationsNeeded.isEmpty {
            applyTargetedOptimizations(optimizationsNeeded, metrics: metrics)
        }
    }
    
    private func applyTargetedOptimizations(_ areas: [String], metrics: PerformanceMetrics) {
        var newSensorConfig = sensorConfig
        var newBackgroundConfig = backgroundConfig
        var newGestureConfig = gestureConfig
        var reasons: [String] = []
        
        if areas.contains("battery") {
            newSensorConfig.accelerometerInterval = min(0.3, newSensorConfig.accelerometerInterval * 1.2)
            newSensorConfig.gyroscopeInterval = min(0.3, newSensorConfig.gyroscopeInterval * 1.2)
            newSensorConfig.heartRateQueryInterval = min(15.0, newSensorConfig.heartRateQueryInterval * 1.2)
            newBackgroundConfig.monitoringInterval = min(90.0, newBackgroundConfig.monitoringInterval * 1.2)
            reasons.append("降低传感器采样频率以节省电量")
        }
        
        if areas.contains("response") {
            newBackgroundConfig.antiSleepCheckInterval = max(2.0, newBackgroundConfig.antiSleepCheckInterval * 0.8)
            newBackgroundConfig.phaseAnalysisInterval = max(10.0, newBackgroundConfig.phaseAnalysisInterval * 0.8)
            reasons.append("加快后台任务调度以提高响应速度")
        }
        
        if areas.contains("gesture") {
            newGestureConfig.confidenceThreshold = max(0.85, newGestureConfig.confidenceThreshold - 0.02)
            newGestureConfig.snapThreshold = max(1.5, newGestureConfig.snapThreshold - 0.1)
            newGestureConfig.wristFlipThreshold = max(3.0, newGestureConfig.wristFlipThreshold - 0.2)
            reasons.append("调整手势检测阈值以提高准确率")
        }
        
        sensorConfig = newSensorConfig
        backgroundConfig = newBackgroundConfig
        gestureConfig = newGestureConfig
        
        applySensorConfig()
        applyBackgroundConfig()
        applyGestureConfig()
        
        let result = OptimizationResult(
            timestamp: Date(),
            profile: .adaptive,
            previousConfig: "自适应调整前",
            newConfig: "自适应调整后",
            reason: reasons.joined(separator: "; "),
            expectedImprovement: "预期改善: \(areas.map { areaName($0) }.joined(separator: ", "))"
        )
        
        optimizationHistory.append(result)
        lastOptimizationTime = Date()
        
        onOptimizationApplied?(result)
        logOptimizationEvent("自适应优化已应用: \(reasons.joined(separator: ", "))")
    }
    
    private func areaName(_ area: String) -> String {
        switch area {
        case "battery": return "电池消耗"
        case "response": return "响应速度"
        case "gesture": return "手势准确率"
        default: return area
        }
    }
    
    private func handlePerformanceLevelChange(_ level: PerformanceLevel) {
        guard currentProfile == .adaptive else { return }
        
        switch level {
        case .critical:
            optimizeForCriticalState()
        case .poor:
            optimizeForPoorState()
        case .acceptable:
            break
        case .good, .excellent:
            break
        }
    }
    
    private func handleMetricsUpdate(_ metrics: PerformanceMetrics?) {
        guard let metrics = metrics, currentProfile == .adaptive else { return }
        
        let currentBatteryLevel = metrics.batteryLevel
        
        if currentBatteryLevel < 0.15 && lastBatteryLevel >= 0.15 {
            applyEmergencyBatteryOptimization()
        }
        
        lastBatteryLevel = currentBatteryLevel
    }
    
    private func optimizeForCriticalState() {
        sensorConfig = SensorSamplingConfig(
            accelerometerInterval: 0.3,
            gyroscopeInterval: 0.3,
            heartRateQueryInterval: 15.0,
            dataCollectionInterval: 15.0
        )
        
        backgroundConfig = BackgroundTaskConfig(
            monitoringInterval: 90.0,
            phaseAnalysisInterval: 90.0,
            heartbeatInterval: 180.0,
            antiSleepCheckInterval: 15.0
        )
        
        applySensorConfig()
        applyBackgroundConfig()
        
        logOptimizationEvent("应用紧急优化策略")
    }
    
    private func optimizeForPoorState() {
        sensorConfig = SensorSamplingConfig(
            accelerometerInterval: 0.2,
            gyroscopeInterval: 0.2,
            heartRateQueryInterval: 10.0,
            dataCollectionInterval: 10.0
        )
        
        applySensorConfig()
        
        logOptimizationEvent("应用低性能优化策略")
    }
    
    private func applyEmergencyBatteryOptimization() {
        sensorConfig = .batterySaver
        backgroundConfig = .batterySaver
        
        applySensorConfig()
        applyBackgroundConfig()
        
        let result = OptimizationResult(
            timestamp: Date(),
            profile: .adaptive,
            previousConfig: "紧急前",
            newConfig: "紧急省电",
            reason: "电量低于15%，启用紧急省电模式",
            expectedImprovement: "显著降低电池消耗"
        )
        
        optimizationHistory.append(result)
        onOptimizationApplied?(result)
        
        logOptimizationEvent("电量低于15%，启用紧急省电模式")
    }
    
    func optimizeSensorDataCollection() -> SensorOptimizationResult {
        let currentInterval = sensorConfig.accelerometerInterval
        var optimalInterval = currentInterval
        
        if let metrics = performanceMonitor.currentMetrics {
            if metrics.batteryDrainRate > targetBatteryDrain {
                optimalInterval = min(0.3, currentInterval * 1.2)
            } else if metrics.batteryDrainRate < targetBatteryDrain * 0.5 {
                optimalInterval = max(0.05, currentInterval * 0.9)
            }
        }
        
        let reduction = (optimalInterval - currentInterval) / currentInterval * 100
        
        return SensorOptimizationResult(
            previousInterval: currentInterval,
            newInterval: optimalInterval,
            expectedBatterySaving: max(0, reduction),
            expectedLatencyIncrease: max(0, -reduction)
        )
    }
    
    func optimizeBackgroundTaskScheduling() -> BackgroundOptimizationResult {
        let currentInterval = backgroundConfig.monitoringInterval
        var optimalInterval = currentInterval
        
        if let metrics = performanceMonitor.currentMetrics {
            if metrics.averageResponseTime > targetResponseTime {
                optimalInterval = max(15.0, currentInterval * 0.8)
            } else if metrics.averageResponseTime < targetResponseTime * 0.5 {
                optimalInterval = min(60.0, currentInterval * 1.1)
            }
        }
        
        return BackgroundOptimizationResult(
            previousInterval: currentInterval,
            newInterval: optimalInterval,
            expectedResponseImprovement: (currentInterval - optimalInterval) / currentInterval * 100
        )
    }
    
    func optimizeGestureAlgorithm() -> GestureOptimizationResult {
        let currentThreshold = gestureConfig.snapThreshold
        var optimalThreshold = currentThreshold
        
        if let metrics = performanceMonitor.currentMetrics {
            if metrics.gestureAccuracy < targetGestureAccuracy {
                optimalThreshold = max(1.5, currentThreshold - 0.1)
            } else if metrics.gestureAccuracy > 0.98 {
                optimalThreshold = min(2.5, currentThreshold + 0.05)
            }
        }
        
        return GestureOptimizationResult(
            previousThreshold: currentThreshold,
            newThreshold: optimalThreshold,
            expectedAccuracyImprovement: optimalThreshold < currentThreshold ? 0.02 : 0
        )
    }
    
    private func getExpectedImprovement(for profile: OptimizationProfile) -> String {
        switch profile {
        case .balanced:
            return "均衡性能与电池消耗"
        case .batterySaver:
            return "电池消耗降低约40%，响应时间增加约20%"
        case .highPerformance:
            return "响应时间降低约30%，电池消耗增加约25%"
        case .adaptive:
            return "根据实时性能指标自动调整"
        }
    }
    
    private func logOptimizationEvent(_ message: String) {
        let timestamp = Date().formatted(date: .abbreviated, time: .standard)
        print("[PerformanceOptimizer] \(timestamp): \(message)")
    }
    
    func getOptimizationSummary() -> String {
        return """
        === 性能优化摘要 ===
        当前配置: \(currentProfile.displayName)
        
        传感器采样:
          加速度计: \(String(format: "%.2f", sensorConfig.accelerometerInterval))秒
          陀螺仪: \(String(format: "%.2f", sensorConfig.gyroscopeInterval))秒
          心率查询: \(String(format: "%.1f", sensorConfig.heartRateQueryInterval))秒
        
        后台任务:
          监控间隔: \(String(format: "%.1f", backgroundConfig.monitoringInterval))秒
          阶段分析: \(String(format: "%.1f", backgroundConfig.phaseAnalysisInterval))秒
        
        手势检测:
          响指阈值: \(String(format: "%.1f", gestureConfig.snapThreshold))
          置信度阈值: \(String(format: "%.2f", gestureConfig.confidenceThreshold))
        
        优化历史: \(optimizationHistory.count)次
        """
    }
    
    func resetToDefaults() {
        currentProfile = .balanced
        applyBalancedConfig()
        
        logOptimizationEvent("已重置为默认配置")
    }
}

struct SensorOptimizationResult {
    let previousInterval: TimeInterval
    let newInterval: TimeInterval
    let expectedBatterySaving: Double
    let expectedLatencyIncrease: Double
}

struct BackgroundOptimizationResult {
    let previousInterval: TimeInterval
    let newInterval: TimeInterval
    let expectedResponseImprovement: Double
}

struct GestureOptimizationResult {
    let previousThreshold: Double
    let newThreshold: Double
    let expectedAccuracyImprovement: Double
}

extension PerformanceOptimizer {
    func getRecommendedProfile() -> OptimizationProfile {
        guard let metrics = performanceMonitor.currentMetrics else {
            return .balanced
        }
        
        if metrics.batteryLevel < 0.2 {
            return .batterySaver
        }
        
        if metrics.batteryDrainRate > targetBatteryDrain * 1.5 {
            return .batterySaver
        }
        
        if metrics.averageResponseTime > targetResponseTime * 1.5 {
            return .highPerformance
        }
        
        if metrics.gestureAccuracy < targetGestureAccuracy {
            return .highPerformance
        }
        
        return .adaptive
    }
    
    func estimateBatteryLife(with profile: OptimizationProfile) -> TimeInterval {
        let currentLevel = WKInterfaceDevice.current().batteryLevel
        
        let drainRate: Double
        switch profile {
        case .batterySaver:
            drainRate = 0.02
        case .balanced:
            drainRate = 0.04
        case .highPerformance:
            drainRate = 0.07
        case .adaptive:
            drainRate = 0.035
        }
        
        return TimeInterval(currentLevel / Float(drainRate)) * 3600
    }
}
