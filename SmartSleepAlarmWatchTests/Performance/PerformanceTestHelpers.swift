import Foundation
import XCTest
@testable import SmartSleepAlarmWatch

class PerformanceTestHelpers {
    
    static let shared = PerformanceTestHelpers()
    
    private init() {}
    
    // MARK: - 性能数据生成器
    
    func generateSensorData(count: Int, heartRateRange: ClosedRange<Double> = 55...75, motionRange: ClosedRange<Double> = 0.05...0.3) -> [SensorData] {
        return (0..<count).map { i in
            SensorData(
                timestamp: Date().addingTimeInterval(Double(i) * 5.0),
                heartRate: Double.random(in: heartRateRange),
                heartRateVariability: Double.random(in: 20...60),
                accelerationX: Double.random(in: -motionRange.upperBound...motionRange.upperBound),
                accelerationY: Double.random(in: -motionRange.upperBound...motionRange.upperBound),
                accelerationZ: Double.random(in: -motionRange.upperBound...motionRange.upperBound),
                rotationRateX: Double.random(in: -0.5...0.5),
                rotationRateY: Double.random(in: -0.5...0.5),
                rotationRateZ: Double.random(in: -0.5...0.5)
            )
        }
    }
    
    func generateAwakeSensorData(count: Int) -> [SensorData] {
        return generateSensorData(
            count: count,
            heartRateRange: 70...100,
            motionRange: 0.2...0.8
        )
    }
    
    func generateSleepSensorData(count: Int) -> [SensorData] {
        return generateSensorData(
            count: count,
            heartRateRange: 50...65,
            motionRange: 0.01...0.1
        )
    }
    
    // MARK: - 手势数据生成器
    
    func generateSnapGestureData() -> [MotionSnapshot] {
        var snapshots: [MotionSnapshot] = []
        
        for i in 0..<10 {
            let acceleration: (x: Double, y: Double, z: Double)
            if i == 3 || i == 6 {
                acceleration = (2.5, 2.8, 2.3)
            } else {
                acceleration = (0.1, 0.1, -0.98)
            }
            
            snapshots.append(MotionSnapshot(
                acceleration: acceleration,
                rotation: (0.5, 0.5, 0.5),
                timestamp: Date().addingTimeInterval(Double(i) * 0.05)
            ))
        }
        
        return snapshots
    }
    
    func generateWristFlipGestureData() -> [MotionSnapshot] {
        return (0..<10).map { i in
            let rotationIntensity = i < 5 ? 0.5 : 5.0
            return MotionSnapshot(
                acceleration: (0.1, 0.1, -0.98),
                rotation: (rotationIntensity, rotationIntensity, rotationIntensity * 2),
                timestamp: Date().addingTimeInterval(Double(i) * 0.05)
            )
        }
    }
    
    func generateShakeGestureData() -> [MotionSnapshot] {
        return (0..<10).map { i in
            let sign = i % 2 == 0 ? 1.0 : -1.0
            return MotionSnapshot(
                acceleration: (sign * 3.5, sign * 3.0, -0.98),
                rotation: (0.1, 0.1, 0.1),
                timestamp: Date().addingTimeInterval(Double(i) * 0.05)
            )
        }
    }
    
    func generateRandomMotionData(count: Int) -> [MotionSnapshot] {
        return (0..<count).map { i in
            MotionSnapshot(
                acceleration: (
                    Double.random(in: -0.3...0.3),
                    Double.random(in: -0.3...0.3),
                    Double.random(in: -1.2...-0.8)
                ),
                rotation: (
                    Double.random(in: -0.3...0.3),
                    Double.random(in: -0.3...0.3),
                    Double.random(in: -0.3...0.3)
                ),
                timestamp: Date().addingTimeInterval(Double(i) * 0.05)
            )
        }
    }
    
    // MARK: - 性能模拟器
    
    func simulateBatteryDrain(duration: TimeInterval, initialLevel: Float = 1.0, drainRate: Float = 0.05) -> [(timestamp: Date, level: Float)] {
        let interval: TimeInterval = 60.0
        let steps = Int(duration / interval)
        
        return (0...steps).map { step in
            let level = max(0, initialLevel - drainRate * Float(step) / 60.0)
            return (Date().addingTimeInterval(Double(step) * interval), level)
        }
    }
    
    func simulateResponseTimes(count: Int, average: TimeInterval = 3.0, variance: TimeInterval = 1.0) -> [TimeInterval] {
        return (0..<count).map { _ in
            max(0.1, average + Double.random(in: -variance...variance))
        }
    }
    
    func simulateGestureDetections(total: Int, accuracy: Double = 0.95) -> (truePositives: Int, falsePositives: Int, falseNegatives: Int) {
        let truePositives = Int(Double(total) * accuracy)
        let errors = total - truePositives
        let falsePositives = errors / 2
        let falseNegatives = errors - falsePositives
        
        return (truePositives, falsePositives, falseNegatives)
    }
    
    // MARK: - 性能基准测试
    
    func benchmarkSensorDataProcessing(iterations: Int = 100) -> TimeInterval {
        let data = generateSensorData(count: 100)
        
        let start = Date()
        for _ in 0..<iterations {
            _ = processSensorDataBatch(data)
        }
        let end = Date()
        
        return end.timeIntervalSince(start) / Double(iterations)
    }
    
    private func processSensorDataBatch(_ data: [SensorData]) -> (avgHR: Double, avgMotion: Double) {
        let heartRates = data.compactMap { $0.heartRate }
        let motions = data.compactMap { $0.accelerationMagnitude }
        
        let avgHR = heartRates.isEmpty ? 0 : heartRates.reduce(0, +) / Double(heartRates.count)
        let avgMotion = motions.isEmpty ? 0 : motions.reduce(0, +) / Double(motions.count)
        
        return (avgHR, avgMotion)
    }
    
    func benchmarkGestureDetection(iterations: Int = 100) -> TimeInterval {
        let gestureService = GestureDetectionService.shared
        let snapData = generateSnapGestureData()
        
        let start = Date()
        for _ in 0..<iterations {
            for snapshot in snapData {
                gestureService.processMotionData(snapshot)
            }
        }
        let end = Date()
        
        return end.timeIntervalSince(start) / Double(iterations)
    }
    
    // MARK: - 性能验证助手
    
    func verifyPerformanceTargets(
        batteryDrain: Double,
        responseTime: TimeInterval,
        gestureAccuracy: Double
    ) -> (battery: Bool, response: Bool, gesture: Bool, overall: Bool) {
        let batteryTarget = batteryDrain < 0.05
        let responseTarget = responseTime < 5.0
        let gestureTarget = gestureAccuracy > 0.95
        
        return (
            battery: batteryTarget,
            response: responseTarget,
            gesture: gestureTarget,
            overall: batteryTarget && responseTarget && gestureTarget
        )
    }
    
    func calculatePerformanceScore(metrics: PerformanceMetrics) -> Double {
        var score = 0.0
        
        if metrics.batteryDrainRate < 0.03 {
            score += 0.4
        } else if metrics.batteryDrainRate < 0.05 {
            score += 0.3
        } else if metrics.batteryDrainRate < 0.08 {
            score += 0.1
        }
        
        if metrics.averageResponseTime < 2.0 {
            score += 0.3
        } else if metrics.averageResponseTime < 5.0 {
            score += 0.2
        } else if metrics.averageResponseTime < 8.0 {
            score += 0.1
        }
        
        if metrics.gestureAccuracy > 0.98 {
            score += 0.3
        } else if metrics.gestureAccuracy > 0.95 {
            score += 0.2
        } else if metrics.gestureAccuracy > 0.90 {
            score += 0.1
        }
        
        return score
    }
    
    // MARK: - 测试报告生成
    
    func generatePerformanceReport(
        batteryDrain: Double,
        responseTime: TimeInterval,
        gestureAccuracy: Double,
        duration: TimeInterval
    ) -> String {
        let targets = verifyPerformanceTargets(
            batteryDrain: batteryDrain,
            responseTime: responseTime,
            gestureAccuracy: gestureAccuracy
        )
        
        return """
        === 性能测试报告 ===
        测试时长: \(String(format: "%.1f", duration))秒
        
        电池消耗:
          实际: \(String(format: "%.2f", batteryDrain * 100))%/小时
          目标: <5%/小时
          结果: \(targets.battery ? "✓ 通过" : "✗ 未通过")
        
        响应时间:
          实际: \(String(format: "%.2f", responseTime))秒
          目标: <5秒
          结果: \(targets.response ? "✓ 通过" : "✗ 未通过")
        
        手势准确率:
          实际: \(String(format: "%.1f", gestureAccuracy * 100))%
          目标: >95%
          结果: \(targets.gesture ? "✓ 通过" : "✗ 未通过")
        
        综合评估: \(targets.overall ? "✓ 所有指标达标" : "✗ 部分指标未达标")
        """
    }
    
    func generateDetailedMetricsReport(metrics: PerformanceMetrics) -> String {
        let targets = metrics.meetsTargets
        
        return """
        === 详细性能指标 ===
        
        [电池状态]
        当前电量: \(Int(metrics.batteryLevel * 100))%
        消耗率: \(String(format: "%.2f", metrics.batteryDrainRate * 100))%/小时
        状态: \(targets.battery ? "正常" : "偏高")
        
        [响应性能]
        平均响应时间: \(String(format: "%.2f", metrics.averageResponseTime))秒
        状态: \(targets.response ? "正常" : "偏慢")
        
        [手势识别]
        准确率: \(String(format: "%.1f", metrics.gestureAccuracy * 100))%
        状态: \(targets.gesture ? "正常" : "偏低")
        
        [系统资源]
        CPU使用: \(String(format: "%.1f", metrics.cpuUsage * 100))%
        内存使用: \(String(format: "%.1f", metrics.memoryUsageMB))MB
        
        [传感器状态]
        活跃传感器: \(metrics.activeSensors)
        降级传感器: \(metrics.degradedSensors)
        数据采集率: \(String(format: "%.1f", metrics.sensorDataRate))/秒
        """
    }
}

// MARK: - XCTestCase 扩展

extension XCTestCase {
    
    func measurePerformance(description: String, operation: () -> Void) -> TimeInterval {
        let start = Date()
        operation()
        let end = Date()
        return end.timeIntervalSince(start)
    }
    
    func assertPerformanceTarget(
        actual: Double,
        target: Double,
        isLessThan: Bool = true,
        _ message: String = ""
    ) {
        if isLessThan {
            XCTAssertLessThan(actual, target, message)
        } else {
            XCTAssertGreaterThan(actual, target, message)
        }
    }
    
    func runPerformanceTest(
        name: String,
        iterations: Int = 100,
        operation: (Int) -> Void
    ) -> (average: TimeInterval, min: TimeInterval, max: TimeInterval) {
        var times: [TimeInterval] = []
        
        for i in 0..<iterations {
            let start = Date()
            operation(i)
            let end = Date()
            times.append(end.timeIntervalSince(start))
        }
        
        let average = times.reduce(0, +) / Double(times.count)
        let min = times.min() ?? 0
        let max = times.max() ?? 0
        
        print("[\(name)] 平均: \(String(format: "%.4f", average))秒, 最小: \(String(format: "%.4f", min))秒, 最大: \(String(format: "%.4f", max))秒")
        
        return (average, min, max)
    }
}

// MARK: - 性能测试数据模型

struct PerformanceTestResult {
    let testName: String
    let timestamp: Date
    let duration: TimeInterval
    let metrics: [String: Double]
    let passed: Bool
    let message: String
    
    var summary: String {
        """
        测试: \(testName)
        时间: \(timestamp.formatted())
        耗时: \(String(format: "%.2f", duration))秒
        结果: \(passed ? "✓ 通过" : "✗ 失败")
        消息: \(message)
        """
    }
}

struct PerformanceTestSuite {
    let name: String
    var results: [PerformanceTestResult]
    
    var allPassed: Bool {
        results.allSatisfy { $0.passed }
    }
    
    var passRate: Double {
        guard !results.isEmpty else { return 0 }
        let passed = results.filter { $0.passed }.count
        return Double(passed) / Double(results.count)
    }
    
    var averageDuration: TimeInterval {
        guard !results.isEmpty else { return 0 }
        return results.map { $0.duration }.reduce(0, +) / Double(results.count)
    }
    
    func generateReport() -> String {
        var report = """
        === 测试套件: \(name) ===
        总测试数: \(results.count)
        通过率: \(String(format: "%.1f", passRate * 100))%
        平均耗时: \(String(format: "%.2f", averageDuration))秒
        综合结果: \(allPassed ? "✓ 全部通过" : "✗ 部分失败")
        
        """
        
        for result in results {
            report += "\n" + result.summary + "\n"
        }
        
        return report
    }
}

// MARK: - 性能测试构建器

class PerformanceTestBuilder {
    private var suite = PerformanceTestSuite(name: "", results: [])
    
    func setName(_ name: String) -> Self {
        suite = PerformanceTestSuite(name: name, results: suite.results)
        return self
    }
    
    func addTest(name: String, metrics: [String: Double], passed: Bool, message: String, duration: TimeInterval = 0) -> Self {
        let result = PerformanceTestResult(
            testName: name,
            timestamp: Date(),
            duration: duration,
            metrics: metrics,
            passed: passed,
            message: message
        )
        suite.results.append(result)
        return self
    }
    
    func build() -> PerformanceTestSuite {
        return suite
    }
}
