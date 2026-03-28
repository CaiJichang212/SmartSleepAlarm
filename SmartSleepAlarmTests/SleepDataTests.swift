import XCTest
@testable import SmartSleepAlarm

final class SleepDataTests: XCTestCase {
    
    func testSleepDataInitialization() {
        let startTime = Date().addingTimeInterval(-8 * 3600)
        let endTime = Date()
        let sleepData = SleepData(
            startTime: startTime,
            endTime: endTime,
            sleepQuality: 0.85,
            sleepPhase: .deep
        )
        
        XCTAssertNotNil(sleepData.id)
        XCTAssertEqual(sleepData.startTime, startTime)
        XCTAssertEqual(sleepData.endTime, endTime)
        XCTAssertEqual(sleepData.sleepQuality, 0.85)
        XCTAssertEqual(sleepData.sleepPhase, .deep)
    }
    
    func testSleepDataDuration() {
        let startTime = Date().addingTimeInterval(-8 * 3600)
        let endTime = Date()
        let sleepData = SleepData(
            startTime: startTime,
            endTime: endTime,
            sleepQuality: 0.8,
            sleepPhase: .light
        )
        
        let expectedDuration = endTime.timeIntervalSince(startTime)
        XCTAssertEqual(sleepData.duration, expectedDuration, accuracy: 0.001)
    }
    
    func testSleepDataDurationEightHours() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(8 * 3600)
        let sleepData = SleepData(
            startTime: startTime,
            endTime: endTime,
            sleepQuality: 0.9,
            sleepPhase: .rem
        )
        
        XCTAssertEqual(sleepData.duration, 8 * 3600, accuracy: 0.001)
    }
    
    func testSleepPhaseAllCases() {
        XCTAssertEqual(SleepPhase.allCases.count, 4)
        XCTAssertEqual(SleepPhase.awake.displayName, "清醒")
        XCTAssertEqual(SleepPhase.light.displayName, "浅睡")
        XCTAssertEqual(SleepPhase.deep.displayName, "深睡")
        XCTAssertEqual(SleepPhase.rem.displayName, "REM")
    }
    
    func testSleepPhaseIcons() {
        XCTAssertEqual(SleepPhase.awake.icon, "eye")
        XCTAssertEqual(SleepPhase.light.icon, "moon")
        XCTAssertEqual(SleepPhase.deep.icon, "bed.double")
        XCTAssertEqual(SleepPhase.rem.icon, "brain")
    }
    
    func testSleepDataCodable() {
        let original = SleepData(
            startTime: Date().addingTimeInterval(-36000),
            endTime: Date(),
            sleepQuality: 0.75,
            sleepPhase: .rem
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(SleepData.self, from: data)
            
            XCTAssertEqual(decoded.id, original.id)
            XCTAssertEqual(decoded.sleepQuality, original.sleepQuality, accuracy: 0.001)
            XCTAssertEqual(decoded.sleepPhase, original.sleepPhase)
        } catch {
            XCTFail("Coding failed: \(error)")
        }
    }
    
    func testSleepDataIdentifiable() {
        let sleepData1 = SleepData(
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            sleepQuality: 0.8,
            sleepPhase: .light
        )
        let sleepData2 = SleepData(
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            sleepQuality: 0.8,
            sleepPhase: .light
        )
        
        XCTAssertNotEqual(sleepData1.id, sleepData2.id)
    }
    
    func testSleepQualityBoundaryValues() {
        let minQuality = SleepData(
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            sleepQuality: 0.0,
            sleepPhase: .awake
        )
        XCTAssertEqual(minQuality.sleepQuality, 0.0)
        
        let maxQuality = SleepData(
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            sleepQuality: 1.0,
            sleepPhase: .deep
        )
        XCTAssertEqual(maxQuality.sleepQuality, 1.0)
    }
    
    func testZeroDurationSleepData() {
        let time = Date()
        let sleepData = SleepData(
            startTime: time,
            endTime: time,
            sleepQuality: 0.0,
            sleepPhase: .awake
        )
        
        XCTAssertEqual(sleepData.duration, 0)
    }
    
    func testNegativeDurationHandling() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(-3600)
        let sleepData = SleepData(
            startTime: startTime,
            endTime: endTime,
            sleepQuality: 0.5,
            sleepPhase: .light
        )
        
        XCTAssertLessThan(sleepData.duration, 0)
    }
}

final class SleepStateTests: XCTestCase {
    
    func testSleepStateAllCases() {
        XCTAssertEqual(SleepState.allCases.count, 3)
        XCTAssertEqual(SleepState.asleep.displayName, "睡眠")
        XCTAssertEqual(SleepState.awake.displayName, "清醒")
        XCTAssertEqual(SleepState.unknown.displayName, "未知")
    }
    
    func testSleepStateIcons() {
        XCTAssertEqual(SleepState.asleep.icon, "moon.zzz")
        XCTAssertEqual(SleepState.awake.icon, "sun.max")
        XCTAssertEqual(SleepState.unknown.icon, "questionmark.circle")
    }
    
    func testSleepStateColors() {
        XCTAssertEqual(SleepState.asleep.color, "blue")
        XCTAssertEqual(SleepState.awake.color, "orange")
        XCTAssertEqual(SleepState.unknown.color, "gray")
    }
    
    func testSleepStateCodable() {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for state in SleepState.allCases {
            do {
                let data = try encoder.encode(state)
                let decoded = try decoder.decode(SleepState.self, from: data)
                XCTAssertEqual(decoded, state)
            } catch {
                XCTFail("Coding failed for \(state): \(error)")
            }
        }
    }
}
