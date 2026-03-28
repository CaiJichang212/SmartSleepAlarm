import XCTest
@testable import SmartSleepAlarm
@testable import SmartSleepAlarmWatch

final class BoundaryConditionTests: XCTestCase {
    
    func testAlarmSnoozeIntervalBoundaryMin() {
        let alarm = Alarm(time: Date(), snoozeInterval: -10)
        XCTAssertEqual(alarm.snoozeInterval, 1)
    }
    
    func testAlarmSnoozeIntervalBoundaryMax() {
        let alarm = Alarm(time: Date(), snoozeInterval: 100)
        XCTAssertEqual(alarm.snoozeInterval, 30)
    }
    
    func testAlarmSnoozeIntervalBoundaryValid() {
        let alarm = Alarm(time: Date(), snoozeInterval: 15)
        XCTAssertEqual(alarm.snoozeInterval, 15)
    }
    
    func testSleepQualityBoundaryMin() {
        let sleepData = SleepData(
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            sleepQuality: 0.0,
            sleepPhase: .awake
        )
        XCTAssertEqual(sleepData.sleepQuality, 0.0)
    }
    
    func testSleepQualityBoundaryMax() {
        let sleepData = SleepData(
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            sleepQuality: 1.0,
            sleepPhase: .deep
        )
        XCTAssertEqual(sleepData.sleepQuality, 1.0)
    }
    
    func testSleepQualityBoundaryExceeded() {
        let sleepData = SleepData(
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            sleepQuality: 1.5,
            sleepPhase: .deep
        )
        XCTAssertGreaterThan(sleepData.sleepQuality, 1.0)
    }
    
    func testConfidenceBoundaryMin() {
        let signal = AwakeSignal(
            timestamp: Date(),
            type: .heartRateIncrease,
            confidence: 0.0,
            rawValue: 60.0,
            threshold: 70.0
        )
        XCTAssertFalse(signal.isSignificant)
    }
    
    func testConfidenceBoundaryMax() {
        let signal = AwakeSignal(
            timestamp: Date(),
            type: .heartRateIncrease,
            confidence: 1.0,
            rawValue: 80.0,
            threshold: 70.0
        )
        XCTAssertTrue(signal.isSignificant)
    }
    
    func testConfidenceSignificanceThreshold() {
        let signal = AwakeSignal(
            timestamp: Date(),
            type: .heartRateIncrease,
            confidence: 0.5,
            rawValue: 70.0,
            threshold: 70.0
        )
        XCTAssertTrue(signal.isSignificant)
    }
    
    func testConfidenceBelowSignificanceThreshold() {
        let signal = AwakeSignal(
            timestamp: Date(),
            type: .heartRateIncrease,
            confidence: 0.49,
            rawValue: 69.0,
            threshold: 70.0
        )
        XCTAssertFalse(signal.isSignificant)
    }
    
    func testHeartRateThresholdBoundary() {
        let config = AwakeDetectionConfig.default
        let baselineHR = 60.0
        let thresholdHR = baselineHR * (1 + config.heartRateThresholdPercentage)
        
        XCTAssertEqual(thresholdHR, 66.0, accuracy: 0.1)
    }
    
    func testMotionThresholdBoundary() {
        let config = AwakeDetectionConfig.default
        
        XCTAssertGreaterThan(config.motionThresholdStdDev, 0)
        XCTAssertLessThan(config.motionThresholdStdDev, 1)
    }
    
    func testSmartAlarmWindowBoundary() {
        let settings = AlarmSettings(targetWakeTime: Date(), smartAlarmWindow: 0)
        
        XCTAssertEqual(settings.smartAlarmStartTime, settings.targetWakeTime)
    }
    
    func testSmartAlarmWindowNegative() {
        let settings = AlarmSettings(targetWakeTime: Date(), smartAlarmWindow: -100)
        
        XCTAssertGreaterThan(settings.smartAlarmStartTime, settings.targetWakeTime)
    }
    
    func testEmptyRepeatDays() {
        let alarm = Alarm(time: Date(), repeatDays: [])
        XCTAssertEqual(alarm.repeatDaysDescription, "永不")
    }
    
    func testFullWeekRepeatDays() {
        let alarm = Alarm(time: Date(), repeatDays: [0, 1, 2, 3, 4, 5, 6])
        XCTAssertEqual(alarm.repeatDaysDescription, "每天")
    }
    
    func testDuplicateRepeatDays() {
        let alarm = Alarm(time: Date(), repeatDays: [1, 1, 2, 2, 3])
        XCTAssertNotNil(alarm.repeatDaysDescription)
    }
    
    func testInvalidRepeatDays() {
        let alarm = Alarm(time: Date(), repeatDays: [-1, 7, 8])
        XCTAssertNotNil(alarm.repeatDaysDescription)
    }
}

final class ExceptionHandlingTests: XCTestCase {
    
    func testInvalidJSONDecoding() {
        let invalidData = "invalid json data".data(using: .utf8)!
        let decoder = JSONDecoder()
        
        do {
            _ = try decoder.decode(AlarmSettings.self, from: invalidData)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(true)
        }
    }
    
    func testEmptyJSONDecoding() {
        let emptyData = Data()
        let decoder = JSONDecoder()
        
        do {
            _ = try decoder.decode(AlarmSettings.self, from: emptyData)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(true)
        }
    }
    
    func testNilDataDecoding() {
        let data: Data? = nil
        
        if let data = data {
            let decoder = JSONDecoder()
            do {
                _ = try decoder.decode(AlarmSettings.self, from: data)
            } catch {
                XCTAssertTrue(true)
            }
        } else {
            XCTAssertTrue(true)
        }
    }
    
    func testEmptyArraySync() {
        let manager = SharedDataManager.shared
        manager.syncAlarms([])
        
        let expectation = XCTestExpectation(description: "Sync completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let syncedAlarms = manager.loadSyncedAlarms()
            XCTAssertNotNil(syncedAlarms)
            XCTAssertEqual(syncedAlarms?.count, 0)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testLargeDataSync() {
        var alarms: [Alarm] = []
        for i in 0..<100 {
            alarms.append(Alarm(time: Date().addingTimeInterval(Double(i) * 60), label: "闹铃\(i)"))
        }
        
        let manager = SharedDataManager.shared
        manager.syncAlarms(alarms)
        
        let expectation = XCTestExpectation(description: "Large sync completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let syncedAlarms = manager.loadSyncedAlarms()
            XCTAssertNotNil(syncedAlarms)
            XCTAssertEqual(syncedAlarms?.count, 100)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testZeroDurationSleepData() {
        let time = Date()
        let sleepData = SleepData(
            startTime: time,
            endTime: time,
            sleepQuality: 0.5,
            sleepPhase: .light
        )
        
        XCTAssertEqual(sleepData.duration, 0)
    }
    
    func testNegativeDurationSleepData() {
        let sleepData = SleepData(
            startTime: Date(),
            endTime: Date().addingTimeInterval(-3600),
            sleepQuality: 0.5,
            sleepPhase: .light
        )
        
        XCTAssertLessThan(sleepData.duration, 0)
    }
    
    func testVeryLongLabel() {
        let longLabel = String(repeating: "测试", count: 1000)
        let alarm = Alarm(time: Date(), label: longLabel)
        
        XCTAssertEqual(alarm.label, longLabel)
    }
    
    func testEmptyLabel() {
        let alarm = Alarm(time: Date(), label: "")
        XCTAssertEqual(alarm.label, "")
    }
    
    func testSpecialCharactersInLabel() {
        let specialLabel = "闹铃🎉\n\t\"测试\""
        let alarm = Alarm(time: Date(), label: specialLabel)
        
        XCTAssertEqual(alarm.label, specialLabel)
    }
    
    func testUnicodeInLabel() {
        let unicodeLabel = "闹铃 🔔 朝闹鐘"
        let alarm = Alarm(time: Date(), label: unicodeLabel)
        
        XCTAssertEqual(alarm.label, unicodeLabel)
    }
    
    func testDateInFarFuture() {
        let farFuture = Date().addingTimeInterval(365 * 24 * 3600 * 10)
        let alarm = Alarm(time: farFuture)
        
        XCTAssertNotNil(alarm.nextFireDate)
    }
    
    func testDateInFarPast() {
        let farPast = Date().addingTimeInterval(-365 * 24 * 3600 * 10)
        let alarm = Alarm(time: farPast)
        
        XCTAssertNotNil(alarm.nextFireDate)
    }
}

final class EdgeCaseTests: XCTestCase {
    
    func testMidnightAlarm() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 0
        components.minute = 0
        
        let midnight = calendar.date(from: components)!
        let alarm = Alarm(time: midnight)
        
        XCTAssertEqual(alarm.formattedTime.contains("0") || alarm.formattedTime.contains("12"), true)
    }
    
    func testNoonAlarm() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        components.minute = 0
        
        let noon = calendar.date(from: components)!
        let alarm = Alarm(time: noon)
        
        XCTAssertNotNil(alarm.formattedTime)
    }
    
    func testLeapYearAlarm() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 2
        components.day = 29
        components.hour = 7
        components.minute = 30
        
        if let leapDay = calendar.date(from: components) {
            let alarm = Alarm(time: leapDay)
            XCTAssertNotNil(alarm.nextFireDate)
        }
    }
    
    func testDaylightSavingTimeTransition() {
        let calendar = Calendar.current
        
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 10
        components.hour = 2
        components.minute = 0
        
        if let dstDate = calendar.date(from: components) {
            let alarm = Alarm(time: dstDate)
            XCTAssertNotNil(alarm.nextFireDate)
        }
    }
    
    func testAllRingtones() {
        for (key, _) in Alarm.defaultRingtones {
            let alarm = Alarm(time: Date(), ringtone: key)
            XCTAssertEqual(alarm.ringtone, key)
        }
    }
    
    func testAllSnoozeGestures() {
        for gesture in SnoozeGesture.allCases {
            let alarm = Alarm(time: Date(), snoozeGesture: gesture)
            XCTAssertEqual(alarm.snoozeGesture, gesture)
        }
    }
    
    func testAllSleepPhases() {
        for phase in SleepPhase.allCases {
            let sleepData = SleepData(
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600),
                sleepQuality: 0.5,
                sleepPhase: phase
            )
            XCTAssertEqual(sleepData.sleepPhase, phase)
        }
    }
    
    func testAllSleepStates() {
        for state in SleepState.allCases {
            XCTAssertNotNil(state.displayName)
            XCTAssertNotNil(state.icon)
            XCTAssertNotNil(state.color)
        }
    }
    
    func testAllAlarmSyncStates() {
        for state in AlarmSyncState.allCases {
            XCTAssertNotNil(state.rawValue)
        }
    }
    
    func testAllWatchMessageTypes() {
        for type in WatchMessageType.allCases {
            let message = WatchMessage(type: type)
            XCTAssertEqual(message.type, type)
        }
    }
    
    func testAllSyncReasons() {
        for reason in SyncReason.allCases {
            XCTAssertNotNil(reason.rawValue)
        }
    }
    
    func testAllAlarmChangeTypes() {
        for changeType in AlarmChangeType.allCases {
            XCTAssertNotNil(changeType.rawValue)
        }
    }
    
    func testAllAwakeDetectionModes() {
        for mode in AwakeDetectionMode.allCases {
            XCTAssertNotNil(mode.config)
        }
    }
    
    func testAllAwakeSignalTypes() {
        for signalType in AwakeSignalType.allCases {
            XCTAssertNotNil(signalType.displayName)
        }
    }
    
    func testAllGestureTypes() {
        for gestureType in [GestureType.snap, .wristFlip, .shake, .tap] {
            XCTAssertNotNil(gestureType.displayName)
        }
    }
}

final class PerformanceTests: XCTestCase {
    
    func testAlarmCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = Alarm(time: Date())
            }
        }
    }
    
    func testAlarmSyncDataEncodingPerformance() {
        let alarm = Alarm(time: Date())
        let syncData = AlarmSyncData(
            id: alarm.id,
            time: alarm.time,
            repeatDays: alarm.repeatDays,
            ringtone: alarm.ringtone,
            label: alarm.label,
            isEnabled: alarm.isEnabled,
            isSmartModeEnabled: alarm.isSmartModeEnabled,
            snoozeInterval: alarm.snoozeInterval,
            snoozeGesture: alarm.snoozeGesture,
            createdAt: alarm.createdAt,
            updatedAt: alarm.updatedAt
        )
        
        let encoder = JSONEncoder()
        
        measure {
            for _ in 0..<1000 {
                _ = try? encoder.encode(syncData)
            }
        }
    }
    
    func testAlarmSyncDataDecodingPerformance() {
        let alarm = Alarm(time: Date())
        let syncData = AlarmSyncData(
            id: alarm.id,
            time: alarm.time,
            repeatDays: alarm.repeatDays,
            ringtone: alarm.ringtone,
            label: alarm.label,
            isEnabled: alarm.isEnabled,
            isSmartModeEnabled: alarm.isSmartModeEnabled,
            snoozeInterval: alarm.snoozeInterval,
            snoozeGesture: alarm.snoozeGesture,
            createdAt: alarm.createdAt,
            updatedAt: alarm.updatedAt
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        guard let data = try? encoder.encode(syncData) else {
            XCTFail("Encoding failed")
            return
        }
        
        measure {
            for _ in 0..<1000 {
                _ = try? decoder.decode(AlarmSyncData.self, from: data)
            }
        }
    }
    
    func testNextFireDateCalculationPerformance() {
        let alarm = Alarm(time: Date(), repeatDays: [1, 2, 3, 4, 5])
        
        measure {
            for _ in 0..<1000 {
                _ = alarm.nextFireDate
            }
        }
    }
    
    func testConfidenceCalculationPerformance() {
        var signals: [AwakeSignal] = []
        for i in 0..<100 {
            signals.append(AwakeSignal(
                timestamp: Date(),
                type: i % 2 == 0 ? .heartRateIncrease : .motionActivity,
                confidence: Double.random(in: 0...1),
                rawValue: Double.random(in: 0...100),
                threshold: 50.0
            ))
        }
        
        measure {
            for _ in 0..<1000 {
                let significantSignals = signals.filter { $0.isSignificant }
                _ = Double(significantSignals.count) / Double(signals.count)
            }
        }
    }
}
