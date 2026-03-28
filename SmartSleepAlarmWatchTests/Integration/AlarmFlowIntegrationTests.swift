import XCTest
import Combine
@testable import SmartSleepAlarmWatch

final class AlarmFlowIntegrationTests: XCTestCase {
    
    private var alarmController: AlarmController!
    private var alarmPlayer: AlarmPlayer!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        alarmController = AlarmController.shared
        alarmPlayer = AlarmPlayer.shared
        cancellables = []
        
        alarmController.silenceAlarm()
        alarmPlayer.stopAlarm()
    }
    
    override func tearDown() {
        alarmController.silenceAlarm()
        alarmPlayer.stopAlarm()
        cancellables = nil
        super.tearDown()
    }
    
    func testCompleteAlarmFlow_CreateRingSilence() {
        let alarm = TestDataFactory.createAlarm(
            time: Date(),
            label: "Integration Test Alarm"
        )
        
        XCTAssertFalse(alarmController.isRinging)
        XCTAssertNil(alarmController.currentAlarm)
        
        alarmController.triggerAlarm(for: alarm)
        
        XCTAssertTrue(alarmController.isRinging)
        XCTAssertEqual(alarmController.currentAlarm?.id, alarm.id)
        
        alarmController.silenceAlarm()
        
        XCTAssertFalse(alarmController.isRinging)
        XCTAssertNil(alarmController.currentAlarm)
    }
    
    func testAlarmFlow_WithSmartModeEnabled() {
        let alarm = TestDataFactory.createAlarm(
            time: Date(),
            isSmartModeEnabled: true,
            label: "Smart Alarm"
        )
        
        XCTAssertTrue(alarm.isSmartModeEnabled)
        
        alarmController.triggerAlarm(for: alarm)
        
        XCTAssertTrue(alarmController.isRinging)
        XCTAssertEqual(alarmController.currentAlarm?.isSmartModeEnabled, true)
        
        alarmController.silenceAlarm()
        
        XCTAssertFalse(alarmController.isRinging)
    }
    
    func testAlarmFlow_MultipleAlarmsInSequence() {
        let alarm1 = TestDataFactory.createAlarm(label: "First Alarm")
        let alarm2 = TestDataFactory.createAlarm(label: "Second Alarm")
        
        alarmController.triggerAlarm(for: alarm1)
        XCTAssertTrue(alarmController.isRinging)
        XCTAssertEqual(alarmController.currentAlarm?.id, alarm1.id)
        
        alarmController.silenceAlarm()
        XCTAssertFalse(alarmController.isRinging)
        
        alarmController.triggerAlarm(for: alarm2)
        XCTAssertTrue(alarmController.isRinging)
        XCTAssertEqual(alarmController.currentAlarm?.id, alarm2.id)
        
        alarmController.silenceAlarm()
        XCTAssertFalse(alarmController.isRinging)
    }
    
    func testAlarmFlow_CallbacksTriggered() {
        let alarm = TestDataFactory.createAlarm()
        
        var triggeredAlarm: Alarm?
        var silencedAlarm: Alarm?
        var silencedTime: Date?
        
        let triggerExpectation = XCTestExpectation(description: "Alarm triggered")
        let silenceExpectation = XCTestExpectation(description: "Alarm silenced")
        
        alarmController.onAlarmTriggered = { alarm in
            triggeredAlarm = alarm
            triggerExpectation.fulfill()
        }
        
        alarmController.onAlarmSilenced = { alarm, time in
            silencedAlarm = alarm
            silencedTime = time
            silenceExpectation.fulfill()
        }
        
        alarmController.triggerAlarm(for: alarm)
        wait(for: [triggerExpectation], timeout: 1.0)
        
        alarmController.silenceAlarm()
        wait(for: [silenceExpectation], timeout: 1.0)
        
        XCTAssertNotNil(triggeredAlarm)
        XCTAssertEqual(triggeredAlarm?.id, alarm.id)
        XCTAssertNotNil(silencedAlarm)
        XCTAssertNotNil(silencedTime)
    }
    
    func testAlarmFlow_RingDurationTracking() {
        let alarm = TestDataFactory.createAlarm()
        
        alarmController.triggerAlarm(for: alarm)
        
        let expectation = XCTestExpectation(description: "Ring duration check")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let duration = self.alarmController.getRingDuration()
            XCTAssertNotNil(duration)
            XCTAssertGreaterThanOrEqual(duration!, 0.4)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        alarmController.silenceAlarm()
        
        XCTAssertNil(alarmController.getRingDuration())
    }
    
    func testAlarmFlow_PreventDoubleTrigger() {
        let alarm = TestDataFactory.createAlarm()
        
        alarmController.triggerAlarm(for: alarm)
        XCTAssertTrue(alarmController.isRinging)
        
        let firstTriggerTime = alarmController.ringStartTime
        
        alarmController.triggerAlarm(for: alarm)
        
        XCTAssertEqual(alarmController.ringStartTime, firstTriggerTime)
        
        alarmController.silenceAlarm()
    }
    
    func testAlarmFlow_SnoozeFunctionality() {
        let alarm = TestDataFactory.createAlarm(snoozeInterval: 1)
        
        alarmController.triggerAlarm(for: alarm)
        XCTAssertTrue(alarmController.isRinging)
        
        alarmController.snoozeAlarm(duration: 1.0)
        XCTAssertFalse(alarmController.isRinging)
        
        let expectation = XCTestExpectation(description: "Snooze re-trigger")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testAlarmFlow_VolumeControl() {
        let alarm = TestDataFactory.createAlarm()
        
        alarmController.triggerAlarm(for: alarm)
        
        alarmController.setVolume(0.5)
        
        alarmController.setVolume(1.0)
        
        alarmController.setVolume(0.0)
        
        alarmController.silenceAlarm()
    }
    
    func testAlarmFlow_MaxDurationHandler() {
        let alarm = TestDataFactory.createAlarm()
        
        let maxDurationExpectation = XCTestExpectation(description: "Max duration reached")
        
        alarmController.onMaxDurationReached = { _ in
            maxDurationExpectation.fulfill()
        }
        
        alarmController.triggerAlarm(for: alarm)
        
        XCTAssertFalse(alarmController.isRinging)
    }
    
    func testAlarmFlow_StateTransitions() {
        let alarm = TestDataFactory.createAlarm()
        
        XCTAssertFalse(alarmController.isRinging)
        
        alarmController.triggerAlarm(for: alarm)
        XCTAssertTrue(alarmController.isRinging)
        
        alarmController.silenceAlarm()
        XCTAssertFalse(alarmController.isRinging)
        
        alarmController.triggerAlarm(for: alarm)
        XCTAssertTrue(alarmController.isRinging)
        
        alarmController.silenceAlarm()
        XCTAssertFalse(alarmController.isRinging)
    }
    
    func testAlarmFlow_WithDifferentRingtones() {
        let ringtones = ["default", "gentle", "nature", "classic", "digital"]
        
        for ringtone in ringtones {
            let alarm = TestDataFactory.createAlarm(ringtone: ringtone)
            
            alarmController.triggerAlarm(for: alarm)
            XCTAssertTrue(alarmController.isRinging)
            XCTAssertEqual(alarmController.currentAlarm?.ringtone, ringtone)
            
            alarmController.silenceAlarm()
            XCTAssertFalse(alarmController.isRinging)
        }
    }
    
    func testAlarmFlow_WithRepeatDays() {
        let weekdays = [1, 2, 3, 4, 5]
        let alarm = TestDataFactory.createAlarm(repeatDays: weekdays)
        
        alarmController.triggerAlarm(for: alarm)
        
        XCTAssertEqual(alarmController.currentAlarm?.repeatDays, weekdays)
        XCTAssertEqual(alarmController.currentAlarm?.repeatDaysDescription, "工作日")
        
        alarmController.silenceAlarm()
    }
    
    func testAlarmFlow_ConcurrentOperations() {
        let alarm = TestDataFactory.createAlarm()
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 3
        
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        for _ in 0..<3 {
            queue.async {
                self.alarmController.triggerAlarm(for: alarm)
                Thread.sleep(forTimeInterval: 0.1)
                self.alarmController.silenceAlarm()
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertFalse(alarmController.isRinging)
    }
    
    func testAlarmFlow_DataIntegrity() {
        let originalId = UUID()
        let originalTime = Date()
        let originalLabel = "Data Integrity Test"
        
        let alarm = TestDataFactory.createAlarm(
            id: originalId,
            time: originalTime,
            label: originalLabel
        )
        
        alarmController.triggerAlarm(for: alarm)
        
        XCTAssertEqual(alarmController.currentAlarm?.id, originalId)
        XCTAssertEqual(alarmController.currentAlarm?.time, originalTime)
        XCTAssertEqual(alarmController.currentAlarm?.label, originalLabel)
        
        alarmController.silenceAlarm()
    }
}

final class AlarmPlayerIntegrationTests: XCTestCase {
    
    private var alarmPlayer: AlarmPlayer!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        alarmPlayer = AlarmPlayer.shared
        cancellables = []
        alarmPlayer.stopAlarm()
    }
    
    override func tearDown() {
        alarmPlayer.stopAlarm()
        cancellables = nil
        super.tearDown()
    }
    
    func testPlaybackFlow_PlayStop() {
        let config = AlarmPlaybackConfig.default
        
        alarmPlayer.playAlarm(config: config)
        
        XCTAssertTrue(alarmPlayer.isPlaying())
        XCTAssertEqual(alarmPlayer.playbackState, .playing)
        
        alarmPlayer.stopAlarm()
        
        XCTAssertFalse(alarmPlayer.isPlaying())
        XCTAssertEqual(alarmPlayer.playbackState, .idle)
    }
    
    func testPlaybackFlow_PauseResume() {
        let config = AlarmPlaybackConfig.default
        
        alarmPlayer.playAlarm(config: config)
        XCTAssertTrue(alarmPlayer.isPlaying())
        
        alarmPlayer.pauseAlarm()
        XCTAssertEqual(alarmPlayer.playbackState, .paused)
        
        alarmPlayer.resumeAlarm()
        XCTAssertEqual(alarmPlayer.playbackState, .playing)
        
        alarmPlayer.stopAlarm()
    }
    
    func testPlaybackFlow_Snooze() {
        let config = AlarmPlaybackConfig.default
        
        alarmPlayer.playAlarm(config: config)
        XCTAssertTrue(alarmPlayer.isPlaying())
        
        alarmPlayer.snooze()
        XCTAssertEqual(alarmPlayer.playbackState, .snoozed)
        
        alarmPlayer.stopAlarm()
    }
    
    func testPlaybackFlow_VolumeControl() {
        let config = AlarmPlaybackConfig(volume: 0.5, vibrationEnabled: false, fadeInEnabled: false, fadeInDuration: 0, repeatCount: 0, repeatInterval: 0, soundId: "default")
        
        alarmPlayer.playAlarm(config: config)
        
        alarmPlayer.setVolume(0.8)
        XCTAssertEqual(alarmPlayer.currentVolume, 0.8, accuracy: 0.01)
        
        alarmPlayer.setVolume(0.2)
        XCTAssertEqual(alarmPlayer.currentVolume, 0.2, accuracy: 0.01)
        
        alarmPlayer.stopAlarm()
    }
    
    func testPlaybackFlow_Callbacks() {
        let config = AlarmPlaybackConfig.default
        
        let startedExpectation = XCTestExpectation(description: "Playback started")
        let stoppedExpectation = XCTestExpectation(description: "Playback stopped")
        
        alarmPlayer.onPlaybackStarted = {
            startedExpectation.fulfill()
        }
        
        alarmPlayer.onPlaybackStopped = {
            stoppedExpectation.fulfill()
        }
        
        alarmPlayer.playAlarm(config: config)
        wait(for: [startedExpectation], timeout: 1.0)
        
        alarmPlayer.stopAlarm()
        wait(for: [stoppedExpectation], timeout: 1.0)
    }
    
    func testPlaybackFlow_DifferentSoundTypes() {
        let sounds = ["default", "gentle_wake", "classic_alarm", "digital_beep"]
        
        for sound in sounds {
            let config = AlarmPlaybackConfig(
                soundId: sound,
                volume: 0.5,
                vibrationEnabled: false,
                fadeInEnabled: false,
                fadeInDuration: 0,
                repeatCount: 0,
                repeatInterval: 0
            )
            
            alarmPlayer.playAlarm(config: config)
            XCTAssertTrue(alarmPlayer.isPlaying())
            
            alarmPlayer.stopAlarm()
            XCTAssertFalse(alarmPlayer.isPlaying())
        }
    }
    
    func testPlaybackFlow_PresetConfigurations() {
        alarmPlayer.playOptimalWakeAlarm()
        XCTAssertTrue(alarmPlayer.isPlaying())
        alarmPlayer.stopAlarm()
        
        alarmPlayer.playStandardAlarm()
        XCTAssertTrue(alarmPlayer.isPlaying())
        alarmPlayer.stopAlarm()
        
        alarmPlayer.playSnoozeAlarm()
        XCTAssertTrue(alarmPlayer.isPlaying())
        alarmPlayer.stopAlarm()
    }
    
    func testPlaybackFlow_StateTransitions() {
        let config = AlarmPlaybackConfig.default
        
        XCTAssertEqual(alarmPlayer.playbackState, .idle)
        
        alarmPlayer.playAlarm(config: config)
        XCTAssertEqual(alarmPlayer.playbackState, .playing)
        
        alarmPlayer.pauseAlarm()
        XCTAssertEqual(alarmPlayer.playbackState, .paused)
        
        alarmPlayer.resumeAlarm()
        XCTAssertEqual(alarmPlayer.playbackState, .playing)
        
        alarmPlayer.snooze()
        XCTAssertEqual(alarmPlayer.playbackState, .snoozed)
        
        alarmPlayer.stopAlarm()
        XCTAssertEqual(alarmPlayer.playbackState, .idle)
    }
}
