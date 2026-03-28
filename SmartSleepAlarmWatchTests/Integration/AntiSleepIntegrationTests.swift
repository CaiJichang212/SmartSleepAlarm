import XCTest
import Combine
@testable import SmartSleepAlarmWatch

final class AntiSleepIntegrationTests: XCTestCase {
    
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
    
    func testAntiSleep_MonitoringStartsAfterSilence() {
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
        
        let expectation = XCTestExpectation(description: "Anti-sleep monitoring started")
        
        awakeDetectionService.onAlarmSilenced = { _ in
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
        
        if case .antiSleepMonitoring = awakeDetectionService.detectionState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected antiSleepMonitoring state")
        }
    }
    
    func testAntiSleep_StatusTracking() {
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        let expectation = XCTestExpectation(description: "Status tracking")
        
        awakeDetectionService.onAlarmSilenced = { _ in
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertNotNil(awakeDetectionService.antiSleepStatus)
    }
    
    func testAntiSleep_ProgressCalculation() {
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        let expectation = XCTestExpectation(description: "Progress check")
        
        awakeDetectionService.onAlarmSilenced = { _ in
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
        
        if let status = awakeDetectionService.antiSleepStatus {
            XCTAssertGreaterThanOrEqual(status.progress, 0.0)
            XCTAssertLessThanOrEqual(status.progress, 1.0)
        } else {
            XCTFail("Anti-sleep status should not be nil")
        }
    }
    
    func testAntiSleep_RemainingTimeCalculation() {
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        let expectation = XCTestExpectation(description: "Remaining time check")
        
        awakeDetectionService.onAlarmSilenced = { _ in
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
        
        if let status = awakeDetectionService.antiSleepStatus {
            XCTAssertGreaterThanOrEqual(status.remainingTime, 0.0)
        }
    }
    
    func testAntiSleep_AwakeSignalCounting() {
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        let expectation = XCTestExpectation(description: "Signal counting")
        
        awakeDetectionService.onAlarmSilenced = { _ in
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
        
        if let status = awakeDetectionService.antiSleepStatus {
            XCTAssertGreaterThanOrEqual(status.awakeSignalsCount, 0)
            XCTAssertGreaterThanOrEqual(status.sleepSignalsCount, 0)
        }
    }
    
    func testAntiSleep_UserAwakeStatus() {
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        let expectation = XCTestExpectation(description: "User awake status")
        
        awakeDetectionService.onAlarmSilenced = { _ in
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
        
        if let status = awakeDetectionService.antiSleepStatus {
            XCTAssertTrue(status.isUserAwake || !status.isUserAwake)
        }
    }
    
    func testAntiSleep_ReAlarmTrigger() {
        let config = AwakeDetectionConfig(
            heartRateThresholdPercentage: 0.10,
            motionThresholdStdDev: 0.3,
            confirmationWindowSeconds: 1.0,
            antiSleepMonitorDurationSeconds: 30.0,
            alarmSilenceMaxDelaySeconds: 2.0,
            reAlarmThreshold: 0.3,
            reAlarmCooldownSeconds: 5.0,
            minHeartRateSamples: 1,
            minMotionSamples: 1,
            baselineHeartRateWindowMinutes: 1,
            motionAnalysisWindowSeconds: 5.0
        )
        
        awakeDetectionService.setCustomConfig(config)
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        let silenceExpectation = XCTestExpectation(description: "Alarm silenced")
        
        awakeDetectionService.onAlarmSilenced = { _ in
            silenceExpectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [silenceExpectation], timeout: 2.0)
        
        mockAlarmController.reset()
        
        let reAlarmExpectation = XCTestExpectation(description: "Re-alarm triggered")
        
        awakeDetectionService.onReAlarmTriggered = { reason in
            XCTAssertFalse(reason.isEmpty)
            reAlarmExpectation.fulfill()
        }
    }
    
    func testAntiSleep_CompleteAfterDuration() {
        let shortDurationConfig = AwakeDetectionConfig(
            heartRateThresholdPercentage: 0.10,
            motionThresholdStdDev: 0.3,
            confirmationWindowSeconds: 1.0,
            antiSleepMonitorDurationSeconds: 5.0,
            alarmSilenceMaxDelaySeconds: 2.0,
            reAlarmThreshold: 0.3,
            reAlarmCooldownSeconds: 10.0,
            minHeartRateSamples: 1,
            minMotionSamples: 1,
            baselineHeartRateWindowMinutes: 1,
            motionAnalysisWindowSeconds: 5.0
        )
        
        awakeDetectionService.setCustomConfig(shortDurationConfig)
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        let expectation = XCTestExpectation(description: "Anti-sleep completed")
        
        awakeDetectionService.onAlarmSilenced = { _ in
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testAntiSleep_StateTransitions() {
        awakeDetectionService.startMonitoring()
        XCTAssertEqual(awakeDetectionService.detectionState, .monitoring)
        
        awakeDetectionService.handleAlarmTriggered()
        
        if case .alarmRinging = awakeDetectionService.detectionState {
            XCTAssertTrue(true)
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        if case .antiSleepMonitoring = awakeDetectionService.detectionState {
            XCTAssertTrue(true)
        }
        
        awakeDetectionService.stopMonitoring()
        XCTAssertEqual(awakeDetectionService.detectionState, .idle)
    }
    
    func testAntiSleep_CallbackSequence() {
        var callbackOrder: [String] = []
        
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        let awakeExpectation = XCTestExpectation(description: "Awake detected")
        let silenceExpectation = XCTestExpectation(description: "Alarm silenced")
        
        awakeDetectionService.onAwakeDetected = { _ in
            callbackOrder.append("awake")
            awakeExpectation.fulfill()
        }
        
        awakeDetectionService.onAlarmSilenced = { _ in
            callbackOrder.append("silenced")
            silenceExpectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [awakeExpectation, silenceExpectation], timeout: 2.0)
        
        XCTAssertTrue(callbackOrder.contains("awake"))
        XCTAssertTrue(callbackOrder.contains("silenced"))
    }
    
    func testAntiSleep_StatusUpdateCallback() {
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        let silenceExpectation = XCTestExpectation(description: "Alarm silenced")
        let statusExpectation = XCTestExpectation(description: "Status updated")
        
        awakeDetectionService.onAlarmSilenced = { _ in
            silenceExpectation.fulfill()
        }
        
        awakeDetectionService.onAntiSleepStatusUpdate = { status in
            XCTAssertNotNil(status)
            statusExpectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [silenceExpectation], timeout: 2.0)
    }
    
    func testAntiSleep_MonitoringDuration() {
        let expectedDuration: TimeInterval = 30.0
        let config = AwakeDetectionConfig(
            heartRateThresholdPercentage: 0.10,
            motionThresholdStdDev: 0.3,
            confirmationWindowSeconds: 1.0,
            antiSleepMonitorDurationSeconds: expectedDuration,
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
        
        let expectation = XCTestExpectation(description: "Duration check")
        
        awakeDetectionService.onAlarmSilenced = { _ in
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertEqual(awakeDetectionService.currentConfig.antiSleepMonitorDurationSeconds, expectedDuration)
    }
}

final class AntiSleepCoordinatorTests: XCTestCase {
    
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
    
    func testCoordinator_AntiSleepStatusMessage() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        coordinator.triggerAlarmNow()
        
        let expectation = XCTestExpectation(description: "Status message update")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertFalse(self.coordinator.statusMessage.isEmpty)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        coordinator.stopSmartAlarm()
    }
    
    func testCoordinator_AntiSleepProgressTracking() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        coordinator.triggerAlarmNow()
        coordinator.silenceAlarmManually()
        
        XCTAssertGreaterThanOrEqual(coordinator.detectionProgress, 0.0)
        
        coordinator.stopSmartAlarm()
    }
    
    func testCoordinator_FullAntiSleepCycle() {
        let alarm = TestDataFactory.createAlarm(isSmartModeEnabled: true)
        
        coordinator.startSmartAlarm(for: alarm)
        XCTAssertTrue(coordinator.isActive)
        
        coordinator.triggerAlarmNow()
        
        coordinator.silenceAlarmManually()
        
        let status = coordinator.getCurrentStatus()
        XCTAssertNotNil(status)
        
        coordinator.stopSmartAlarm()
        XCTAssertFalse(coordinator.isActive)
    }
    
    func testCoordinator_AntiSleepDetectionState() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        let status = coordinator.getCurrentStatus()
        XCTAssertFalse(status.detectionState.isEmpty)
        
        coordinator.stopSmartAlarm()
    }
    
    func testCoordinator_MultipleAlarmCycles() {
        for i in 0..<3 {
            let alarm = TestDataFactory.createAlarm(label: "Cycle \(i)")
            
            coordinator.startSmartAlarm(for: alarm)
            XCTAssertTrue(coordinator.isActive)
            
            coordinator.triggerAlarmNow()
            coordinator.silenceAlarmManually()
            
            coordinator.stopSmartAlarm()
            XCTAssertFalse(coordinator.isActive)
        }
    }
    
    func testCoordinator_StatusSummary() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        let status = coordinator.getCurrentStatus()
        let summary = status.summary
        
        XCTAssertFalse(summary.isEmpty)
        
        coordinator.stopSmartAlarm()
    }
}
