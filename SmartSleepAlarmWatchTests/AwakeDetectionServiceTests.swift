import XCTest
@testable import SmartSleepAlarmWatch

final class AwakeDetectionServiceTests: XCTestCase {
    
    private var sut: AwakeDetectionService!
    private var mockAlarmController: MockAlarmController!
    
    override func setUp() {
        super.setUp()
        sut = AwakeDetectionService.shared
        mockAlarmController = MockAlarmController()
        sut.alarmController = mockAlarmController
    }
    
    override func tearDown() {
        sut.stopMonitoring()
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertEqual(sut.detectionState, .idle)
        XCTAssertNil(sut.lastDetectionResult)
        XCTAssertNil(sut.baselineHeartRate)
    }
    
    func testStartMonitoring() {
        sut.startMonitoring()
        
        XCTAssertEqual(sut.detectionState, .monitoring)
    }
    
    func testStartMonitoringWhenAlreadyMonitoring() {
        sut.startMonitoring()
        sut.startMonitoring()
        
        XCTAssertEqual(sut.detectionState, .monitoring)
    }
    
    func testStopMonitoring() {
        sut.startMonitoring()
        sut.stopMonitoring()
        
        XCTAssertEqual(sut.detectionState, .idle)
    }
    
    func testSetDetectionMode() {
        sut.setDetectionMode(.sensitive)
        
        XCTAssertEqual(sut.detectionMode, .sensitive)
        XCTAssertEqual(sut.currentConfig.heartRateThresholdPercentage, AwakeDetectionConfig.sensitive.heartRateThresholdPercentage)
    }
    
    func testSetCustomConfig() {
        let customConfig = AwakeDetectionConfig(
            heartRateThresholdPercentage: 0.20,
            motionThresholdStdDev: 0.5,
            confirmationWindowSeconds: 10.0,
            antiSleepMonitorDurationSeconds: 600.0,
            alarmSilenceMaxDelaySeconds: 8.0,
            reAlarmThreshold: 0.2,
            reAlarmCooldownSeconds: 60.0,
            minHeartRateSamples: 10,
            minMotionSamples: 15,
            baselineHeartRateWindowMinutes: 10,
            motionAnalysisWindowSeconds: 20.0
        )
        
        sut.setCustomConfig(customConfig)
        
        XCTAssertEqual(sut.currentConfig.heartRateThresholdPercentage, 0.20)
        XCTAssertEqual(sut.currentConfig.minHeartRateSamples, 10)
    }
    
    func testHandleAlarmTriggered() {
        sut.startMonitoring()
        sut.handleAlarmTriggered()
        
        if case .alarmRinging = sut.detectionState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected alarmRinging state")
        }
    }
    
    func testHandleAlarmTriggeredWhenNotMonitoring() {
        sut.handleAlarmTriggered()
        
        XCTAssertEqual(sut.detectionState, .idle)
    }
    
    func testForceSilenceAlarm() {
        sut.startMonitoring()
        sut.handleAlarmTriggered()
        sut.forceSilenceAlarm()
        
        if case .alarmSilenced = sut.detectionState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected alarmSilenced state")
        }
    }
    
    func testForceSilenceAlarmWhenNoAlarm() {
        sut.startMonitoring()
        sut.forceSilenceAlarm()
        
        XCTAssertEqual(sut.detectionState, .monitoring)
    }
    
    func testGetCurrentHeartRate() {
        let heartRate = sut.getCurrentHeartRate()
        XCTAssertNil(heartRate)
    }
    
    func testGetCurrentMotionLevel() {
        let motionLevel = sut.getCurrentMotionLevel()
        XCTAssertNil(motionLevel)
    }
    
    func testGetDetectionStatistics() {
        sut.startMonitoring()
        
        let stats = sut.getDetectionStatistics()
        
        XCTAssertEqual(stats.heartRateSamples, 0)
        XCTAssertEqual(stats.motionSamples, 0)
        XCTAssertNil(stats.baselineHR)
        XCTAssertEqual(stats.state, "监测中")
    }
    
    func testDetectionStateIsAlarmActive() {
        XCTAssertFalse(AwakeDetectionState.idle.isAlarmActive)
        XCTAssertFalse(AwakeDetectionState.monitoring.isAlarmActive)
        XCTAssertTrue(AwakeDetectionState.alarmRinging(startTime: Date()).isAlarmActive)
        XCTAssertFalse(AwakeDetectionState.alarmSilenced(silenceTime: Date()).isAlarmActive)
        XCTAssertTrue(AwakeDetectionState.reAlarmPending(reason: "test").isAlarmActive)
    }
    
    func testAwakeDetectedCallback() {
        let expectation = XCTestExpectation(description: "Awake detected callback")
        
        sut.onAwakeDetected = { result in
            XCTAssertTrue(result.isAwake)
            expectation.fulfill()
        }
        
        sut.startMonitoring()
        sut.handleAlarmTriggered()
        sut.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testAlarmSilencedCallback() {
        let expectation = XCTestExpectation(description: "Alarm silenced callback")
        
        sut.onAlarmSilenced = { date in
            XCTAssertNotNil(date)
            expectation.fulfill()
        }
        
        sut.startMonitoring()
        sut.handleAlarmTriggered()
        sut.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
    }
}

final class AwakeDetectionServiceHeartRateTests: XCTestCase {
    
    private var sut: AwakeDetectionService!
    
    override func setUp() {
        super.setUp()
        sut = AwakeDetectionService.shared
    }
    
    override func tearDown() {
        sut.stopMonitoring()
        super.tearDown()
    }
    
    func testHeartRateSignalDetection() {
        let config = AwakeDetectionConfig.default
        let baselineHR = 60.0
        let currentHR = 70.0
        
        let increaseRatio = (currentHR - baselineHR) / baselineHR
        let threshold = config.heartRateThresholdPercentage
        
        XCTAssertGreaterThanOrEqual(increaseRatio, threshold)
    }
    
    func testHeartRateSignalBelowThreshold() {
        let config = AwakeDetectionConfig.default
        let baselineHR = 60.0
        let currentHR = 63.0
        
        let increaseRatio = (currentHR - baselineHR) / baselineHR
        let threshold = config.heartRateThresholdPercentage
        
        XCTAssertLessThan(increaseRatio, threshold)
    }
    
    func testHeartRateSignalConfidenceCalculation() {
        let baselineHR = 60.0
        let currentHR = 72.0
        let threshold = 0.10
        
        let increaseRatio = (currentHR - baselineHR) / baselineHR
        let confidence = min(1.0, increaseRatio / threshold)
        
        XCTAssertEqual(confidence, 2.0, accuracy: 0.01)
    }
}

final class AwakeDetectionServiceMotionTests: XCTestCase {
    
    private var sut: AwakeDetectionService!
    
    override func setUp() {
        super.setUp()
        sut = AwakeDetectionService.shared
    }
    
    override func tearDown() {
        sut.stopMonitoring()
        super.tearDown()
    }
    
    func testMotionStandardDeviationCalculation() {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        let stdDev = sqrt(variance)
        
        let expectedStdDev = sqrt(2.0)
        XCTAssertEqual(stdDev, expectedStdDev, accuracy: 0.01)
    }
    
    func testMotionThresholdCheck() {
        let config = AwakeDetectionConfig.default
        let stdDev = 0.35
        
        XCTAssertGreaterThanOrEqual(stdDev, config.motionThresholdStdDev)
    }
    
    func testMotionBelowThreshold() {
        let config = AwakeDetectionConfig.default
        let stdDev = 0.25
        
        XCTAssertLessThan(stdDev, config.motionThresholdStdDev)
    }
}

final class AwakeDetectionServiceConfidenceTests: XCTestCase {
    
    func testConfidenceCalculationWithNoSignals() {
        let signals: [AwakeSignal] = []
        
        let significantSignals = signals.filter { $0.isSignificant }
        let signalScore = Double(significantSignals.count) / max(Double(signals.count), 1)
        
        XCTAssertEqual(signalScore, 0)
    }
    
    func testConfidenceCalculationWithMixedSignals() {
        let signals = [
            AwakeSignal(timestamp: Date(), type: .heartRateIncrease, confidence: 0.8, rawValue: 75, threshold: 70),
            AwakeSignal(timestamp: Date(), type: .motionActivity, confidence: 0.3, rawValue: 0.25, threshold: 0.3),
            AwakeSignal(timestamp: Date(), type: .combined, confidence: 0.9, rawValue: 2, threshold: 2)
        ]
        
        let significantSignals = signals.filter { $0.isSignificant }
        XCTAssertEqual(significantSignals.count, 2)
    }
    
    func testTypeBonusCalculation() {
        let signals = [
            AwakeSignal(timestamp: Date(), type: .heartRateIncrease, confidence: 0.8, rawValue: 75, threshold: 70),
            AwakeSignal(timestamp: Date(), type: .motionActivity, confidence: 0.7, rawValue: 0.35, threshold: 0.3)
        ]
        
        let significantSignals = signals.filter { $0.isSignificant }
        let uniqueTypes = Set(significantSignals.map { $0.type })
        let typeBonus = Double(uniqueTypes.count) * 0.15
        
        XCTAssertEqual(typeBonus, 0.3, accuracy: 0.01)
    }
}

class MockAlarmController: AlarmControllable {
    var isRinging = false
    var silenceCalled = false
    var triggerCalled = false
    
    func silenceAlarm() {
        isRinging = false
        silenceCalled = true
    }
    
    func triggerAlarm() {
        isRinging = true
        triggerCalled = true
    }
    
    func isAlarmRinging() -> Bool {
        return isRinging
    }
}
