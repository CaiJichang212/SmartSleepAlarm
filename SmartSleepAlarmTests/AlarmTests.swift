import XCTest
@testable import SmartSleepAlarm

final class AlarmTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testAlarmInitialization() {
        let alarm = Alarm(time: Date())
        
        XCTAssertNotNil(alarm.id)
        XCTAssertEqual(alarm.repeatDays, [])
        XCTAssertEqual(alarm.ringtone, "default")
        XCTAssertEqual(alarm.label, "")
        XCTAssertTrue(alarm.isEnabled)
        XCTAssertFalse(alarm.isSmartModeEnabled)
        XCTAssertEqual(alarm.snoozeInterval, 5)
        XCTAssertEqual(alarm.snoozeGesture, .snap)
    }
    
    func testAlarmInitializationWithCustomValues() {
        let customId = UUID()
        let customTime = Date().addingTimeInterval(3600)
        let customRepeatDays = [1, 2, 3, 4, 5]
        let customRingtone = "gentle"
        let customLabel = "工作日闹铃"
        
        let alarm = Alarm(
            id: customId,
            time: customTime,
            repeatDays: customRepeatDays,
            ringtone: customRingtone,
            label: customLabel,
            isEnabled: false,
            isSmartModeEnabled: true,
            snoozeInterval: 10,
            snoozeGesture: .wristFlip
        )
        
        XCTAssertEqual(alarm.id, customId)
        XCTAssertEqual(alarm.time, customTime)
        XCTAssertEqual(alarm.repeatDays, customRepeatDays)
        XCTAssertEqual(alarm.ringtone, customRingtone)
        XCTAssertEqual(alarm.label, customLabel)
        XCTAssertFalse(alarm.isEnabled)
        XCTAssertTrue(alarm.isSmartModeEnabled)
        XCTAssertEqual(alarm.snoozeInterval, 10)
        XCTAssertEqual(alarm.snoozeGesture, .wristFlip)
    }
    
    func testSnoozeIntervalClamping() {
        let alarmBelowMin = Alarm(time: Date(), snoozeInterval: 0)
        XCTAssertEqual(alarmBelowMin.snoozeInterval, 1)
        
        let alarmAboveMax = Alarm(time: Date(), snoozeInterval: 50)
        XCTAssertEqual(alarmAboveMax.snoozeInterval, 30)
        
        let alarmValid = Alarm(time: Date(), snoozeInterval: 15)
        XCTAssertEqual(alarmValid.snoozeInterval, 15)
    }
    
    func testFormattedTime() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 7
        components.minute = 30
        
        let date = calendar.date(from: components)!
        let alarm = Alarm(time: date)
        
        let formatted = alarm.formattedTime
        XCTAssertTrue(formatted.contains("7"))
        XCTAssertTrue(formatted.contains("30"))
    }
    
    func testRepeatDaysDescriptionNever() {
        let alarm = Alarm(time: Date(), repeatDays: [])
        XCTAssertEqual(alarm.repeatDaysDescription, "永不")
    }
    
    func testRepeatDaysDescriptionEveryday() {
        let alarm = Alarm(time: Date(), repeatDays: [0, 1, 2, 3, 4, 5, 6])
        XCTAssertEqual(alarm.repeatDaysDescription, "每天")
    }
    
    func testRepeatDaysDescriptionWeekdays() {
        let alarm = Alarm(time: Date(), repeatDays: [1, 2, 3, 4, 5])
        XCTAssertEqual(alarm.repeatDaysDescription, "工作日")
    }
    
    func testRepeatDaysDescriptionWeekend() {
        let alarm = Alarm(time: Date(), repeatDays: [0, 6])
        XCTAssertEqual(alarm.repeatDaysDescription, "周末")
    }
    
    func testRepeatDaysDescriptionCustomDays() {
        let alarm = Alarm(time: Date(), repeatDays: [1, 3, 5])
        XCTAssertEqual(alarm.repeatDaysDescription, "一、三、五")
    }
    
    func testNextFireDateNoRepeat() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = calendar.component(.hour, from: Date()) + 2
        components.minute = 0
        components.second = 0
        
        let futureTime = calendar.date(from: components)!
        let alarm = Alarm(time: futureTime, repeatDays: [])
        
        let nextFire = alarm.nextFireDate
        XCTAssertNotNil(nextFire)
        
        if let fireDate = nextFire {
            XCTAssertTrue(fireDate > Date())
        }
    }
    
    func testNextFireDatePastTimeNoRepeat() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 1
        components.minute = 0
        
        let pastTime = calendar.date(from: components)!
        let alarm = Alarm(time: pastTime, repeatDays: [])
        
        let nextFire = alarm.nextFireDate
        XCTAssertNotNil(nextFire)
        
        if let fireDate = nextFire {
            XCTAssertTrue(fireDate > Date())
        }
    }
    
    func testNextFireDateWithRepeatDays() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 7
        components.minute = 0
        
        let time = calendar.date(from: components)!
        let alarm = Alarm(time: time, repeatDays: [1, 2, 3, 4, 5])
        
        let nextFire = alarm.nextFireDate
        XCTAssertNotNil(nextFire)
        
        if let fireDate = nextFire {
            let weekday = calendar.component(.weekday, from: fireDate)
            let weekdayIndex = weekday - 1
            XCTAssertTrue([1, 2, 3, 4, 5].contains(weekdayIndex))
        }
    }
    
    func testTimeUntilFire() {
        let calendar = Calendar.current
        let futureTime = calendar.date(byAdding: .hour, value: 2, to: Date())!
        let alarm = Alarm(time: futureTime, repeatDays: [])
        
        let timeUntil = alarm.timeUntilFire
        XCTAssertNotNil(timeUntil)
        XCTAssertTrue(timeUntil!.contains("小时") || timeUntil!.contains("分钟"))
    }
    
    func testTimeUntilFireDays() {
        let calendar = Calendar.current
        let futureTime = calendar.date(byAdding: .day, value: 2, to: Date())!
        let alarm = Alarm(time: futureTime, repeatDays: [])
        
        let timeUntil = alarm.timeUntilFire
        XCTAssertNotNil(timeUntil)
        XCTAssertTrue(timeUntil!.contains("天"))
    }
    
    func testTimeUntilFireMinutes() {
        let calendar = Calendar.current
        let futureTime = calendar.date(byAdding: .minute, value: 30, to: Date())!
        let alarm = Alarm(time: futureTime, repeatDays: [])
        
        let timeUntil = alarm.timeUntilFire
        XCTAssertNotNil(timeUntil)
        XCTAssertTrue(timeUntil!.contains("分钟"))
    }
    
    func testUpdateTimestamp() {
        let alarm = Alarm(time: Date())
        let originalUpdatedAt = alarm.updatedAt
        
        Thread.sleep(forTimeInterval: 0.1)
        alarm.updateTimestamp()
        
        XCTAssertTrue(alarm.updatedAt > originalUpdatedAt)
    }
    
    func testDefaultRingtones() {
        let ringtones = Alarm.defaultRingtones
        
        XCTAssertNotNil(ringtones["default"])
        XCTAssertNotNil(ringtones["gentle"])
        XCTAssertNotNil(ringtones["nature"])
        XCTAssertNotNil(ringtones["classic"])
        XCTAssertNotNil(ringtones["digital"])
    }
    
    func testAlarmEquality() {
        let id = UUID()
        let time = Date()
        
        let alarm1 = Alarm(id: id, time: time)
        let alarm2 = Alarm(id: id, time: time)
        
        XCTAssertEqual(alarm1.id, alarm2.id)
    }
    
    func testAlarmUniqueness() {
        let alarm1 = Alarm(time: Date())
        let alarm2 = Alarm(time: Date())
        
        XCTAssertNotEqual(alarm1.id, alarm2.id)
    }
    
    func testSnoozeGestureAllCases() {
        XCTAssertEqual(SnoozeGesture.allCases.count, 2)
        XCTAssertEqual(SnoozeGesture.snap.displayName, "打响指")
        XCTAssertEqual(SnoozeGesture.wristFlip.displayName, "手腕翻转")
    }
    
    func testSnoozeGestureIcon() {
        XCTAssertEqual(SnoozeGesture.snap.icon, "hand.tap")
        XCTAssertEqual(SnoozeGesture.wristFlip.icon, "hand.raised")
    }
    
    func testSnoozeGestureInstruction() {
        XCTAssertEqual(SnoozeGesture.snap.instruction, "打响指以贪睡")
        XCTAssertEqual(SnoozeGesture.wristFlip.instruction, "翻转手腕以贪睡")
    }
}
