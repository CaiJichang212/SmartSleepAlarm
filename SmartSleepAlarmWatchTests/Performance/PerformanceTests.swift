import XCTest
@testable import SmartSleepAlarmWatch

final class PerformanceTests: XCTestCase {
    
    var performanceMonitor: PerformanceMonitor!
    var performanceOptimizer: PerformanceOptimizer!
    
    override func setUp() {
        super.setUp()
        performanceMonitor = PerformanceMonitor()
        performanceOptimizer = PerformanceOptimizer()
    }
    
    override func tearDown() {
        performanceMonitor.stopMonitoring()
        performanceOptimizer.stopOptimization()
        performanceMonitor = nil
        performanceOptimizer = nil
        super.tearDown()
    }
    
    // MARK: - 电池消耗测试
    
    func testBatteryDrainTarget() {
        let expectation = XCTestExpectation(description: "电池消耗测试")
        
        performanceMonitor.startMonitoring()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            for _ in 0..<10 {
                self.performanceMonitor.recordResponseTime(Double.random(in: 1.0...4.0))
            }
            
            for _ in 0..<95 {
                self.performanceMonitor.recordGestureDetection(isAccurate: true)
            }
            for _ in 0..<5 {
                self.performanceMonitor.recordGestureDetection(isAccurate: false, isFalsePositive: true)
            }
            
            if let metrics = self.performanceMonitor.currentMetrics {
                XCTAssertLessThan(metrics.batteryDrainRate, 0.05, "电池消耗率应小于5%/小时")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testBatteryMetricsCalculation() {
        performanceMonitor.startMonitoring()
        
        let batteryMetrics = BatteryMetrics(
            startLevel: 1.0,
            currentLevel: 0.95,
            startTime: Date().addingTimeInterval(-3600),
            drainRate: 0.05,
            estimatedRemaining: 19 * 3600
        )
        
        XCTAssertEqual(batteryMetrics.drainPerHour, 0.05, accuracy: 0.01, "每小时消耗率计算应正确")
        XCTAssertEqual(batteryMetrics.currentLevel, 0.95, "当前电量应正确")
    }
    
    func testBatterySaverProfileOptimization() {
        performanceOptimizer.setProfile(.batterySaver)
        
        let sensorConfig = performanceOptimizer.sensorConfig
        
        XCTAssertGreaterThanOrEqual(sensorConfig.accelerometerInterval, 0.15, "省电模式下加速度计间隔应增大")
        XCTAssertGreaterThanOrEqual(sensorConfig.heartRateQueryInterval, 8.0, "省电模式下心率查询间隔应增大")
    }
    
    // MARK: - 响应速度测试
    
    func testResponseTimeTarget() {
        let responseTimes: [TimeInterval] = [1.2, 2.3, 1.8, 3.1, 2.5, 1.9, 2.1, 4.2, 3.5, 2.8]
        
        for time in responseTimes {
            performanceMonitor.recordResponseTime(time)
        }
        
        let metrics = performanceMonitor.responseTimeMetrics
        
        XCTAssertLessThan(metrics.average, 5.0, "平均响应时间应小于5秒")
        XCTAssertGreaterThanOrEqual(metrics.min, 0, "最小响应时间应大于等于0")
        XCTAssertLessThan(metrics.p95, 5.0, "P95响应时间应小于5秒")
    }
    
    func testResponseTimeMetricsCalculation() {
        let samples: [TimeInterval] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let metrics = ResponseTimeMetrics(samples: samples)
        
        XCTAssertEqual(metrics.average, 3.0, "平均响应时间计算应正确")
        XCTAssertEqual(metrics.min, 1.0, "最小响应时间应正确")
        XCTAssertEqual(metrics.max, 5.0, "最大响应时间应正确")
    }
    
    func testHighPerformanceProfileResponseTime() {
        performanceOptimizer.setProfile(.highPerformance)
        
        let backgroundConfig = performanceOptimizer.backgroundConfig
        
        XCTAssertLessThanOrEqual(backgroundConfig.monitoringInterval, 20.0, "高性能模式下监控间隔应减小")
        XCTAssertLessThanOrEqual(backgroundConfig.antiSleepCheckInterval, 5.0, "高性能模式下防睡检查间隔应减小")
    }
    
    // MARK: - 手势识别准确率测试
    
    func testGestureAccuracyTarget() {
        for _ in 0..<95 {
            performanceMonitor.recordGestureDetection(isAccurate: true)
        }
        
        for _ in 0..<5 {
            performanceMonitor.recordGestureDetection(isAccurate: false, isFalsePositive: true)
        }
        
        let gestureMetrics = performanceMonitor.gestureMetrics
        
        XCTAssertGreaterThan(gestureMetrics.accuracy, 0.95, "手势准确率应大于95%")
        XCTAssertGreaterThan(gestureMetrics.precision, 0.90, "手势精确率应大于90%")
        XCTAssertGreaterThan(gestureMetrics.f1Score, 0.90, "F1分数应大于0.90")
    }
    
    func testGestureMetricsCalculation() {
        var metrics = GestureAccuracyMetrics()
        metrics.truePositives = 95
        metrics.falsePositives = 3
        metrics.falseNegatives = 2
        metrics.totalDetections = 100
        
        XCTAssertEqual(metrics.accuracy, 0.95, accuracy: 0.01, "准确率计算应正确")
        XCTAssertEqual(metrics.precision, 0.969, accuracy: 0.01, "精确率计算应正确")
        XCTAssertEqual(metrics.recall, 0.979, accuracy: 0.01, "召回率计算应正确")
    }
    
    func testGestureOptimizationConfig() {
        let sensitiveConfig = GestureOptimizationConfig.sensitive
        let strictConfig = GestureOptimizationConfig.strict
        
        XCTAssertLessThan(sensitiveConfig.snapThreshold, strictConfig.snapThreshold, "敏感模式阈值应低于严格模式")
        XCTAssertLessThan(sensitiveConfig.confidenceThreshold, strictConfig.confidenceThreshold, "敏感模式置信度阈值应低于严格模式")
    }
    
    // MARK: - 性能等级评估测试
    
    func testPerformanceLevelEvaluation() {
        performanceMonitor.startMonitoring()
        
        for _ in 0..<10 {
            performanceMonitor.recordResponseTime(2.0)
        }
        
        for _ in 0..<98 {
            performanceMonitor.recordGestureDetection(isAccurate: true)
        }
        for _ in 0..<2 {
            performanceMonitor.recordGestureDetection(isAccurate: false, isFalsePositive: true)
        }
        
        let level = performanceMonitor.performanceLevel
        
        XCTAssertNotNil(level, "性能等级应被评估")
        XCTAssertTrue([.excellent, .good, .acceptable].contains(level), "性能等级应在可接受范围内")
    }
    
    func testPerformanceLevelDisplayNames() {
        XCTAssertEqual(PerformanceLevel.excellent.displayName, "优秀")
        XCTAssertEqual(PerformanceLevel.good.displayName, "良好")
        XCTAssertEqual(PerformanceLevel.acceptable.displayName, "可接受")
        XCTAssertEqual(PerformanceLevel.poor.displayName, "较差")
        XCTAssertEqual(PerformanceLevel.critical.displayName, "严重")
    }
    
    // MARK: - 优化配置测试
    
    func testOptimizationProfiles() {
        XCTAssertEqual(OptimizationProfile.balanced.displayName, "均衡模式")
        XCTAssertEqual(OptimizationProfile.batterySaver.displayName, "省电模式")
        XCTAssertEqual(OptimizationProfile.highPerformance.displayName, "高性能模式")
        XCTAssertEqual(OptimizationProfile.adaptive.displayName, "自适应模式")
    }
    
    func testSensorSamplingConfigs() {
        let balanced = SensorSamplingConfig.balanced
        let batterySaver = SensorSamplingConfig.batterySaver
        let highPerformance = SensorSamplingConfig.highPerformance
        
        XCTAssertGreaterThan(batterySaver.accelerometerInterval, balanced.accelerometerInterval, "省电模式采样间隔应大于均衡模式")
        XCTAssertLessThan(highPerformance.accelerometerInterval, balanced.accelerometerInterval, "高性能模式采样间隔应小于均衡模式")
    }
    
    func testBackgroundTaskConfigs() {
        let balanced = BackgroundTaskConfig.balanced
        let batterySaver = BackgroundTaskConfig.batterySaver
        let highPerformance = BackgroundTaskConfig.highPerformance
        
        XCTAssertGreaterThan(batterySaver.monitoringInterval, balanced.monitoringInterval, "省电模式监控间隔应大于均衡模式")
        XCTAssertLessThan(highPerformance.monitoringInterval, balanced.monitoringInterval, "高性能模式监控间隔应小于均衡模式")
    }
    
    // MARK: - 告警系统测试
    
    func testAlertTriggering() {
        performanceMonitor.startMonitoring()
        
        let expectation = XCTestExpectation(description: "告警触发测试")
        var receivedAlert: PerformanceAlert?
        
        performanceMonitor.onAlertTriggered = { alert in
            receivedAlert = alert
            expectation.fulfill()
        }
        
        performanceMonitor.recordResponseTime(10.0)
        
        wait(for: [expectation], timeout: 15.0)
        
        XCTAssertNotNil(receivedAlert, "应触发告警")
        XCTAssertEqual(receivedAlert?.type, .responseTime, "告警类型应为响应时间")
    }
    
    func testAlertSeverityLevels() {
        let infoAlert = PerformanceAlert(
            id: UUID(),
            timestamp: Date(),
            type: .sensorDegradation,
            message: "测试信息告警",
            severity: .info,
            suggestedAction: nil
        )
        
        let warningAlert = PerformanceAlert(
            id: UUID(),
            timestamp: Date(),
            type: .batteryDrain,
            message: "测试警告告警",
            severity: .warning,
            suggestedAction: "建议操作"
        )
        
        let criticalAlert = PerformanceAlert(
            id: UUID(),
            timestamp: Date(),
            type: .cpuOverload,
            message: "测试严重告警",
            severity: .critical,
            suggestedAction: "紧急操作"
        )
        
        XCTAssertNotNil(infoAlert)
        XCTAssertNotNil(warningAlert)
        XCTAssertNotNil(criticalAlert)
    }
    
    // MARK: - 自适应优化测试
    
    func testAdaptiveOptimization() {
        performanceOptimizer.setProfile(.adaptive)
        
        XCTAssertEqual(performanceOptimizer.currentProfile, .adaptive, "应设置为自适应模式")
    }
    
    func testAdaptiveSensorConfigForLowBattery() {
        let config = SensorSamplingConfig.adaptive(for: 0.15, performanceLevel: .critical)
        
        XCTAssertGreaterThanOrEqual(config.accelerometerInterval, 0.15, "低电量时应使用省电配置")
    }
    
    func testAdaptiveSensorConfigForHighBattery() {
        let config = SensorSamplingConfig.adaptive(for: 0.85, performanceLevel: .excellent)
        
        XCTAssertLessThanOrEqual(config.accelerometerInterval, 0.1, "高电量时可使用高性能配置")
    }
    
    // MARK: - 性能指标导出测试
    
    func testMetricsExport() {
        performanceMonitor.startMonitoring()
        
        for _ in 0..<10 {
            performanceMonitor.recordResponseTime(2.0)
        }
        
        let exportData = performanceMonitor.exportMetrics()
        
        XCTAssertNotNil(exportData, "应能导出性能数据")
        XCTAssertGreaterThan(exportData!.count, 0, "导出数据不应为空")
    }
    
    func testMetricsSummary() {
        performanceMonitor.startMonitoring()
        
        for _ in 0..<10 {
            performanceMonitor.recordResponseTime(2.0)
        }
        
        for _ in 0..<95 {
            performanceMonitor.recordGestureDetection(isAccurate: true)
        }
        
        let summary = performanceMonitor.getMetricsSummary()
        
        XCTAssertTrue(summary.contains("性能摘要"), "摘要应包含标题")
        XCTAssertTrue(summary.contains("电池消耗"), "摘要应包含电池消耗")
        XCTAssertTrue(summary.contains("响应时间"), "摘要应包含响应时间")
        XCTAssertTrue(summary.contains("手势准确率"), "摘要应包含手势准确率")
    }
    
    // MARK: - 综合性能目标测试
    
    func testAllPerformanceTargets() {
        performanceMonitor.startMonitoring()
        performanceOptimizer.startOptimization()
        
        let expectation = XCTestExpectation(description: "综合性能测试")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            
            for _ in 0..<100 {
                self.performanceMonitor.recordResponseTime(Double.random(in: 1.0...4.0))
            }
            
            for _ in 0..<96 {
                self.performanceMonitor.recordGestureDetection(isAccurate: true)
            }
            for _ in 0..<4 {
                self.performanceMonitor.recordGestureDetection(isAccurate: false, isFalsePositive: true)
            }
            
            if let metrics = self.performanceMonitor.currentMetrics {
                let targets = metrics.meetsTargets
                
                XCTAssertTrue(targets.battery || metrics.batteryDrainRate < 0.1, "电池消耗应接近目标")
                XCTAssertTrue(targets.response, "响应时间应达标")
                XCTAssertTrue(targets.gesture, "手势准确率应达标")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - 优化结果测试
    
    func testOptimizationResult() {
        let result = OptimizationResult(
            timestamp: Date(),
            profile: .balanced,
            previousConfig: "省电模式",
            newConfig: "均衡模式",
            reason: "测试优化",
            expectedImprovement: "预期改善"
        )
        
        XCTAssertEqual(result.profile, .balanced)
        XCTAssertEqual(result.previousConfig, "省电模式")
        XCTAssertEqual(result.newConfig, "均衡模式")
    }
    
    func testSensorOptimizationResult() {
        let result = SensorOptimizationResult(
            previousInterval: 0.1,
            newInterval: 0.15,
            expectedBatterySaving: 33.0,
            expectedLatencyIncrease: 50.0
        )
        
        XCTAssertEqual(result.previousInterval, 0.1)
        XCTAssertEqual(result.newInterval, 0.15)
        XCTAssertGreaterThan(result.expectedBatterySaving, 0)
    }
    
    func testBackgroundOptimizationResult() {
        let result = BackgroundOptimizationResult(
            previousInterval: 30.0,
            newInterval: 20.0,
            expectedResponseImprovement: 33.0
        )
        
        XCTAssertEqual(result.previousInterval, 30.0)
        XCTAssertEqual(result.newInterval, 20.0)
        XCTAssertGreaterThan(result.expectedResponseImprovement, 0)
    }
    
    func testGestureOptimizationResult() {
        let result = GestureOptimizationResult(
            previousThreshold: 2.0,
            newThreshold: 1.8,
            expectedAccuracyImprovement: 0.02
        )
        
        XCTAssertEqual(result.previousThreshold, 2.0)
        XCTAssertEqual(result.newThreshold, 1.8)
        XCTAssertGreaterThan(result.expectedAccuracyImprovement, 0)
    }
}
