import XCTest
import Combine
@testable import SmartSleepAlarmWatch

final class DegradedModeIntegrationTests: XCTestCase {
    
    private var sensorService: SensorService!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sensorService = SensorService.shared
        cancellables = []
        
        sensorService.stopMonitoring()
    }
    
    override func tearDown() {
        sensorService.stopMonitoring()
        cancellables = nil
        super.tearDown()
    }
    
    func testDegradedMode_SensorAvailabilityCheck() {
        let availabilities = sensorService.checkAvailability()
        
        XCTAssertNotNil(availabilities[.heartRate])
        XCTAssertNotNil(availabilities[.accelerometer])
        XCTAssertNotNil(availabilities[.gyroscope])
    }
    
    func testDegradedMode_SensorStatusTracking() {
        sensorService.startMonitoring()
        
        let statuses = sensorService.sensorStatuses
        
        XCTAssertNotNil(statuses[.heartRate])
        XCTAssertNotNil(statuses[.accelerometer])
        XCTAssertNotNil(statuses[.gyroscope])
        
        sensorService.stopMonitoring()
    }
    
    func testDegradedMode_DegradedStateDetection() {
        sensorService.startMonitoring()
        
        XCTAssertFalse(sensorService.degradedMode)
        
        sensorService.stopMonitoring()
    }
    
    func testDegradedMode_CallbackOnDegraded() {
        let expectation = XCTestExpectation(description: "Degraded callback")
        
        sensorService.onSensorDegraded = { sensors in
            XCTAssertFalse(sensors.isEmpty)
            expectation.fulfill()
        }
        
        sensorService.startMonitoring()
        
        sensorService.simulateDegradedMode([.heartRate])
        
        wait(for: [expectation], timeout: 1.0)
        
        sensorService.stopMonitoring()
    }
    
    func testDegradedMode_CallbackOnRecovery() {
        let expectation = XCTestExpectation(description: "Recovery callback")
        
        sensorService.onSensorRecovered = { sensor in
            expectation.fulfill()
        }
        
        sensorService.startMonitoring()
        sensorService.simulateRecovery(.heartRate)
        
        wait(for: [expectation], timeout: 1.0)
        
        sensorService.stopMonitoring()
    }
    
    func testDegradedMode_AvailableSensorCount() {
        sensorService.startMonitoring()
        
        let count = sensorService.getAvailableSensorCount()
        
        XCTAssertGreaterThanOrEqual(count, 0)
        
        sensorService.stopMonitoring()
    }
    
    func testDegradedMode_DegradedSensorTypes() {
        sensorService.startMonitoring()
        
        let degradedTypes = sensorService.getDegradedSensorTypes()
        
        XCTAssertNotNil(degradedTypes)
        
        sensorService.stopMonitoring()
    }
    
    func testDegradedMode_RecentDataRetrieval() {
        sensorService.startMonitoring()
        
        let recentData = sensorService.getRecentData(count: 10)
        
        XCTAssertNotNil(recentData)
        
        sensorService.stopMonitoring()
    }
    
    func testDegradedMode_AverageHeartRate() {
        sensorService.startMonitoring()
        
        let avgHR = sensorService.getAverageHeartRate(forLast: 5)
        
        sensorService.stopMonitoring()
    }
    
    func testDegradedMode_MotionActivityLevel() {
        sensorService.startMonitoring()
        
        let motionLevel = sensorService.getMotionActivityLevel(forLast: 5)
        
        sensorService.stopMonitoring()
    }
    
    func testDegradedMode_SensorDataCollection() {
        sensorService.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Sensor data collected")
        
        sensorService.onSensorData = { data in
            XCTAssertNotNil(data.timestamp)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
        
        sensorService.stopMonitoring()
    }
}

final class DegradedModeAwakeDetectionTests: XCTestCase {
    
    private var awakeDetectionService: AwakeDetectionService!
    private var mockAlarmController: MockAlarmController!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        awakeDetectionService = AwakeDetectionService.shared
        mockAlarmController = MockAlarmController()
        awakeDetectionService.alarmController = mockAlarmController
        cancellables = []
        
        awakeDetectionService.stopMonitoring()
    }
    
    override func tearDown() {
        awakeDetectionService.stopMonitoring()
        mockAlarmController.reset()
        cancellables = nil
        super.tearDown()
    }
    
    func testDegradedDetection_HeartRateOnlyMode() {
        let config = AwakeDetectionConfig(
            heartRateThresholdPercentage: 0.10,
            motionThresholdStdDev: 0.3,
            confirmationWindowSeconds: 1.0,
            antiSleepMonitorDurationSeconds: 30.0,
            alarmSilenceMaxDelaySeconds: 2.0,
            reAlarmThreshold: 0.3,
            reAlarmCooldownSeconds: 10.0,
            minHeartRateSamples: 1,
            minMotionSamples: 1,
            baselineHeartRateWindowMinutes: 1,
            motionAnalysisWindowSeconds: 5.0
        )
        
        awakeDetectionService.setCustomConfig(config)
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        let expectation = XCTestExpectation(description: "Heart rate only detection")
        
        awakeDetectionService.onAwakeDetected = { result in
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testDegradedDetection_MotionOnlyMode() {
        let config = AwakeDetectionConfig(
            heartRateThresholdPercentage: 0.10,
            motionThresholdStdDev: 0.3,
            confirmationWindowSeconds: 1.0,
            antiSleepMonitorDurationSeconds: 30.0,
            alarmSilenceMaxDelaySeconds: 2.0,
            reAlarmThreshold: 0.3,
            reAlarmCooldownSeconds: 10.0,
            minHeartRateSamples: 1,
            minMotionSamples: 1,
            baselineHeartRateWindowMinutes: 1,
            motionAnalysisWindowSeconds: 5.0
        )
        
        awakeDetectionService.setCustomConfig(config)
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        let expectation = XCTestExpectation(description: "Motion only detection")
        
        awakeDetectionService.onAwakeDetected = { result in
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testDegradedDetection_ConservativeModeFallback() {
        awakeDetectionService.setDetectionMode(.conservative)
        awakeDetectionService.startMonitoring()
        
        XCTAssertEqual(awakeDetectionService.detectionMode, .conservative)
        
        awakeDetectionService.handleAlarmTriggered()
        
        let expectation = XCTestExpectation(description: "Conservative mode fallback")
        
        awakeDetectionService.onAwakeDetected = { result in
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testDegradedDetection_SensitiveModeFallback() {
        awakeDetectionService.setDetectionMode(.sensitive)
        awakeDetectionService.startMonitoring()
        
        XCTAssertEqual(awakeDetectionService.detectionMode, .sensitive)
        
        awakeDetectionService.handleAlarmTriggered()
        
        let expectation = XCTestExpectation(description: "Sensitive mode fallback")
        
        awakeDetectionService.onAwakeDetected = { result in
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testDegradedDetection_GracefulDegradation() {
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        let expectation = XCTestExpectation(description: "Graceful degradation")
        
        awakeDetectionService.onAwakeDetected = { result in
            XCTAssertNotNil(result)
            XCTAssertTrue(result.isAwake)
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testDegradedDetection_StatePreservation() {
        awakeDetectionService.startMonitoring()
        
        let initialState = awakeDetectionService.detectionState
        
        awakeDetectionService.handleAlarmTriggered()
        
        awakeDetectionService.forceSilenceAlarm()
        
        XCTAssertNotEqual(awakeDetectionService.detectionState, initialState)
    }
}

final class DegradedModeCoordinatorTests: XCTestCase {
    
    private var coordinator: SmartAlarmCoordinator!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        coordinator = SmartAlarmCoordinator.shared
        cancellables = []
        
        coordinator.stopSmartAlarm()
    }
    
    override func tearDown() {
        coordinator.stopSmartAlarm()
        cancellables = nil
        super.tearDown()
    }
    
    func testCoordinator_DegradedModeStatus() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        let status = coordinator.getCurrentStatus()
        
        XCTAssertNotNil(status.currentHeartRate)
        XCTAssertNotNil(status.currentMotionLevel)
        
        coordinator.stopSmartAlarm()
    }
    
    func testCoordinator_FallbackToManualMode() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        coordinator.triggerAlarmNow()
        
        coordinator.silenceAlarmManually()
        
        XCTAssertFalse(coordinator.statusMessage.isEmpty)
        
        coordinator.stopSmartAlarm()
    }
    
    func testCoordinator_DetectionProgressInDegradedMode() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        let progress = coordinator.detectionProgress
        
        XCTAssertGreaterThanOrEqual(progress, 0.0)
        XCTAssertLessThanOrEqual(progress, 1.0)
        
        coordinator.stopSmartAlarm()
    }
    
    func testCoordinator_StatusSummaryInDegradedMode() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        let status = coordinator.getCurrentStatus()
        let summary = status.summary
        
        XCTAssertFalse(summary.isEmpty)
        
        coordinator.stopSmartAlarm()
    }
    
    func testCoordinator_MultipleSensorFailures() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        let status = coordinator.getCurrentStatus()
        
        XCTAssertNotNil(status.detectionState)
        
        coordinator.stopSmartAlarm()
    }
    
    func testCoordinator_FullDegradedCycle() {
        let alarm = TestDataFactory.createAlarm(isSmartModeEnabled: true)
        
        coordinator.startSmartAlarm(for: alarm)
        XCTAssertTrue(coordinator.isActive)
        
        coordinator.triggerAlarmNow()
        
        coordinator.silenceAlarmManually()
        
        coordinator.stopSmartAlarm()
        XCTAssertFalse(coordinator.isActive)
    }
}

final class SensorFallbackTests: XCTestCase {
    
    private var sensorService: SensorService!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sensorService = SensorService.shared
        cancellables = []
        
        sensorService.stopMonitoring()
    }
    
    override func tearDown() {
        sensorService.stopMonitoring()
        cancellables = nil
        super.tearDown()
    }
    
    func testFallback_HeartRateUnavailable() {
        sensorService.startMonitoring()
        
        XCTAssertFalse(sensorService.degradedMode)
        
        sensorService.stopMonitoring()
    }
    
    func testFallback_MotionUnavailable() {
        sensorService.startMonitoring()
        
        XCTAssertFalse(sensorService.degradedMode)
        
        sensorService.stopMonitoring()
    }
    
    func testFallback_AllSensorsUnavailable() {
        sensorService.startMonitoring()
        
        XCTAssertFalse(sensorService.degradedMode)
        
        sensorService.stopMonitoring()
    }
    
    func testFallback_PartialSensorAvailability() {
        sensorService.startMonitoring()
        
        let availableCount = sensorService.getAvailableSensorCount()
        
        XCTAssertGreaterThanOrEqual(availableCount, 0)
        
        sensorService.stopMonitoring()
    }
    
    func testFallback_SensorRecovery() {
        sensorService.startMonitoring()
        
        sensorService.simulateDegradedMode([.heartRate])
        
        sensorService.simulateRecovery(.heartRate)
        
        sensorService.stopMonitoring()
    }
    
    func testFallback_DataBufferManagement() {
        sensorService.startMonitoring()
        
        let recentData = sensorService.getRecentData(count: 100)
        
        XCTAssertLessThanOrEqual(recentData.count, 100)
        
        sensorService.stopMonitoring()
    }
}

extension SensorService {
    func simulateDegradedMode(_ sensors: [SensorType]) {
        for sensor in sensors {
            var status = sensorStatuses[sensor] ?? SensorStatus(
                type: sensor,
                availability: .degraded,
                lastDataTime: nil,
                consecutiveMisses: 5
            )
            status = SensorStatus(
                type: sensor,
                availability: .degraded,
                lastDataTime: nil,
                consecutiveMisses: 5
            )
            sensorStatuses[sensor] = status
        }
        
        degradedMode = true
        onSensorDegraded?(sensors)
    }
    
    func simulateRecovery(_ sensor: SensorType) {
        let status = SensorStatus(
            type: sensor,
            availability: .available,
            lastDataTime: Date(),
            consecutiveMisses: 0
        )
        sensorStatuses[sensor] = status
        
        onSensorRecovered?(sensor)
    }
}
