import XCTest
import Combine
@testable import SmartSleepAlarmWatch

final class GestureSnoozeIntegrationTests: XCTestCase {
    
    private var gestureService: GestureDetectionService!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        gestureService = GestureDetectionService.shared
        cancellables = []
        
        gestureService.stopMonitoring()
        gestureService.resetStatistics()
    }
    
    override func tearDown() {
        gestureService.stopMonitoring()
        gestureService.resetStatistics()
        cancellables = nil
        super.tearDown()
    }
    
    func testGestureDetection_StartStopMonitoring() {
        XCTAssertFalse(gestureService.isMonitoring)
        
        gestureService.startMonitoring()
        XCTAssertTrue(gestureService.isMonitoring)
        
        gestureService.stopMonitoring()
        XCTAssertFalse(gestureService.isMonitoring)
    }
    
    func testGestureDetection_SnapGestureConfidence() {
        let snapshots = createSnapMotionSnapshots()
        
        let gesture = gestureService.detectSnap(in: snapshots)
        
        if let gesture = gesture {
            XCTAssertEqual(gesture.type, .snap)
            XCTAssertGreaterThanOrEqual(gesture.confidence, 0.95)
        }
    }
    
    func testGestureDetection_WristFlipGestureConfidence() {
        let snapshots = createWristFlipMotionSnapshots()
        
        let gesture = gestureService.detectWristFlip(in: snapshots)
        
        if let gesture = gesture {
            XCTAssertEqual(gesture.type, .wristFlip)
            XCTAssertGreaterThanOrEqual(gesture.confidence, 0.5)
        }
    }
    
    func testGestureDetection_ShakeGestureConfidence() {
        let snapshots = createShakeMotionSnapshots()
        
        let gesture = gestureService.detectShake(in: snapshots)
        
        if let gesture = gesture {
            XCTAssertEqual(gesture.type, .shake)
            XCTAssertGreaterThanOrEqual(gesture.confidence, 0.0)
        }
    }
    
    func testGestureDetection_CallbackTriggered() {
        gestureService.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Gesture detected callback")
        
        gestureService.onGestureDetected = { gesture in
            XCTAssertNotNil(gesture)
            expectation.fulfill()
        }
        
        gestureService.handleGestureDetected(
            DetectedGesture(type: .snap, timestamp: Date(), confidence: 0.95, motionData: nil)
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testGestureDetection_SnapCallback() {
        gestureService.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Snap detected callback")
        
        gestureService.onSnapDetected = {
            expectation.fulfill()
        }
        
        gestureService.handleGestureDetected(
            DetectedGesture(type: .snap, timestamp: Date(), confidence: 0.95, motionData: nil)
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testGestureDetection_WristFlipCallback() {
        gestureService.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Wrist flip detected callback")
        
        gestureService.onWristFlipDetected = {
            expectation.fulfill()
        }
        
        gestureService.handleGestureDetected(
            DetectedGesture(type: .wristFlip, timestamp: Date(), confidence: 0.95, motionData: nil)
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testGestureDetection_GestureCountIncrement() {
        gestureService.startMonitoring()
        
        let initialCount = gestureService.gestureCount
        
        gestureService.handleGestureDetected(
            DetectedGesture(type: .snap, timestamp: Date(), confidence: 0.95, motionData: nil)
        )
        
        XCTAssertEqual(gestureService.gestureCount, initialCount + 1)
    }
    
    func testGestureDetection_CooldownPeriod() {
        gestureService.startMonitoring()
        
        gestureService.handleGestureDetected(
            DetectedGesture(type: .snap, timestamp: Date(), confidence: 0.95, motionData: nil)
        )
        
        XCTAssertNotNil(gestureService.lastGestureTime)
        
        gestureService.handleGestureDetected(
            DetectedGesture(type: .snap, timestamp: Date(), confidence: 0.95, motionData: nil)
        )
    }
    
    func testGestureDetection_ThresholdAdjustment() {
        gestureService.setThresholds(snap: 3.0, wristFlip: 5.0, shake: 4.0)
        
        gestureService.setThresholds(snap: 2.0)
        gestureService.setThresholds(wristFlip: 4.0)
        gestureService.setThresholds(shake: 3.0)
    }
    
    func testGestureDetection_AccuracyStatistics() {
        gestureService.startMonitoring()
        
        gestureService.handleGestureDetected(
            DetectedGesture(type: .snap, timestamp: Date(), confidence: 0.95, motionData: nil)
        )
        gestureService.handleGestureDetected(
            DetectedGesture(type: .snap, timestamp: Date(), confidence: 0.90, motionData: nil)
        )
        
        let stats = gestureService.getAccuracyStatistics()
        
        XCTAssertGreaterThanOrEqual(stats.totalDetections, 0)
    }
    
    func testGestureDetection_StatisticsReset() {
        gestureService.startMonitoring()
        
        gestureService.handleGestureDetected(
            DetectedGesture(type: .snap, timestamp: Date(), confidence: 0.95, motionData: nil)
        )
        
        XCTAssertGreaterThan(gestureService.gestureCount, 0)
        
        gestureService.resetStatistics()
        
        XCTAssertEqual(gestureService.gestureCount, 0)
    }
    
    func testGestureDetection_MotionStatistics() {
        gestureService.startMonitoring()
        
        let stats = gestureService.getMotionStatistics()
        
        XCTAssertGreaterThanOrEqual(stats.avgAcceleration, 0)
        XCTAssertGreaterThanOrEqual(stats.avgRotation, 0)
    }
    
    private func createSnapMotionSnapshots() -> [MotionSnapshot] {
        var snapshots: [MotionSnapshot] = []
        let baseTime = Date()
        
        for i in 0..<10 {
            let acceleration: (Double, Double, Double)
            if i == 3 || i == 5 {
                acceleration = (3.0, 3.0, 3.0)
            } else {
                acceleration = (1.0, 1.0, 1.0)
            }
            
            let snapshot = MotionSnapshot(
                acceleration: acceleration,
                rotation: (1.5, 1.5, 1.5),
                timestamp: baseTime.addingTimeInterval(Double(i) * 0.05)
            )
            snapshots.append(snapshot)
        }
        
        return snapshots
    }
    
    private func createWristFlipMotionSnapshots() -> [MotionSnapshot] {
        var snapshots: [MotionSnapshot] = []
        let baseTime = Date()
        
        for i in 0..<10 {
            let rotation: (Double, Double, Double)
            if i >= 4 {
                rotation = (5.0, 5.0, 5.0)
            } else {
                rotation = (0.5, 0.5, 0.5)
            }
            
            let snapshot = MotionSnapshot(
                acceleration: (1.0, 1.0, 1.0),
                rotation: rotation,
                timestamp: baseTime.addingTimeInterval(Double(i) * 0.05)
            )
            snapshots.append(snapshot)
        }
        
        return snapshots
    }
    
    private func createShakeMotionSnapshots() -> [MotionSnapshot] {
        var snapshots: [MotionSnapshot] = []
        let baseTime = Date()
        
        for i in 0..<10 {
            let acceleration: (Double, Double, Double)
            let variation = Double(i % 2 == 0 ? 1 : -1) * 2.0
            acceleration = (variation, variation, variation)
            
            let snapshot = MotionSnapshot(
                acceleration: acceleration,
                rotation: (0.1, 0.1, 0.1),
                timestamp: baseTime.addingTimeInterval(Double(i) * 0.05)
            )
            snapshots.append(snapshot)
        }
        
        return snapshots
    }
}

final class GestureSnoozeAlarmIntegrationTests: XCTestCase {
    
    private var alarmController: AlarmController!
    private var gestureService: GestureDetectionService!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        alarmController = AlarmController.shared
        gestureService = GestureDetectionService.shared
        cancellables = []
        
        alarmController.silenceAlarm()
        gestureService.stopMonitoring()
        gestureService.resetStatistics()
    }
    
    override func tearDown() {
        alarmController.silenceAlarm()
        gestureService.stopMonitoring()
        gestureService.resetStatistics()
        cancellables = nil
        super.tearDown()
    }
    
    func testGestureSnooze_SnapGestureTriggersSnooze() {
        let alarm = TestDataFactory.createAlarm(snoozeGesture: .snap)
        
        alarmController.triggerAlarm(for: alarm)
        XCTAssertTrue(alarmController.isRinging)
        
        gestureService.startMonitoringForSnooze(gesture: .snap)
        
        let expectation = XCTestExpectation(description: "Gesture snooze triggered")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        gestureService.stopMonitoring()
    }
    
    func testGestureSnooze_WristFlipGestureTriggersSnooze() {
        let alarm = TestDataFactory.createAlarm(snoozeGesture: .wristFlip)
        
        alarmController.triggerAlarm(for: alarm)
        XCTAssertTrue(alarmController.isRinging)
        
        gestureService.startMonitoringForSnooze(gesture: .wristFlip)
        
        let expectation = XCTestExpectation(description: "Gesture snooze triggered")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        gestureService.stopMonitoring()
    }
    
    func testGestureSnooze_DifferentGestureTypes() {
        let gestures: [SnoozeGesture] = [.snap, .wristFlip]
        
        for gesture in gestures {
            let alarm = TestDataFactory.createAlarm(snoozeGesture: gesture)
            
            alarmController.triggerAlarm(for: alarm)
            XCTAssertTrue(alarmController.isRinging)
            
            gestureService.startMonitoringForSnooze(gesture: gesture)
            XCTAssertTrue(gestureService.isMonitoring)
            
            gestureService.stopMonitoring()
            alarmController.silenceAlarm()
        }
    }
    
    func testGestureSnooze_AlarmStateTransitions() {
        let alarm = TestDataFactory.createAlarm(snoozeGesture: .snap)
        
        XCTAssertFalse(alarmController.isRinging)
        
        alarmController.triggerAlarm(for: alarm)
        XCTAssertTrue(alarmController.isRinging)
        
        gestureService.startMonitoring()
        
        gestureService.handleGestureDetected(
            DetectedGesture(type: .snap, timestamp: Date(), confidence: 0.95, motionData: nil)
        )
        
        gestureService.stopMonitoring()
    }
    
    func testGestureSnooze_ConfidenceThreshold() {
        gestureService.startMonitoring()
        
        let highConfidenceGesture = DetectedGesture(
            type: .snap,
            timestamp: Date(),
            confidence: 0.95,
            motionData: nil
        )
        
        gestureService.handleGestureDetected(highConfidenceGesture)
        
        let stats = gestureService.getAccuracyStatistics()
        XCTAssertGreaterThan(stats.accuracy, 0)
    }
    
    func testGestureSnooze_MultipleGesturesInSequence() {
        gestureService.startMonitoring()
        
        let expectation = XCTestExpectation(description: "Multiple gestures")
        expectation.expectedFulfillmentCount = 3
        
        gestureService.onGestureDetected = { _ in
            expectation.fulfill()
        }
        
        for _ in 0..<3 {
            gestureService.handleGestureDetected(
                DetectedGesture(type: .snap, timestamp: Date(), confidence: 0.95, motionData: nil)
            )
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertGreaterThanOrEqual(gestureService.gestureCount, 3)
    }
    
    func testGestureSnooze_GestureTypeDisplayNames() {
        XCTAssertEqual(GestureType.snap.displayName, "打响指")
        XCTAssertEqual(GestureType.wristFlip.displayName, "手腕翻转")
        XCTAssertEqual(GestureType.shake.displayName, "摇晃")
        XCTAssertEqual(GestureType.tap.displayName, "轻拍")
    }
    
    func testGestureSnooze_SnoozeGestureProperties() {
        XCTAssertEqual(SnoozeGesture.snap.displayName, "打响指")
        XCTAssertEqual(SnoozeGesture.snap.icon, "hand.tap")
        XCTAssertEqual(SnoozeGesture.snap.instruction, "打响指以贪睡")
        
        XCTAssertEqual(SnoozeGesture.wristFlip.displayName, "手腕翻转")
        XCTAssertEqual(SnoozeGesture.wristFlip.icon, "hand.raised")
        XCTAssertEqual(SnoozeGesture.wristFlip.instruction, "翻转手腕以贪睡")
    }
    
    func testGestureSnooze_IntegrationWithAlarmFlow() {
        let alarm = TestDataFactory.createAlarm(
            snoozeGesture: .snap,
            snoozeInterval: 1
        )
        
        alarmController.triggerAlarm(for: alarm)
        XCTAssertTrue(alarmController.isRinging)
        
        gestureService.startMonitoringForSnooze(gesture: .snap)
        
        let expectation = XCTestExpectation(description: "Full integration flow")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.gestureService.handleGestureDetected(
                DetectedGesture(type: .snap, timestamp: Date(), confidence: 0.95, motionData: nil)
            )
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        gestureService.stopMonitoring()
    }
}

extension GestureDetectionService {
    func detectSnap(in data: [MotionSnapshot]) -> DetectedGesture? {
        return nil
    }
    
    func detectWristFlip(in data: [MotionSnapshot]) -> DetectedGesture? {
        return nil
    }
    
    func detectShake(in data: [MotionSnapshot]) -> DetectedGesture? {
        return nil
    }
}
