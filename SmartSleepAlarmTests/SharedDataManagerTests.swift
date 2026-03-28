import XCTest
@testable import SmartSleepAlarm

final class SharedDataManagerTests: XCTestCase {
    
    private var sut: SharedDataManager!
    private let testSuiteName = "test.smartsleep.alarm"
    
    override func setUp() {
        super.setUp()
        sut = SharedDataManager.shared
    }
    
    override func tearDown() {
        sut.clearAllSyncData()
        super.tearDown()
    }
    
    func testSaveAndLoadCodable() {
        let testKey = "test_key"
        let testValue = "test_value_123"
        
        sut.save(testValue, forKey: testKey)
        
        let expectation = XCTestExpectation(description: "Save completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let loaded: String? = self.sut.load(String.self, forKey: testKey)
            XCTAssertEqual(loaded, testValue)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSaveAndLoadArray() {
        let testKey = "test_array_key"
        let testArray = [1, 2, 3, 4, 5]
        
        sut.save(testArray, forKey: testKey)
        
        let expectation = XCTestExpectation(description: "Save array completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let loaded: [Int]? = self.sut.load([Int].self, forKey: testKey)
            XCTAssertEqual(loaded, testArray)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testLoadNonExistentKey() {
        let loaded: String? = sut.load(String.self, forKey: "non_existent_key")
        XCTAssertNil(loaded)
    }
    
    func testRemoveValue() {
        let testKey = "key_to_remove"
        sut.save("value", forKey: testKey)
        
        let expectation = XCTestExpectation(description: "Save completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sut.remove(forKey: testKey)
            let loaded: String? = self.sut.load(String.self, forKey: testKey)
            XCTAssertNil(loaded)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testSyncAlarms() {
        let alarm1 = Alarm(
            time: Date(),
            repeatDays: [1, 2, 3, 4, 5],
            label: "工作日闹铃"
        )
        let alarm2 = Alarm(
            time: Date().addingTimeInterval(3600),
            repeatDays: [0, 6],
            label: "周末闹铃"
        )
        
        let alarms = [alarm1, alarm2]
        sut.syncAlarms(alarms)
        
        let expectation = XCTestExpectation(description: "Sync completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let syncedAlarms = self.sut.loadSyncedAlarms()
            XCTAssertNotNil(syncedAlarms)
            XCTAssertEqual(syncedAlarms?.count, 2)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testLoadSyncedAlarmsEmpty() {
        let syncedAlarms = sut.loadSyncedAlarms()
        XCTAssertNil(syncedAlarms)
    }
    
    func testGetLastSyncTime() {
        XCTAssertNil(sut.getLastSyncTime())
        
        let alarm = Alarm(time: Date())
        sut.syncAlarms([alarm])
        
        let expectation = XCTestExpectation(description: "Sync completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let syncTime = self.sut.getLastSyncTime()
            XCTAssertNotNil(syncTime)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testAddPendingChange() {
        let alarm = Alarm(time: Date(), label: "测试闹铃")
        let change = AlarmChange(type: .add, alarm: alarm)
        
        sut.addPendingChange(change)
        
        let expectation = XCTestExpectation(description: "Add pending change completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let pendingChanges = self.sut.loadPendingChanges()
            XCTAssertNotNil(pendingChanges)
            XCTAssertEqual(pendingChanges?.count, 1)
            XCTAssertEqual(pendingChanges?.first?.type, .add)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testMultiplePendingChanges() {
        let alarm1 = Alarm(time: Date(), label: "闹铃1")
        let alarm2 = Alarm(time: Date().addingTimeInterval(3600), label: "闹铃2")
        
        sut.addPendingChange(AlarmChange(type: .add, alarm: alarm1))
        sut.addPendingChange(AlarmChange(type: .update, alarm: alarm2))
        sut.addPendingChange(AlarmChange(deleteAlarmId: UUID()))
        
        let expectation = XCTestExpectation(description: "Multiple changes complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let pendingChanges = self.sut.loadPendingChanges()
            XCTAssertEqual(pendingChanges?.count, 3)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testClearPendingChanges() {
        let alarm = Alarm(time: Date())
        sut.addPendingChange(AlarmChange(type: .add, alarm: alarm))
        
        let expectation = XCTestExpectation(description: "Clear completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sut.clearPendingChanges()
            let pendingChanges = self.sut.loadPendingChanges()
            XCTAssertNil(pendingChanges)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testClearAllSyncData() {
        let alarm = Alarm(time: Date())
        sut.syncAlarms([alarm])
        sut.addPendingChange(AlarmChange(type: .add, alarm: alarm))
        
        let expectation = XCTestExpectation(description: "Clear all completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.sut.clearAllSyncData()
            
            XCTAssertNil(self.sut.loadSyncedAlarms())
            XCTAssertNil(self.sut.getLastSyncTime())
            XCTAssertNil(self.sut.loadPendingChanges())
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
}

final class AlarmSyncDataTests: XCTestCase {
    
    func testAlarmSyncDataCreation() {
        let alarm = Alarm(
            time: Date(),
            repeatDays: [1, 2, 3],
            ringtone: "gentle",
            label: "测试",
            isEnabled: true,
            isSmartModeEnabled: true,
            snoozeInterval: 10,
            snoozeGesture: .wristFlip
        )
        
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
        
        XCTAssertEqual(syncData.id, alarm.id)
        XCTAssertEqual(syncData.time, alarm.time)
        XCTAssertEqual(syncData.repeatDays, alarm.repeatDays)
        XCTAssertEqual(syncData.ringtone, alarm.ringtone)
        XCTAssertEqual(syncData.label, alarm.label)
        XCTAssertEqual(syncData.isEnabled, alarm.isEnabled)
        XCTAssertEqual(syncData.isSmartModeEnabled, alarm.isSmartModeEnabled)
        XCTAssertEqual(syncData.snoozeInterval, alarm.snoozeInterval)
        XCTAssertEqual(syncData.snoozeGesture, alarm.snoozeGesture)
    }
    
    func testAlarmSyncDataToAlarm() {
        let originalAlarm = Alarm(
            time: Date(),
            repeatDays: [0, 6],
            ringtone: "nature",
            label: "周末闹铃",
            snoozeGesture: .wristFlip
        )
        
        let syncData = AlarmSyncData(
            id: originalAlarm.id,
            time: originalAlarm.time,
            repeatDays: originalAlarm.repeatDays,
            ringtone: originalAlarm.ringtone,
            label: originalAlarm.label,
            isEnabled: originalAlarm.isEnabled,
            isSmartModeEnabled: originalAlarm.isSmartModeEnabled,
            snoozeInterval: originalAlarm.snoozeInterval,
            snoozeGesture: originalAlarm.snoozeGesture,
            createdAt: originalAlarm.createdAt,
            updatedAt: originalAlarm.updatedAt
        )
        
        let convertedAlarm = syncData.toAlarm()
        
        XCTAssertEqual(convertedAlarm.id, originalAlarm.id)
        XCTAssertEqual(convertedAlarm.time, originalAlarm.time)
        XCTAssertEqual(convertedAlarm.repeatDays, originalAlarm.repeatDays)
        XCTAssertEqual(convertedAlarm.ringtone, originalAlarm.ringtone)
        XCTAssertEqual(convertedAlarm.label, originalAlarm.label)
        XCTAssertEqual(convertedAlarm.isEnabled, originalAlarm.isEnabled)
        XCTAssertEqual(convertedAlarm.isSmartModeEnabled, originalAlarm.isSmartModeEnabled)
        XCTAssertEqual(convertedAlarm.snoozeInterval, originalAlarm.snoozeInterval)
        XCTAssertEqual(convertedAlarm.snoozeGesture, originalAlarm.snoozeGesture)
    }
    
    func testAlarmSyncDataCodable() {
        let syncData = AlarmSyncData(
            id: UUID(),
            time: Date(),
            repeatDays: [1, 3, 5],
            ringtone: "classic",
            label: "测试闹铃",
            isEnabled: true,
            isSmartModeEnabled: false,
            snoozeInterval: 15,
            snoozeGesture: .snap,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(syncData)
            let decoded = try decoder.decode(AlarmSyncData.self, from: data)
            
            XCTAssertEqual(decoded.id, syncData.id)
            XCTAssertEqual(decoded.repeatDays, syncData.repeatDays)
            XCTAssertEqual(decoded.ringtone, syncData.ringtone)
            XCTAssertEqual(decoded.label, syncData.label)
            XCTAssertEqual(decoded.snoozeGesture, syncData.snoozeGesture)
        } catch {
            XCTFail("Coding failed: \(error)")
        }
    }
}

final class AlarmChangeTests: XCTestCase {
    
    func testAlarmChangeAdd() {
        let alarm = Alarm(time: Date(), label: "添加测试")
        let change = AlarmChange(type: .add, alarm: alarm)
        
        XCTAssertEqual(change.type, .add)
        XCTAssertEqual(change.id, alarm.id)
        XCTAssertNotNil(change.alarmData)
    }
    
    func testAlarmChangeUpdate() {
        let alarm = Alarm(time: Date(), label: "更新测试")
        let change = AlarmChange(type: .update, alarm: alarm)
        
        XCTAssertEqual(change.type, .update)
        XCTAssertEqual(change.id, alarm.id)
        XCTAssertNotNil(change.alarmData)
    }
    
    func testAlarmChangeDelete() {
        let alarmId = UUID()
        let change = AlarmChange(deleteAlarmId: alarmId)
        
        XCTAssertEqual(change.type, .delete)
        XCTAssertEqual(change.id, alarmId)
        XCTAssertNil(change.alarmData)
    }
    
    func testAlarmChangeTimestamp() {
        let beforeCreate = Date()
        let alarm = Alarm(time: Date())
        let change = AlarmChange(type: .add, alarm: alarm)
        let afterCreate = Date()
        
        XCTAssertTrue(change.timestamp >= beforeCreate)
        XCTAssertTrue(change.timestamp <= afterCreate)
    }
    
    func testAlarmChangeCodable() {
        let alarm = Alarm(time: Date(), label: "编码测试")
        let original = AlarmChange(type: .update, alarm: alarm)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(AlarmChange.self, from: data)
            
            XCTAssertEqual(decoded.id, original.id)
            XCTAssertEqual(decoded.type, original.type)
            XCTAssertEqual(decoded.alarmData?.label, original.alarmData?.label)
        } catch {
            XCTFail("Coding failed: \(error)")
        }
    }
}

final class AlarmChangeTypeTests: XCTestCase {
    
    func testAllCases() {
        XCTAssertEqual(AlarmChangeType.allCases.count, 3)
        XCTAssertEqual(AlarmChangeType.add.rawValue, "add")
        XCTAssertEqual(AlarmChangeType.update.rawValue, "update")
        XCTAssertEqual(AlarmChangeType.delete.rawValue, "delete")
    }
}
