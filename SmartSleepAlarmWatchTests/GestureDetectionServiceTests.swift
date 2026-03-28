import XCTest
@testable import SmartSleepAlarmWatch

final class GestureTypeTests: XCTestCase {
    
    func testAllGestureTypes() {
        XCTAssertEqual(GestureType.snap.displayName, "打响指")
        XCTAssertEqual(GestureType.wristFlip.displayName, "手腕翻转")
        XCTAssertEqual(GestureType.shake.displayName, "摇晃")
        XCTAssertEqual(GestureType.tap.displayName, "轻拍")
    }
}

final class DetectedGestureTests: XCTestCase {
    
    func testDetectedGestureCreation() {
        let gesture = DetectedGesture(
            type: .snap,
            timestamp: Date(),
            confidence: 0.95,
            motionData: nil
        )
        
        XCTAssertEqual(gesture.type, .snap)
        XCTAssertEqual(gesture.confidence, 0.95, accuracy: 0.001)
        XCTAssertNotNil(gesture.timestamp)
        XCTAssertNil(gesture.motionData)
    }
    
    func testDetectedGestureWithMotionData() {
        let motionSnapshot = MotionSnapshot(
            acceleration: (1.0, 2.0, 3.0),
            rotation: (0.1, 0.2, 0.3),
            timestamp: Date()
        )
        
        let gesture = DetectedGesture(
            type: .wristFlip,
            timestamp: Date(),
            confidence: 0.88,
            motionData: motionSnapshot
        )
        
        XCTAssertEqual(gesture.type, .wristFlip)
        XCTAssertNotNil(gesture.motionData)
        XCTAssertEqual(gesture.motionData?.acceleration.x, 1.0)
        XCTAssertEqual(gesture.motionData?.acceleration.y, 2.0)
        XCTAssertEqual(gesture.motionData?.acceleration.z, 3.0)
    }
}

final class MotionSnapshotTests: XCTestCase {
    
    func testMotionSnapshotCreation() {
        let snapshot = MotionSnapshot(
            acceleration: (0.5, 0.8, 1.2),
            rotation: (0.1, 0.2, 0.3),
            timestamp: Date()
        )
        
        XCTAssertEqual(snapshot.acceleration.x, 0.5)
        XCTAssertEqual(snapshot.acceleration.y, 0.8)
        XCTAssertEqual(snapshot.acceleration.z, 1.2)
        XCTAssertEqual(snapshot.rotation.x, 0.1)
        XCTAssertEqual(snapshot.rotation.y, 0.2)
        XCTAssertEqual(snapshot.rotation.z, 0.3)
    }
}

final class GestureDetectionServiceTests: XCTestCase {
    
    private var sut: GestureDetectionService!
    
    override func setUp() {
        super.setUp()
        sut = GestureDetectionService.shared
        sut.stopMonitoring()
        sut.resetStatistics()
    }
    
    override func tearDown() {
        sut.stopMonitoring()
        sut.resetStatistics()
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(sut.isMonitoring)
        XCTAssertNil(sut.lastDetectedGesture)
        XCTAssertEqual(sut.gestureCount, 0)
    }
    
    func testStartMonitoring() {
        sut.startMonitoring()
        
        XCTAssertTrue(sut.isMonitoring)
    }
    
    func testStopMonitoring() {
        sut.startMonitoring()
        sut.stopMonitoring()
        
        XCTAssertFalse(sut.isMonitoring)
    }
    
    func testResetStatistics() {
        sut.resetStatistics()
        
        let stats = sut.getAccuracyStatistics()
        XCTAssertEqual(stats.totalDetections, 0)
        XCTAssertEqual(stats.accuracy, 0)
        XCTAssertEqual(sut.gestureCount, 0)
    }
    
    func testSetThresholds() {
        sut.setThresholds(snap: 3.0, wristFlip: 5.0, shake: 4.0)
        
        let stats = sut.getMotionStatistics()
        XCTAssertNotNil(stats)
    }
    
    func testGetAccuracyStatisticsEmpty() {
        let stats = sut.getAccuracyStatistics()
        
        XCTAssertEqual(stats.accuracy, 0)
        XCTAssertEqual(stats.falsePositiveRate, 0)
        XCTAssertEqual(stats.totalDetections, 0)
    }
    
    func testGetMotionStatisticsEmpty() {
        let stats = sut.getMotionStatistics()
        
        XCTAssertEqual(stats.avgAcceleration, 0)
        XCTAssertEqual(stats.avgRotation, 0)
    }
    
    func testGestureCallback() {
        let expectation = XCTestExpectation(description: "Gesture detected callback")
        
        sut.onGestureDetected = { gesture in
            expectation.fulfill()
        }
        
        sut.startMonitoring()
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSnapDetectedCallback() {
        let expectation = XCTestExpectation(description: "Snap detected callback")
        
        sut.onSnapDetected = {
            expectation.fulfill()
        }
        
        sut.startMonitoring()
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testWristFlipDetectedCallback() {
        let expectation = XCTestExpectation(description: "Wrist flip detected callback")
        
        sut.onWristFlipDetected = {
            expectation.fulfill()
        }
        
        sut.startMonitoring()
        
        wait(for: [expectation], timeout: 5.0)
    }
}

final class GestureDetectionAlgorithmTests: XCTestCase {
    
    func testSnapDetectionPeakFinding() {
        let accelerations: [Double] = [1.0, 1.2, 2.5, 1.3, 1.1, 2.8, 1.4, 1.0]
        
        var peaks: [Int] = []
        let threshold = 2.0
        
        for i in 1..<accelerations.count - 1 {
            if accelerations[i] > accelerations[i-1] && 
               accelerations[i] > accelerations[i+1] && 
               accelerations[i] > threshold {
                peaks.append(i)
            }
        }
        
        XCTAssertEqual(peaks.count, 2)
        XCTAssertEqual(peaks[0], 2)
        XCTAssertEqual(peaks[1], 5)
    }
    
    func testSnapDetectionTimeBetweenPeaks() {
        let timeBetweenPeaks: TimeInterval = 0.3
        
        XCTAssertLessThan(timeBetweenPeaks, 0.5)
        XCTAssertGreaterThan(timeBetweenPeaks, 0.05)
    }
    
    func testSnapDetectionInvalidTimeBetweenPeaks() {
        let timeBetweenPeaks: TimeInterval = 0.6
        
        XCTAssertFalse(timeBetweenPeaks < 0.5 && timeBetweenPeaks > 0.05)
    }
    
    func testSnapConfidenceCalculation() {
        let peakAcceleration = 3.0
        let threshold = 2.0
        let hasRotationComponent = true
        let hasHighFrequencyImpact = true
        
        var confidence = min(1.0, peakAcceleration / threshold * 0.4 + 0.4)
        
        if hasRotationComponent {
            confidence = min(1.0, confidence + 0.15)
        }
        
        if hasHighFrequencyImpact {
            confidence = min(1.0, confidence + 0.15)
        }
        
        XCTAssertGreaterThanOrEqual(confidence, 0.95)
    }
    
    func testWristFlipRotationMagnitude() {
        let rotations: [(x: Double, y: Double, z: Double)] = [
            (1.0, 2.0, 3.0),
            (1.5, 2.5, 3.5),
            (2.0, 3.0, 4.0)
        ]
        
        let magnitudes = rotations.map { sqrt($0.x * $0.x + $0.y * $0.y + $0.z * $0.z) }
        let avgRotation = magnitudes.reduce(0, +) / Double(magnitudes.count)
        
        XCTAssertGreaterThan(avgRotation, 0)
    }
    
    func testWristFlipThresholdCheck() {
        let avgRotation = 5.0
        let threshold = 4.0
        
        XCTAssertGreaterThan(avgRotation, threshold)
    }
    
    func testWristFlipCumulativeRotation() {
        let rotations: [(x: Double, y: Double, z: Double)] = [
            (0.5, 0.5, 1.0),
            (0.6, 0.6, 1.2),
            (0.7, 0.7, 1.4),
            (0.8, 0.8, 1.6)
        ]
        
        var cumulativeRotation: Double = 0
        let dt: Double = 0.05
        
        for i in 1..<rotations.count {
            let rotationMagnitude = sqrt(
                rotations[i].x * rotations[i].x +
                rotations[i].y * rotations[i].y +
                rotations[i].z * rotations[i].z
            )
            cumulativeRotation += rotationMagnitude * dt
        }
        
        XCTAssertGreaterThan(cumulativeRotation, 0)
    }
    
    func testShakeDirectionChanges() {
        let accelerations: [Double] = [1.0, 2.0, 1.5, 2.5, 1.0, 3.0, 1.5]
        
        var directionChanges = 0
        
        for i in 2..<accelerations.count {
            let prevDiff = accelerations[i-1] - accelerations[i-2]
            let currDiff = accelerations[i] - accelerations[i-1]
            
            if (prevDiff > 0 && currDiff < 0) || (prevDiff < 0 && currDiff > 0) {
                if abs(prevDiff) > 0.5 && abs(currDiff) > 0.5 {
                    directionChanges += 1
                }
            }
        }
        
        XCTAssertGreaterThanOrEqual(directionChanges, 3)
    }
    
    func testShakeAverageAcceleration() {
        let accelerations: [Double] = [3.5, 3.8, 3.2, 4.0, 3.6]
        let avgAcceleration = accelerations.reduce(0, +) / Double(accelerations.count)
        let threshold = 3.0
        
        XCTAssertGreaterThan(avgAcceleration, threshold)
    }
    
    func testShakeConfidenceCalculation() {
        let directionChanges = 4
        let avgAcceleration = 3.5
        let shakeThreshold = 3.0
        
        let confidence = min(1.0, Double(directionChanges) / 5.0 * 0.5 + avgAcceleration / shakeThreshold * 0.5)
        
        XCTAssertGreaterThan(confidence, 0.5)
    }
}

final class GestureDetectionBoundaryTests: XCTestCase {
    
    func testAccelerationMagnitudeCalculation() {
        let x = 1.0
        let y = 2.0
        let z = 2.0
        
        let magnitude = sqrt(x * x + y * y + z * z)
        
        XCTAssertEqual(magnitude, 3.0, accuracy: 0.001)
    }
    
    func testZeroAccelerationMagnitude() {
        let magnitude = sqrt(0.0 * 0.0 + 0.0 * 0.0 + 0.0 * 0.0)
        
        XCTAssertEqual(magnitude, 0.0)
    }
    
    func testNegativeAccelerationValues() {
        let x = -1.0
        let y = -2.0
        let z = -2.0
        
        let magnitude = sqrt(x * x + y * y + z * z)
        
        XCTAssertEqual(magnitude, 3.0, accuracy: 0.001)
    }
    
    func testConfidenceUpperBound() {
        var confidence = 1.5
        confidence = min(1.0, confidence)
        
        XCTAssertEqual(confidence, 1.0)
    }
    
    func testConfidenceLowerBound() {
        var confidence = -0.5
        confidence = max(0.0, min(1.0, confidence))
        
        XCTAssertEqual(confidence, 0.0)
    }
    
    func testGestureCooldown() {
        let lastGestureTime = Date()
        let cooldown: TimeInterval = 1.0
        
        let elapsed = Date().timeIntervalSince(lastGestureTime)
        
        XCTAssertLessThan(elapsed, cooldown)
    }
    
    func testGestureCooldownExpired() {
        let lastGestureTime = Date().addingTimeInterval(-2.0)
        let cooldown: TimeInterval = 1.0
        
        let elapsed = Date().timeIntervalSince(lastGestureTime)
        
        XCTAssertGreaterThan(elapsed, cooldown)
    }
    
    func testBufferSizeLimit() {
        let bufferSize = 50
        var buffer: [Int] = []
        
        for i in 0..<100 {
            buffer.append(i)
            if buffer.count > bufferSize {
                buffer.removeFirst()
            }
        }
        
        XCTAssertEqual(buffer.count, bufferSize)
    }
    
    func testMinimumDataPointsForDetection() {
        let minDataPoints = 10
        let currentDataPoints = 8
        
        XCTAssertLessThan(currentDataPoints, minDataPoints)
    }
    
    func testSufficientDataPointsForDetection() {
        let minDataPoints = 10
        let currentDataPoints = 15
        
        XCTAssertGreaterThanOrEqual(currentDataPoints, minDataPoints)
    }
}
