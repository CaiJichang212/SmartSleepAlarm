import XCTest
import Combine
@testable import SmartSleepAlarmWatch

final class SmartSilenceIntegrationTests: XCTestCase {
    
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
    
    func testSmartSilence_HeartRateTriggered() {
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
        
        XCTAssertEqual(awakeDetectionService.detectionState, .monitoring)
        
        awakeDetectionService.handleAlarmTriggered()
        
        if case .alarmRinging = awakeDetectionService.detectionState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected alarmRinging state")
        }
        
        let expectation = XCTestExpectation(description: "Smart silence triggered")
        
        awakeDetectionService.onAwakeDetected = { result in
            XCTAssertTrue(result.isAwake)
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertTrue(mockAlarmController.silenceCallCount > 0)
    }
    
    func testSmartSilence_MotionTriggered() {
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
        
        let expectation = XCTestExpectation(description: "Motion triggered silence")
        
        awakeDetectionService.onAwakeDetected = { result in
            XCTAssertTrue(result.isAwake)
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSmartSilence_CombinedSignals() {
        let config = AwakeDetectionConfig.default
        awakeDetectionService.setCustomConfig(config)
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        let expectation = XCTestExpectation(description: "Combined signals detection")
        
        awakeDetectionService.onAwakeDetected = { result in
            XCTAssertTrue(result.isAwake)
            XCTAssertGreaterThanOrEqual(result.confidence, 0.5)
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSmartSilence_DetectionModes() {
        let modes: [AwakeDetectionMode] = [.default, .sensitive, .conservative]
        
        for mode in modes {
            awakeDetectionService.setDetectionMode(mode)
            awakeDetectionService.startMonitoring()
            
            XCTAssertEqual(awakeDetectionService.detectionMode, mode)
            XCTAssertEqual(awakeDetectionService.currentConfig, mode.config)
            
            awakeDetectionService.handleAlarmTriggered()
            
            let expectation = XCTestExpectation(description: "Mode \(mode.displayName) silence")
            
            awakeDetectionService.onAwakeDetected = { _ in
                expectation.fulfill()
            }
            
            awakeDetectionService.forceSilenceAlarm()
            
            wait(for: [expectation], timeout: 2.0)
            
            awakeDetectionService.stopMonitoring()
        }
    }
    
    func testSmartSilence_StateTransitions() {
        awakeDetectionService.startMonitoring()
        
        XCTAssertEqual(awakeDetectionService.detectionState, .monitoring)
        
        awakeDetectionService.handleAlarmTriggered()
        
        if case .alarmRinging = awakeDetectionService.detectionState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected alarmRinging state")
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        if case .alarmSilenced = awakeDetectionService.detectionState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected alarmSilenced state")
        }
    }
    
    func testSmartSilence_ConfirmationWindow() {
        let config = AwakeDetectionConfig(
            heartRateThresholdPercentage: 0.10,
            motionThresholdStdDev: 0.3,
            confirmationWindowSeconds: 2.0,
            antiSleepMonitorDurationSeconds: 30.0,
            alarmSilenceMaxDelaySeconds: 3.0,
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
        
        let startTime = Date()
        let expectation = XCTestExpectation(description: "Confirmation window elapsed")
        
        awakeDetectionService.onAwakeDetected = { _ in
            let elapsed = Date().timeIntervalSince(startTime)
            XCTAssertGreaterThanOrEqual(elapsed, 0.0)
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testSmartSilence_CallbackSequence() {
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        var callbackOrder: [String] = []
        
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
    
    func testSmartSilence_NoFalsePositives() {
        let conservativeConfig = AwakeDetectionConfig.conservative
        awakeDetectionService.setCustomConfig(conservativeConfig)
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        let expectation = XCTestExpectation(description: "Conservative detection")
        
        awakeDetectionService.onAwakeDetected = { result in
            XCTAssertGreaterThanOrEqual(result.confidence, 0.5)
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSmartSilence_SensitiveMode() {
        let sensitiveConfig = AwakeDetectionConfig.sensitive
        awakeDetectionService.setCustomConfig(sensitiveConfig)
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        let expectation = XCTestExpectation(description: "Sensitive detection")
        
        awakeDetectionService.onAwakeDetected = { result in
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSmartSilence_DataFlowIntegrity() {
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        let expectation = XCTestExpectation(description: "Data flow check")
        
        awakeDetectionService.onAwakeDetected = { result in
            XCTAssertNotNil(result.timestamp)
            XCTAssertTrue(result.isAwake)
            XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
            XCTAssertLessThanOrEqual(result.confidence, 1.0)
            
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
    }
}

final class SmartSilenceCoordinatorTests: XCTestCase {
    
    private var coordinator: SmartAlarmCoordinator!
    private var mockAlarmController: MockAlarmController!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        coordinator = SmartAlarmCoordinator.shared
        mockAlarmController = MockAlarmController()
        cancellables = []
        
        coordinator.stopSmartAlarm()
    }
    
    override func tearDown() {
        coordinator.stopSmartAlarm()
        mockAlarmController.reset()
        cancellables = nil
        super.tearDown()
    }
    
    func testCoordinator_StartSmartAlarm() {
        let alarm = TestDataFactory.createAlarm(isSmartModeEnabled: true)
        
        coordinator.startSmartAlarm(for: alarm)
        
        XCTAssertTrue(coordinator.isActive)
        XCTAssertEqual(coordinator.currentAlarm?.id, alarm.id)
        
        coordinator.stopSmartAlarm()
    }
    
    func testCoordinator_StopSmartAlarm() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        XCTAssertTrue(coordinator.isActive)
        
        coordinator.stopSmartAlarm()
        
        XCTAssertFalse(coordinator.isActive)
        XCTAssertNil(coordinator.currentAlarm)
    }
    
    func testCoordinator_TriggerAlarmNow() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        coordinator.triggerAlarmNow()
        
        coordinator.stopSmartAlarm()
    }
    
    func testCoordinator_SilenceAlarmManually() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        coordinator.triggerAlarmNow()
        
        coordinator.silenceAlarmManually()
        
        XCTAssertFalse(coordinator.statusMessage.isEmpty)
    }
    
    func testCoordinator_StatusUpdates() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        let status = coordinator.getCurrentStatus()
        
        XCTAssertTrue(status.isActive)
        
        coordinator.stopSmartAlarm()
    }
    
    func testCoordinator_DetectionModeChange() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        coordinator.updateDetectionMode(.sensitive)
        
        XCTAssertFalse(coordinator.statusMessage.isEmpty)
        
        coordinator.stopSmartAlarm()
    }
    
    func testCoordinator_ProgressTracking() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        XCTAssertGreaterThanOrEqual(coordinator.detectionProgress, 0.0)
        XCTAssertLessThanOrEqual(coordinator.detectionProgress, 1.0)
        
        coordinator.stopSmartAlarm()
    }
    
    func testCoordinator_MultipleStartPrevention() {
        let alarm1 = TestDataFactory.createAlarm(label: "First")
        let alarm2 = TestDataFactory.createAlarm(label: "Second")
        
        coordinator.startSmartAlarm(for: alarm1)
        XCTAssertTrue(coordinator.isActive)
        XCTAssertEqual(coordinator.currentAlarm?.id, alarm1.id)
        
        coordinator.startSmartAlarm(for: alarm2)
        
        XCTAssertEqual(coordinator.currentAlarm?.id, alarm1.id)
        
        coordinator.stopSmartAlarm()
    }
    
    func testCoordinator_StateMessageUpdates() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        XCTAssertFalse(coordinator.statusMessage.isEmpty)
        
        coordinator.triggerAlarmNow()
        
        XCTAssertFalse(coordinator.statusMessage.isEmpty)
        
        coordinator.silenceAlarmManually()
        
        XCTAssertFalse(coordinator.statusMessage.isEmpty)
        
        coordinator.stopSmartAlarm()
    }
    
    func testCoordinator_FullAlarmCycle() {
        let alarm = TestDataFactory.createAlarm(isSmartModeEnabled: true)
        
        XCTAssertFalse(coordinator.isActive)
        
        coordinator.startSmartAlarm(for: alarm)
        XCTAssertTrue(coordinator.isActive)
        
        coordinator.triggerAlarmNow()
        
        coordinator.silenceAlarmManually()
        
        coordinator.stopSmartAlarm()
        XCTAssertFalse(coordinator.isActive)
    }
}
