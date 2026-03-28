import Foundation
import Combine
import WatchKit

struct PerformanceMetrics: Codable {
    let timestamp: Date
    let batteryLevel: Float
    let batteryDrainRate: Double
    let averageResponseTime: TimeInterval
    let gestureAccuracy: Double
    let sensorDataRate: Double
    let cpuUsage: Double
    let memoryUsageMB: Double
    let activeSensors: Int
    let degradedSensors: Int
    
    var summary: String {
        """
        性能指标 [\(timestamp.formatted())]:
        - 电池: \(Int(batteryLevel * 100))% (消耗率: \(String(format: "%.2f", batteryDrainRate * 100))%/小时)
        - 响应时间: \(String(format: "%.2f", averageResponseTime))秒
        - 手势准确率: \(String(format: "%.1f", gestureAccuracy * 100))%
        - 传感器数据率: \(String(format: "%.1f", sensorDataRate))/秒
        - CPU使用: \(String(format: "%.1f", cpuUsage * 100))%
        - 内存: \(String(format: "%.1f", memoryUsageMB))MB
        - 活跃传感器: \(activeSensors)/\(activeSensors + degradedSensors)
        """
    }
    
    var meetsTargets: (battery: Bool, response: Bool, gesture: Bool) {
        (
            battery: batteryDrainRate < 0.05,
            response: averageResponseTime < 5.0,
            gesture: gestureAccuracy > 0.95
        )
    }
}

struct BatteryMetrics {
    var startLevel: Float
    var currentLevel: Float
    var startTime: Date
    var drainRate: Double
    var estimatedRemaining: TimeInterval
    
    var drainPerHour: Double {
        let hours = Date().timeIntervalSince(startTime) / 3600
        guard hours > 0 else { return 0 }
        return Double(startLevel - currentLevel) / hours
    }
}

struct ResponseTimeMetrics {
    var samples: [TimeInterval]
    var average: TimeInterval {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0, +) / Double(samples.count)
    }
    var min: TimeInterval {
        samples.min() ?? 0
    }
    var max: TimeInterval {
        samples.max() ?? 0
    }
    var p95: TimeInterval {
        guard !samples.isEmpty else { return 0 }
        let sorted = samples.sorted()
        let index = Int(Double(sorted.count) * 0.95)
        return sorted[min(index, sorted.count - 1)]
    }
}

struct GestureAccuracyMetrics {
    var truePositives: Int = 0
    var falsePositives: Int = 0
    var falseNegatives: Int = 0
    var totalDetections: Int = 0
    
    var accuracy: Double {
        guard totalDetections > 0 else { return 0 }
        return Double(truePositives) / Double(totalDetections)
    }
    
    var precision: Double {
        let total = truePositives + falsePositives
        guard total > 0 else { return 0 }
        return Double(truePositives) / Double(total)
    }
    
    var recall: Double {
        let total = truePositives + falseNegatives
        guard total > 0 else { return 0 }
        return Double(truePositives) / Double(total)
    }
    
    var f1Score: Double {
        guard precision + recall > 0 else { return 0 }
        return 2 * precision * recall / (precision + recall)
    }
}

enum PerformanceLevel {
    case excellent
    case good
    case acceptable
    case poor
    case critical
    
    var displayName: String {
        switch self {
        case .excellent: return "优秀"
        case .good: return "良好"
        case .acceptable: return "可接受"
        case .poor: return "较差"
        case .critical: return "严重"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "绿色"
        case .good: return "蓝色"
        case .acceptable: return "黄色"
        case .poor: return "橙色"
        case .critical: return "红色"
        }
    }
}

struct PerformanceAlert {
    let id: UUID
    let timestamp: Date
    let type: AlertType
    let message: String
    let severity: AlertSeverity
    let suggestedAction: String?
    
    enum AlertType {
        case batteryDrain
        case responseTime
        case gestureAccuracy
        case sensorDegradation
        case memoryPressure
        case cpuOverload
    }
    
    enum AlertSeverity {
        case info
        case warning
        case critical
    }
}

class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var isMonitoring: Bool = false
    @Published var currentMetrics: PerformanceMetrics?
    @Published var batteryMetrics: BatteryMetrics?
    @Published var responseTimeMetrics = ResponseTimeMetrics(samples: [])
    @Published var gestureMetrics = GestureAccuracyMetrics()
    @Published var performanceLevel: PerformanceLevel = .good
    @Published var alerts: [PerformanceAlert] = []
    @Published var metricsHistory: [PerformanceMetrics] = []
    
    private var monitoringStartTime: Date?
    private var metricsCollectionTimer: Timer?
    private let metricsCollectionInterval: TimeInterval = 10.0
    
    private var responseTimes: [TimeInterval] = []
    private let maxResponseTimeSamples = 100
    
    private var batterySamples: [(timestamp: Date, level: Float)] = []
    private let maxBatterySamples = 60
    
    private let maxHistorySize = 1000
    private let maxAlertsSize = 50
    
    private let targetBatteryDrainPerHour: Double = 0.05
    private let targetResponseTime: TimeInterval = 5.0
    private let targetGestureAccuracy: Double = 0.95
    
    var onMetricsCollected: ((PerformanceMetrics) -> Void)?
    var onAlertTriggered: ((PerformanceAlert) -> Void)?
    var onPerformanceLevelChanged: ((PerformanceLevel) -> Void)?
    
    private override init() {
        super.init()
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        monitoringStartTime = Date()
        
        initializeBatteryMetrics()
        startMetricsCollection()
        
        logPerformanceEvent("性能监控已启动")
        print("Performance monitoring started")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        metricsCollectionTimer?.invalidate()
        metricsCollectionTimer = nil
        
        logPerformanceEvent("性能监控已停止")
        print("Performance monitoring stopped")
    }
    
    private func initializeBatteryMetrics() {
        let currentLevel = WKInterfaceDevice.current().batteryLevel
        batteryMetrics = BatteryMetrics(
            startLevel: currentLevel,
            currentLevel: currentLevel,
            startTime: Date(),
            drainRate: 0,
            estimatedRemaining: 0
        )
        
        batterySamples = [(Date(), currentLevel)]
    }
    
    private func startMetricsCollection() {
        metricsCollectionTimer = Timer.scheduledTimer(
            withTimeInterval: metricsCollectionInterval,
            repeats: true
        ) { [weak self] _ in
            self?.collectMetrics()
        }
        
        RunLoop.current.add(metricsCollectionTimer!, forMode: .default)
    }
    
    private func collectMetrics() {
        let metrics = gatherCurrentMetrics()
        currentMetrics = metrics
        metricsHistory.append(metrics)
        
        if metricsHistory.count > maxHistorySize {
            metricsHistory.removeFirst()
        }
        
        updateBatteryMetrics()
        evaluatePerformanceLevel()
        checkThresholds(metrics)
        
        onMetricsCollected?(metrics)
        
        logPerformanceEvent("指标采集: 电池=\(Int(metrics.batteryLevel * 100))%, 响应=\(String(format: "%.2f", metrics.averageResponseTime))s, 准确率=\(String(format: "%.1f", metrics.gestureAccuracy * 100))%")
    }
    
    private func gatherCurrentMetrics() -> PerformanceMetrics {
        let batteryLevel = WKInterfaceDevice.current().batteryLevel
        let batteryDrainRate = batteryMetrics?.drainPerHour ?? 0
        
        let responseTime = responseTimeMetrics.average
        
        let gestureAccuracy = gestureMetrics.accuracy
        
        let sensorDataRate = calculateSensorDataRate()
        
        let cpuUsage = getCPUUsage()
        let memoryUsage = getMemoryUsage()
        
        let (activeSensors, degradedSensors) = getSensorStatus()
        
        return PerformanceMetrics(
            timestamp: Date(),
            batteryLevel: batteryLevel,
            batteryDrainRate: batteryDrainRate,
            averageResponseTime: responseTime,
            gestureAccuracy: gestureAccuracy,
            sensorDataRate: sensorDataRate,
            cpuUsage: cpuUsage,
            memoryUsageMB: memoryUsage,
            activeSensors: activeSensors,
            degradedSensors: degradedSensors
        )
    }
    
    private func updateBatteryMetrics() {
        let currentLevel = WKInterfaceDevice.current().batteryLevel
        batterySamples.append((Date(), currentLevel))
        
        if batterySamples.count > maxBatterySamples {
            batterySamples.removeFirst()
        }
        
        if var metrics = batteryMetrics {
            metrics.currentLevel = currentLevel
            metrics.drainRate = metrics.drainPerHour
            
            if metrics.drainPerHour > 0 {
                metrics.estimatedRemaining = TimeInterval(currentLevel / Float(metrics.drainPerHour)) * 3600
            }
            
            batteryMetrics = metrics
        }
    }
    
    private func calculateSensorDataRate() -> Double {
        guard let startTime = monitoringStartTime else { return 0 }
        let duration = Date().timeIntervalSince(startTime)
        guard duration > 0 else { return 0 }
        
        let sensorService = SensorService.shared
        let recentData = sensorService.getRecentData(count: 100)
        return Double(recentData.count) / duration
    }
    
    private func getCPUUsage() -> Double {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        guard result == KERN_SUCCESS, let threads = threadList else { return 0 }
        
        var totalUsage: Double = 0
        
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var count = mach_msg_type_number_t(THREAD_INFO_MAX)
            
            let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
                infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), ptr, &count)
                }
            }
            
            if kr == KERN_SUCCESS && info.flags & TH_FLAGS_IDLE == 0 {
                totalUsage += Double(info.cpu_usage) / Double(TH_USAGE_SCALE)
            }
        }
        
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride))
        
        return totalUsage
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), ptr, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        
        return Double(info.resident_size) / 1024.0 / 1024.0
    }
    
    private func getSensorStatus() -> (active: Int, degraded: Int) {
        let sensorService = SensorService.shared
        let statuses = sensorService.sensorStatuses
        
        var active = 0
        var degraded = 0
        
        for (_, status) in statuses {
            if status.availability.isUsable && !status.isDataStale {
                active += 1
            } else {
                degraded += 1
            }
        }
        
        return (active, degraded)
    }
    
    func recordResponseTime(_ time: TimeInterval) {
        responseTimes.append(time)
        
        if responseTimes.count > maxResponseTimeSamples {
            responseTimes.removeFirst()
        }
        
        responseTimeMetrics = ResponseTimeMetrics(samples: responseTimes)
    }
    
    func recordGestureDetection(isAccurate: Bool, isFalsePositive: Bool = false, isFalseNegative: Bool = false) {
        gestureMetrics.totalDetections += 1
        
        if isAccurate {
            gestureMetrics.truePositives += 1
        } else if isFalsePositive {
            gestureMetrics.falsePositives += 1
        } else if isFalseNegative {
            gestureMetrics.falseNegatives += 1
        }
    }
    
    private func evaluatePerformanceLevel() {
        guard let metrics = currentMetrics else { return }
        
        let meetsTargets = metrics.meetsTargets
        var score = 0
        
        if meetsTargets.battery { score += 1 }
        if meetsTargets.response { score += 1 }
        if meetsTargets.gesture { score += 1 }
        
        let previousLevel = performanceLevel
        
        switch score {
        case 3:
            performanceLevel = .excellent
        case 2:
            performanceLevel = .good
        case 1:
            performanceLevel = .acceptable
        case 0:
            if metrics.batteryDrainRate > targetBatteryDrainPerHour * 2 ||
               metrics.averageResponseTime > targetResponseTime * 2 ||
               metrics.gestureAccuracy < targetGestureAccuracy * 0.8 {
                performanceLevel = .critical
            } else {
                performanceLevel = .poor
            }
        default:
            performanceLevel = .acceptable
        }
        
        if previousLevel != performanceLevel {
            onPerformanceLevelChanged?(performanceLevel)
            logPerformanceEvent("性能等级变更: \(previousLevel.displayName) -> \(performanceLevel.displayName)")
        }
    }
    
    private func checkThresholds(_ metrics: PerformanceMetrics) {
        if metrics.batteryDrainRate > targetBatteryDrainPerHour {
            triggerAlert(
                type: .batteryDrain,
                message: "电池消耗率过高: \(String(format: "%.2f", metrics.batteryDrainRate * 100))%/小时",
                severity: metrics.batteryDrainRate > targetBatteryDrainPerHour * 2 ? .critical : .warning,
                suggestedAction: "建议降低传感器采样频率"
            )
        }
        
        if metrics.averageResponseTime > targetResponseTime {
            triggerAlert(
                type: .responseTime,
                message: "响应时间过长: \(String(format: "%.2f", metrics.averageResponseTime))秒",
                severity: metrics.averageResponseTime > targetResponseTime * 2 ? .critical : .warning,
                suggestedAction: "建议优化后台任务调度"
            )
        }
        
        if metrics.gestureAccuracy < targetGestureAccuracy {
            triggerAlert(
                type: .gestureAccuracy,
                message: "手势识别准确率过低: \(String(format: "%.1f", metrics.gestureAccuracy * 100))%",
                severity: metrics.gestureAccuracy < targetGestureAccuracy * 0.8 ? .critical : .warning,
                suggestedAction: "建议调整手势检测阈值"
            )
        }
        
        if metrics.degradedSensors > 0 {
            triggerAlert(
                type: .sensorDegradation,
                message: "\(metrics.degradedSensors)个传感器处于降级状态",
                severity: .info,
                suggestedAction: nil
            )
        }
        
        if metrics.memoryUsageMB > 100 {
            triggerAlert(
                type: .memoryPressure,
                message: "内存使用过高: \(String(format: "%.1f", metrics.memoryUsageMB))MB",
                severity: metrics.memoryUsageMB > 150 ? .critical : .warning,
                suggestedAction: "建议清理缓存数据"
            )
        }
        
        if metrics.cpuUsage > 0.5 {
            triggerAlert(
                type: .cpuOverload,
                message: "CPU使用率过高: \(String(format: "%.1f", metrics.cpuUsage * 100))%",
                severity: metrics.cpuUsage > 0.8 ? .critical : .warning,
                suggestedAction: "建议减少后台计算任务"
            )
        }
    }
    
    private func triggerAlert(type: PerformanceAlert.AlertType, message: String, severity: PerformanceAlert.AlertSeverity, suggestedAction: String?) {
        let alert = PerformanceAlert(
            id: UUID(),
            timestamp: Date(),
            type: type,
            message: message,
            severity: severity,
            suggestedAction: suggestedAction
        )
        
        alerts.append(alert)
        
        if alerts.count > maxAlertsSize {
            alerts.removeFirst()
        }
        
        onAlertTriggered?(alert)
        
        logPerformanceEvent("告警[\(severity)]: \(message)")
    }
    
    private func logPerformanceEvent(_ message: String) {
        let timestamp = Date().formatted(date: .abbreviated, time: .standard)
        print("[PerformanceMonitor] \(timestamp): \(message)")
    }
    
    func getMetricsSummary() -> String {
        guard let metrics = currentMetrics else {
            return "暂无性能数据"
        }
        
        let targets = metrics.meetsTargets
        
        return """
        === 性能摘要 ===
        电池消耗: \(String(format: "%.2f", metrics.batteryDrainRate * 100))%/小时 \(targets.battery ? "✓" : "✗")
        响应时间: \(String(format: "%.2f", metrics.averageResponseTime))秒 \(targets.response ? "✓" : "✗")
        手势准确率: \(String(format: "%.1f", metrics.gestureAccuracy * 100))% \(targets.gesture ? "✓" : "✗")
        性能等级: \(performanceLevel.displayName)
        活跃告警: \(alerts.filter { $0.severity != .info }.count)
        """
    }
    
    func getDetailedReport() -> String {
        var report = getMetricsSummary()
        
        report += "\n\n=== 详细指标 ===\n"
        
        if let battery = batteryMetrics {
            report += "电池:\n"
            report += "  起始: \(Int(battery.startLevel * 100))%\n"
            report += "  当前: \(Int(battery.currentLevel * 100))%\n"
            report += "  消耗率: \(String(format: "%.2f", battery.drainPerHour * 100))%/小时\n"
        }
        
        report += "\n响应时间:\n"
        report += "  平均: \(String(format: "%.2f", responseTimeMetrics.average))秒\n"
        report += "  最小: \(String(format: "%.2f", responseTimeMetrics.min))秒\n"
        report += "  最大: \(String(format: "%.2f", responseTimeMetrics.max))秒\n"
        report += "  P95: \(String(format: "%.2f", responseTimeMetrics.p95))秒\n"
        
        report += "\n手势识别:\n"
        report += "  准确率: \(String(format: "%.1f", gestureMetrics.accuracy * 100))%\n"
        report += "  精确率: \(String(format: "%.1f", gestureMetrics.precision * 100))%\n"
        report += "  召回率: \(String(format: "%.1f", gestureMetrics.recall * 100))%\n"
        report += "  F1分数: \(String(format: "%.1f", gestureMetrics.f1Score * 100))%\n"
        
        if !alerts.isEmpty {
            report += "\n最近告警:\n"
            for alert in alerts.suffix(5) {
                report += "  [\(alert.severity)] \(alert.message)\n"
            }
        }
        
        return report
    }
    
    func resetMetrics() {
        responseTimes.removeAll()
        batterySamples.removeAll()
        metricsHistory.removeAll()
        alerts.removeAll()
        gestureMetrics = GestureAccuracyMetrics()
        responseTimeMetrics = ResponseTimeMetrics(samples: [])
        currentMetrics = nil
        batteryMetrics = nil
        performanceLevel = .good
        
        logPerformanceEvent("性能指标已重置")
    }
    
    func exportMetrics() -> Data? {
        let exportData = PerformanceExportData(
            exportTime: Date(),
            metrics: metricsHistory,
            responseTimes: responseTimes,
            gestureMetrics: gestureMetrics,
            alerts: alerts
        )
        
        return try? JSONEncoder().encode(exportData)
    }
}

struct PerformanceExportData: Codable {
    let exportTime: Date
    let metrics: [PerformanceMetrics]
    let responseTimes: [TimeInterval]
    let gestureMetrics: GestureAccuracyMetrics
    let alerts: [PerformanceAlert]
}

extension PerformanceAlert.AlertType: Codable {}
extension PerformanceAlert.AlertSeverity: Codable {}
