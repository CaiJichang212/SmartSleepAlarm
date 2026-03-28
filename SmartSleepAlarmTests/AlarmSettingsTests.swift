import XCTest
@testable import SmartSleepAlarm

final class AlarmSettingsTests: XCTestCase {
    
    func testAlarmSettingsInitialization() {
        let targetTime = Date()
        let settings = AlarmSettings(targetWakeTime: targetTime)
        
        XCTAssertNotNil(settings.id)
        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.targetWakeTime, targetTime)
        XCTAssertEqual(settings.smartAlarmWindow, 30 * 60)
        XCTAssertEqual(settings.alarmSound, "default")
        XCTAssertTrue(settings.vibrationEnabled)
        XCTAssertTrue(settings.snoozeEnabled)
        XCTAssertEqual(settings.snoozeDuration, 5 * 60)
    }
    
    func testAlarmSettingsCustomValues() {
        let customId = UUID()
        let targetTime = Date()
        let settings = AlarmSettings(
            id: customId,
            isEnabled: false,
            targetWakeTime: targetTime,
            smartAlarmWindow: 45 * 60,
            alarmSound: "gentle",
            vibrationEnabled: false,
            snoozeEnabled: false,
            snoozeDuration: 10 * 60
        )
        
        XCTAssertEqual(settings.id, customId)
        XCTAssertFalse(settings.isEnabled)
        XCTAssertEqual(settings.smartAlarmWindow, 45 * 60)
        XCTAssertEqual(settings.alarmSound, "gentle")
        XCTAssertFalse(settings.vibrationEnabled)
        XCTAssertFalse(settings.snoozeEnabled)
        XCTAssertEqual(settings.snoozeDuration, 10 * 60)
    }
    
    func testSmartAlarmStartTime() {
        let targetTime = Date()
        let window: TimeInterval = 30 * 60
        let settings = AlarmSettings(targetWakeTime: targetTime, smartAlarmWindow: window)
        
        let expectedStartTime = targetTime.addingTimeInterval(-window)
        XCTAssertEqual(settings.smartAlarmStartTime, expectedStartTime)
    }
    
    func testSmartAlarmStartTimeWithDifferentWindows() {
        let targetTime = Date()
        
        let settings15Min = AlarmSettings(targetWakeTime: targetTime, smartAlarmWindow: 15 * 60)
        XCTAssertEqual(settings15Min.smartAlarmStartTime, targetTime.addingTimeInterval(-15 * 60))
        
        let settings60Min = AlarmSettings(targetWakeTime: targetTime, smartAlarmWindow: 60 * 60)
        XCTAssertEqual(settings60Min.smartAlarmStartTime, targetTime.addingTimeInterval(-60 * 60))
    }
    
    func testAlarmSettingsCodable() {
        let original = AlarmSettings(
            targetWakeTime: Date(),
            smartAlarmWindow: 45 * 60,
            alarmSound: "nature",
            vibrationEnabled: false,
            snoozeEnabled: true,
            snoozeDuration: 8 * 60
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(AlarmSettings.self, from: data)
            
            XCTAssertEqual(decoded.id, original.id)
            XCTAssertEqual(decoded.isEnabled, original.isEnabled)
            XCTAssertEqual(decoded.smartAlarmWindow, original.smartAlarmWindow)
            XCTAssertEqual(decoded.alarmSound, original.alarmSound)
            XCTAssertEqual(decoded.vibrationEnabled, original.vibrationEnabled)
            XCTAssertEqual(decoded.snoozeEnabled, original.snoozeEnabled)
            XCTAssertEqual(decoded.snoozeDuration, original.snoozeDuration)
        } catch {
            XCTFail("Coding failed: \(error)")
        }
    }
    
    func testAlarmSettingsIdentifiable() {
        let settings1 = AlarmSettings(targetWakeTime: Date())
        let settings2 = AlarmSettings(targetWakeTime: Date())
        
        XCTAssertNotEqual(settings1.id, settings2.id)
    }
}
