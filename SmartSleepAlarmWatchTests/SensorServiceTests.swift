import XCTest
@testable import SmartSleepAlarmWatch

final class SensorDataTests: XCTestCase {
    
    func testSensorDataCreation() {
        let data = SensorData(
            timestamp: Date(),
            heartRate: 72.0,
            heartRateVariability: 45.0,
            accelerationX: 0.1,
            accelerationY: 0.2,
            accelerationZ: 0.98,
            rotationRateX: 0.01,
            rotationRateY: 0.02,
            rotationRateZ: 0.03
        )
        
        XCTAssertEqual(data.heartRate, 72.0)
        XCTAssertEqual(data.heartRateVariability, 45.0)
        XCTAssertEqual(data.accelerationX, 0.1)
        XCTAssertEqual(data.accelerationY, 0.2)
        XCTAssertEqual(data.accelerationZ, 0.98)
    }
    
    func testSensorDataHasHeartRate() {
        let withHeartRate = SensorData(
            timestamp: Date(),
            heartRate: 72.0,
            heartRateVariability: nil,
            accelerationX: nil,
            accelerationY: nil,
            accelerationZ: nil,
            rotationRateX: nil,
            rotationRateY: nil,
            rotationRateZ: nil
        )
        XCTAssertTrue(withHeartRate.hasHeartRate)
        
        let withoutHeartRate = SensorData(
            timestamp: Date(),
            heartRate: nil,
            heartRateVariability: nil,
            accelerationX: nil,
            accelerationY: nil,
            accelerationZ: nil,
            rotationRateX: nil,
            rotationRateY: nil,
            rotationRateZ: nil
        )
        XCTAssertFalse(withoutHeartRate.hasHeartRate)
    }
    
    func testSensorDataHasMotion() {
        let withMotion = SensorData(
            timestamp: Date(),
            heartRate: nil,
            heartRateVariability: nil,
            accelerationX: 0.1,
            accelerationY: 0.2,
            accelerationZ: 0.98,
            rotationRateX: nil,
            rotationRateY: nil,
            rotationRateZ: nil
        )
        XCTAssertTrue(withMotion.hasMotion)
        
        let withoutMotion = SensorData(
            timestamp: Date(),
            heartRate: 72.0,
            heartRateVariability: nil,
            accelerationX: nil,
            accelerationY: nil,
            accelerationZ: nil,
            rotationRateX: nil,
            rotationRateY: nil,
            rotationRateZ: nil
        )
        XCTAssertFalse(withoutMotion.hasMotion)
    }
    
    func testAccelerationMagnitude() {
        let data = SensorData(
            timestamp: Date(),
            heartRate: nil,
            heartRateVariability: nil,
            accelerationX: 3.0,
            accelerationY: 4.0,
            accelerationZ: 0.0,
            rotationRateX: nil,
            rotationRateY: nil,
            rotationRateZ: nil
        )
        
        XCTAssertEqual(data.accelerationMagnitude, 5.0, accuracy: 0.001)
    }
    
    func testAccelerationMagnitudeWithNilValues() {
        let data = SensorData(
            timestamp: Date(),
            heartRate: nil,
            heartRateVariability: nil,
            accelerationX: nil,
            accelerationY: nil,
            accelerationZ: nil,
            rotationRateX: nil,
            rotationRateY: nil,
            rotationRateZ: nil
        )
        
        XCTAssertNil(data.accelerationMagnitude)
    }
    
    func testAccelerationMagnitudeWithPartialNilValues() {
        let data = SensorData(
            timestamp: Date(),
            heartRate: nil,
            heartRateVariability: nil,
            accelerationX: 1.0,
            accelerationY: nil,
            accelerationZ: 1.0,
            rotationRateX: nil,
            rotationRateY: nil,
            rotationRateZ: nil
        )
        
        XCTAssertNil(data.accelerationMagnitude)
    }
}

final class SensorTypeTests: XCTestCase {
    
    func testAllSensorTypes() {
        XCTAssertEqual(SensorType.heartRate.displayName, "心率")
        XCTAssertEqual(SensorType.heartRateVariability.displayName, "心率变异性")
        XCTAssertEqual(SensorType.accelerometer.displayName, "加速度计")
        XCTAssertEqual(SensorType.gyroscope.displayName, "陀螺仪")
    }
}

final class SensorAvailabilityTests: XCTestCase {
    
    func testAvailabilityStates() {
        XCTAssertTrue(SensorAvailability.available.isUsable)
        XCTAssertTrue(SensorAvailability.degraded.isUsable)
        XCTAssertFalse(SensorAvailability.notAvailable.isUsable)
        XCTAssertFalse(SensorAvailability.permissionDenied.isUsable)
    }
}

final class SensorStatusTests: XCTestCase {
    
    func testSensorStatusCreation() {
        let status = SensorStatus(
            type: .heartRate,
            availability: .available,
            lastDataTime: Date(),
            consecutiveMisses: 0
        )
        
        XCTAssertEqual(status.type, .heartRate)
        XCTAssertEqual(status.availability, .available)
        XCTAssertNotNil(status.lastDataTime)
        XCTAssertEqual(status.consecutiveMisses, 0)
    }
    
    func testSensorStatusIsDataStale() {
        let freshStatus = SensorStatus(
            type: .heartRate,
            availability: .available,
            lastDataTime: Date(),
            consecutiveMisses: 0
        )
        XCTAssertFalse(freshStatus.isDataStale)
        
        let staleTime = Date().addingTimeInterval(-60)
        let staleStatus = SensorStatus(
            type: .heartRate,
            availability: .available,
            lastDataTime: staleTime,
            consecutiveMisses: 0
        )
        XCTAssertTrue(staleStatus.isDataStale)
    }
    
    func testSensorStatusWithNoDataTime() {
        let status = SensorStatus(
            type: .accelerometer,
            availability: .notAvailable,
            lastDataTime: nil,
            consecutiveMisses: 5
        )
        
        XCTAssertTrue(status.isDataStale)
    }
}

final class SensorServiceTests: XCTestCase {
    
    private var sut: SensorService!
    
    override func setUp() {
        super.setUp()
        sut = SensorService.shared
    }
    
    override func tearDown() {
        sut.stopMonitoring()
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(sut.isMonitoring)
        XCTAssertNil(sut.currentHeartRate)
        XCTAssertNil(sut.currentAcceleration)
        XCTAssertFalse(sut.degradedMode)
    }
    
    func testCheckAvailability() {
        let availabilities = sut.checkAvailability()
        
        XCTAssertNotNil(availabilities[.heartRate])
        XCTAssertNotNil(availabilities[.heartRateVariability])
        XCTAssertNotNil(availabilities[.accelerometer])
        XCTAssertNotNil(availabilities[.gyroscope])
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
    
    func testGetRecentDataEmpty() {
        let recentData = sut.getRecentData(count: 10)
        
        XCTAssertTrue(recentData.isEmpty)
    }
    
    func testGetAverageHeartRateEmpty() {
        let avgHeartRate = sut.getAverageHeartRate(forLast: 5)
        
        XCTAssertNil(avgHeartRate)
    }
    
    func testGetMotionActivityLevelEmpty() {
        let motionLevel = sut.getMotionActivityLevel(forLast: 5)
        
        XCTAssertNil(motionLevel)
    }
    
    func testGetDegradedSensorTypes() {
        let degradedTypes = sut.getDegradedSensorTypes()
        
        XCTAssertNotNil(degradedTypes)
    }
    
    func testGetAvailableSensorCount() {
        let count = sut.getAvailableSensorCount()
        
        XCTAssertGreaterThanOrEqual(count, 0)
    }
    
    func testSensorStatusesInitialized() {
        XCTAssertNotNil(sut.sensorStatuses[.heartRate])
        XCTAssertNotNil(sut.sensorStatuses[.heartRateVariability])
        XCTAssertNotNil(sut.sensorStatuses[.accelerometer])
        XCTAssertNotNil(sut.sensorStatuses[.gyroscope])
    }
    
    func testSensorDataCallback() {
        let expectation = XCTestExpectation(description: "Sensor data callback")
        
        sut.onSensorData = { data in
            expectation.fulfill()
        }
        
        sut.startMonitoring()
        
        wait(for: [expectation], timeout: 10.0)
    }
}
