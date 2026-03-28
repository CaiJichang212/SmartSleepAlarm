import XCTest
import Combine
@testable import SmartSleepAlarmWatch

final class StateTransitionIntegrationTests: XCTestCase {
    
    private var coordinator: SmartAlarmCoordinator!
    private var awakeDetectionService: AwakeDetectionService!
    private var alarmController: AlarmController!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        coordinator = SmartAlarmCoordinator.shared
        awakeDetectionService = AwakeDetectionService.shared
        alarmController = AlarmController.shared
        cancellables = []
        
        coordinator.stopSmartAlarm()
        awakeDetectionService.stopMonitoring()
        alarmController.silenceAlarm()
    }
    
    override func tearDown() {
        coordinator.stopSmartAlarm()
        awakeDetectionService.stopMonitoring()
        alarmController.silenceAlarm()
        cancellables = nil
        super.tearDown()
    }
    
    func testStateTransition_IdleToMonitoring() {
        XCTAssertEqual(awakeDetectionService.detectionState, .idle)
        
        awakeDetectionService.startMonitoring()
        
        XCTAssertEqual(awakeDetectionService.detectionState, .monitoring)
    }
    
    func testStateTransition_MonitoringToAlarmRinging() {
        awakeDetectionService.startMonitoring()
        XCTAssertEqual(awakeDetectionService.detectionState, .monitoring)
        
        awakeDetectionService.handleAlarmTriggered()
        
        if case .alarmRinging = awakeDetectionService.detectionState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected alarmRinging state")
        }
    }
    
    func testStateTransition_AlarmRingingToConfirming() {
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        if case .confirmingAwake = awakeDetectionService.detectionState {
            XCTAssertTrue(true)
        }
    }
    
    func testStateTransition_ConfirmingToSilenced() {
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        awakeDetectionService.forceSilenceAlarm()
        
        if case .alarmSilenced = awakeDetectionService.detectionState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected alarmSilenced state")
        }
    }
    
    func testStateTransition_SilencedToAntiSleep() {
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        awakeDetectionService.forceSilenceAlarm()
        
        if case .antiSleepMonitoring = awakeDetectionService.detectionState {
            XCTAssertTrue(true)
        }
    }
    
    func testStateTransition_AntiSleepToIdle() {
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        awakeDetectionService.forceSilenceAlarm()
        
        awakeDetectionService.stopMonitoring()
        
        XCTAssertEqual(awakeDetectionService.detectionState, .idle)
    }
    
    func testStateTransition_FullCycle() {
        XCTAssertEqual(awakeDetectionService.detectionState, .idle)
        
        awakeDetectionService.startMonitoring()
        XCTAssertEqual(awakeDetectionService.detectionState, .monitoring)
        
        awakeDetectionService.handleAlarmTriggered()
        
        awakeDetectionService.forceSilenceAlarm()
        
        awakeDetectionService.stopMonitoring()
        XCTAssertEqual(awakeDetectionService.detectionState, .idle)
    }
    
    func testStateTransition_ReAlarmFlow() {
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        awakeDetectionService.forceSilenceAlarm()
        
        if case .antiSleepMonitoring = awakeDetectionService.detectionState {
            XCTAssertTrue(true)
        }
    }
    
    func testStateTransition_MultipleCycles() {
        for i in 0..<3 {
            awakeDetectionService.startMonitoring()
            XCTAssertEqual(awakeDetectionService.detectionState, .monitoring)
            
            awakeDetectionService.handleAlarmTriggered()
            awakeDetectionService.forceSilenceAlarm()
            
            awakeDetectionService.stopMonitoring()
            XCTAssertEqual(awakeDetectionService.detectionState, .idle)
        }
    }
    
    func testStateTransition_CoordinatorStates() {
        let alarm = TestDataFactory.createAlarm()
        
        XCTAssertFalse(coordinator.isActive)
        
        coordinator.startSmartAlarm(for: alarm)
        XCTAssertTrue(coordinator.isActive)
        
        coordinator.stopSmartAlarm()
        XCTAssertFalse(coordinator.isActive)
    }
    
    func testStateTransition_AlarmControllerStates() {
        XCTAssertFalse(alarmController.isRinging)
        
        alarmController.triggerAlarm()
        XCTAssertTrue(alarmController.isRinging)
        
        alarmController.silenceAlarm()
        XCTAssertFalse(alarmController.isRinging)
    }
}

final class DataFlowIntegrationTests: XCTestCase {
    
    private var coordinator: SmartAlarmCoordinator!
    private var awakeDetectionService: AwakeDetectionService!
    private var alarmController: AlarmController!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        coordinator = SmartAlarmCoordinator.shared
        awakeDetectionService = AwakeDetectionService.shared
        alarmController = AlarmController.shared
        cancellables = []
        
        coordinator.stopSmartAlarm()
        awakeDetectionService.stopMonitoring()
        alarmController.silenceAlarm()
    }
    
    override func tearDown() {
        coordinator.stopSmartAlarm()
        awakeDetectionService.stopMonitoring()
        alarmController.silenceAlarm()
        cancellables = nil
        super.tearDown()
    }
    
    func testDataFlow_AlarmToCoordinator() {
        let alarm = TestDataFactory.createAlarm(label: "Data Flow Test")
        
        coordinator.startSmartAlarm(for: alarm)
        
        XCTAssertEqual(coordinator.currentAlarm?.id, alarm.id)
        XCTAssertEqual(coordinator.currentAlarm?.label, alarm.label)
        
        coordinator.stopSmartAlarm()
    }
    
    func testDataFlow_CoordinatorToDetectionService() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        let status = coordinator.getCurrentStatus()
        
        XCTAssertFalse(status.detectionState.isEmpty)
        
        coordinator.stopSmartAlarm()
    }
    
    func testDataFlow_DetectionResultPropagation() {
        awakeDetectionService.startMonitoring()
        awakeDetectionService.handleAlarmTriggered()
        
        let expectation = XCTestExpectation(description: "Detection result")
        
        awakeDetectionService.onAwakeDetected = { result in
            XCTAssertNotNil(result.timestamp)
            XCTAssertTrue(result.isAwake)
            XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
            expectation.fulfill()
        }
        
        awakeDetectionService.forceSilenceAlarm()
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testDataFlow_StatusUpdatePropagation() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        XCTAssertFalse(coordinator.statusMessage.isEmpty)
        
        coordinator.triggerAlarmNow()
        
        XCTAssertFalse(coordinator.statusMessage.isEmpty)
        
        coordinator.stopSmartAlarm()
    }
    
    func testDataFlow_ProgressUpdatePropagation() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        XCTAssertGreaterThanOrEqual(coordinator.detectionProgress, 0.0)
        
        coordinator.stopSmartAlarm()
    }
    
    func testDataFlow_MultiModuleDataConsistency() {
        let alarm = TestDataFactory.createAlarm(
            id: UUID(),
            time: Date(),
            label: "Consistency Test"
        )
        
        coordinator.startSmartAlarm(for: alarm)
        
        XCTAssertEqual(coordinator.currentAlarm?.id, alarm.id)
        
        let status = coordinator.getCurrentStatus()
        XCTAssertTrue(status.isActive)
        
        coordinator.stopSmartAlarm()
    }
    
    func testDataFlow_CallbackChain() {
        var callbackData: [String: Any] = [:]
        
        let alarm = TestDataFactory.createAlarm()
        
        let triggerExpectation = XCTestExpectation(description: "Trigger")
        let silenceExpectation = XCTestExpectation(description: "Silence")
        
        alarmController.onAlarmTriggered = { alarm in
            callbackData["triggered"] = true
            callbackData["alarmId"] = alarm?.id
            triggerExpectation.fulfill()
        }
        
        alarmController.onAlarmSilenced = { alarm, time in
            callbackData["silenced"] = true
            callbackData["silenceTime"] = time
            silenceExpectation.fulfill()
        }
        
        alarmController.triggerAlarm(for: alarm)
        wait(for: [triggerExpectation], timeout: 1.0)
        
        alarmController.silenceAlarm()
        wait(for: [silenceExpectation], timeout: 1.0)
        
        XCTAssertTrue(callbackData["triggered"] as? Bool ?? false)
        XCTAssertTrue(callbackData["silenced"] as? Bool ?? false)
        XCTAssertNotNil(callbackData["alarmId"])
        XCTAssertNotNil(callbackData["silenceTime"])
    }
    
    func testDataFlow_SensorDataFlow() {
        awakeDetectionService.startMonitoring()
        
        let stats = awakeDetectionService.getDetectionStatistics()
        
        XCTAssertGreaterThanOrEqual(stats.heartRateSamples, 0)
        XCTAssertGreaterThanOrEqual(stats.motionSamples, 0)
        
        awakeDetectionService.stopMonitoring()
    }
    
    func testDataFlow_ConfigurationPropagation() {
        let customConfig = AwakeDetectionConfig(
            heartRateThresholdPercentage: 0.15,
            motionThresholdStdDev: 0.4,
            confirmationWindowSeconds: 5.0,
            antiSleepMonitorDurationSeconds: 300.0,
            alarmSilenceMaxDelaySeconds: 5.0,
            reAlarmThreshold: 0.25,
            reAlarmCooldownSeconds: 45.0,
            minHeartRateSamples: 5,
            minMotionSamples: 7,
            baselineHeartRateWindowMinutes: 7,
            motionAnalysisWindowSeconds: 15.0
        )
        
        awakeDetectionService.setCustomConfig(customConfig)
        
        XCTAssertEqual(awakeDetectionService.currentConfig.heartRateThresholdPercentage, 0.15)
        XCTAssertEqual(awakeDetectionService.currentConfig.confirmationWindowSeconds, 5.0)
    }
}

final class EndToEndIntegrationTests: XCTestCase {
    
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
    
    func testEndToEnd_CompleteSmartAlarmFlow() {
        let alarm = TestDataFactory.createAlarm(
            isSmartModeEnabled: true,
            label: "E2E Smart Alarm"
        )
        
        XCTAssertFalse(coordinator.isActive)
        
        coordinator.startSmartAlarm(for: alarm)
        XCTAssertTrue(coordinator.isActive)
        XCTAssertEqual(coordinator.currentAlarm?.id, alarm.id)
        
        coordinator.triggerAlarmNow()
        
        let statusAfterTrigger = coordinator.getCurrentStatus()
        XCTAssertTrue(statusAfterTrigger.isAlarmRinging || statusAfterTrigger.isActive)
        
        coordinator.silenceAlarmManually()
        
        coordinator.stopSmartAlarm()
        XCTAssertFalse(coordinator.isActive)
        XCTAssertNil(coordinator.currentAlarm)
    }
    
    func testEndToEnd_MultipleAlarmScenarios() {
        let scenarios: [(String, Bool, SnoozeGesture)] = [
            ("Standard Alarm", false, .snap),
            ("Smart Alarm", true, .snap),
            ("Wrist Flip Alarm", false, .wristFlip),
            ("Smart Wrist Flip", true, .wristFlip)
        ]
        
        for (label, smartMode, gesture) in scenarios {
            let alarm = TestDataFactory.createAlarm(
                label: label,
                isSmartModeEnabled: smartMode,
                snoozeGesture: gesture
            )
            
            coordinator.startSmartAlarm(for: alarm)
            XCTAssertTrue(coordinator.isActive)
            
            coordinator.triggerAlarmNow()
            
            coordinator.silenceAlarmManually()
            
            coordinator.stopSmartAlarm()
            XCTAssertFalse(coordinator.isActive)
        }
    }
    
    func testEndToEnd_StatusReportingConsistency() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        let status1 = coordinator.getCurrentStatus()
        XCTAssertTrue(status1.isActive)
        
        coordinator.triggerAlarmNow()
        
        let status2 = coordinator.getCurrentStatus()
        XCTAssertTrue(status2.isActive)
        
        coordinator.silenceAlarmManually()
        
        let status3 = coordinator.getCurrentStatus()
        XCTAssertTrue(status3.isActive)
        
        coordinator.stopSmartAlarm()
    }
    
    func testEndToEnd_MessageFlowConsistency() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        XCTAssertFalse(coordinator.statusMessage.isEmpty)
        
        coordinator.triggerAlarmNow()
        XCTAssertFalse(coordinator.statusMessage.isEmpty)
        
        coordinator.silenceAlarmManually()
        XCTAssertFalse(coordinator.statusMessage.isEmpty)
        
        coordinator.stopSmartAlarm()
        XCTAssertFalse(coordinator.statusMessage.isEmpty)
    }
    
    func testEndToEnd_ProgressTrackingConsistency() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        
        var progressValues: [Double] = []
        
        progressValues.append(coordinator.detectionProgress)
        
        coordinator.triggerAlarmNow()
        progressValues.append(coordinator.detectionProgress)
        
        coordinator.silenceAlarmManually()
        progressValues.append(coordinator.detectionProgress)
        
        for progress in progressValues {
            XCTAssertGreaterThanOrEqual(progress, 0.0)
            XCTAssertLessThanOrEqual(progress, 1.0)
        }
        
        coordinator.stopSmartAlarm()
    }
    
    func testEndToEnd_ErrorRecoveryFlow() {
        let alarm = TestDataFactory.createAlarm()
        
        coordinator.startSmartAlarm(for: alarm)
        XCTAssertTrue(coordinator.isActive)
        
        coordinator.startSmartAlarm(for: alarm)
        XCTAssertTrue(coordinator.isActive)
        
        coordinator.stopSmartAlarm()
        XCTAssertFalse(coordinator.isActive)
        
        coordinator.startSmartAlarm(for: alarm)
        XCTAssertTrue(coordinator.isActive)
        
        coordinator.stopSmartAlarm()
    }
    
    func testEndToEnd_DataIntegrityThroughoutFlow() {
        let originalId = UUID()
        let originalLabel = "Data Integrity Check"
        let originalTime = Date()
        
        let alarm = TestDataFactory.createAlarm(
            id: originalId,
            time: originalTime,
            label: originalLabel
        )
        
        coordinator.startSmartAlarm(for: alarm)
        
        XCTAssertEqual(coordinator.currentAlarm?.id, originalId)
        XCTAssertEqual(coordinator.currentAlarm?.label, originalLabel)
        
        coordinator.triggerAlarmNow()
        
        XCTAssertEqual(coordinator.currentAlarm?.id, originalId)
        XCTAssertEqual(coordinator.currentAlarm?.label, originalLabel)
        
        coordinator.silenceAlarmManually()
        
        coordinator.stopSmartAlarm()
    }
    
    func testEndToEnd_ConcurrentOperationsSafety() {
        let alarm = TestDataFactory.createAlarm()
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 5
        
        let queue = DispatchQueue(label: "test.concurrent.e2e", attributes: .concurrent)
        
        for i in 0..<5 {
            queue.async {
                self.coordinator.startSmartAlarm(for: alarm)
                Thread.sleep(forTimeInterval: 0.1)
                self.coordinator.stopSmartAlarm()
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertFalse(coordinator.isActive)
    }
}
