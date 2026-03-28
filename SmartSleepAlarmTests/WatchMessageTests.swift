import XCTest
@testable import SmartSleepAlarm

final class WatchMessageTests: XCTestCase {
    
    func testWatchMessageInitialization() {
        let message = WatchMessage(type: .ping)
        
        XCTAssertEqual(message.type, .ping)
        XCTAssertNotNil(message.timestamp)
        XCTAssertNil(message.payload)
    }
    
    func testWatchMessageWithPayload() {
        let payloadString = "test_payload"
        let payloadData = payloadString.data(using: .utf8)!
        let message = WatchMessage(type: .alarmDataSync, payload: payloadData)
        
        XCTAssertEqual(message.type, .alarmDataSync)
        XCTAssertNotNil(message.payload)
        XCTAssertEqual(message.payload, payloadData)
    }
    
    func testWatchMessageToDictionary() {
        let message = WatchMessage(type: .ping)
        
        let dictionary = message.toDictionary()
        
        XCTAssertNotNil(dictionary)
        XCTAssertNotNil(dictionary?["messageData"])
    }
    
    func testWatchMessageFromDictionary() {
        let originalMessage = WatchMessage(type: .pong)
        let dictionary = originalMessage.toDictionary()
        
        let reconstructed = WatchMessage.from(dictionary: dictionary!)
        
        XCTAssertNotNil(reconstructed)
        XCTAssertEqual(reconstructed?.type, .pong)
    }
    
    func testWatchMessageRoundTrip() {
        let payloadString = "test_data_123"
        let payloadData = payloadString.data(using: .utf8)!
        let original = WatchMessage(type: .alarmTriggered, payload: payloadData)
        
        let dictionary = original.toDictionary()
        let reconstructed = WatchMessage.from(dictionary: dictionary!)
        
        XCTAssertEqual(reconstructed?.type, original.type)
        XCTAssertEqual(reconstructed?.payload, original.payload)
    }
    
    func testWatchMessageCodable() {
        let payload = "payload_data".data(using: .utf8)
        let message = WatchMessage(type: .alarmDismissed, payload: payload)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(message)
            let decoded = try decoder.decode(WatchMessage.self, from: data)
            
            XCTAssertEqual(decoded.type, message.type)
            XCTAssertEqual(decoded.payload, message.payload)
        } catch {
            XCTFail("Coding failed: \(error)")
        }
    }
    
    func testWatchMessageTypeAllCases() {
        XCTAssertEqual(WatchMessageType.allCases.count, 11)
        XCTAssertEqual(WatchMessageType.alarmDataSync.rawValue, "alarmDataSync")
        XCTAssertEqual(WatchMessageType.alarmStateUpdate.rawValue, "alarmStateUpdate")
        XCTAssertEqual(WatchMessageType.snoozeSettingsSync.rawValue, "snoozeSettingsSync")
        XCTAssertEqual(WatchMessageType.alarmTriggered.rawValue, "alarmTriggered")
        XCTAssertEqual(WatchMessageType.alarmDismissed.rawValue, "alarmDismissed")
        XCTAssertEqual(WatchMessageType.alarmSnoozed.rawValue, "alarmSnoozed")
        XCTAssertEqual(WatchMessageType.connectionStatus.rawValue, "connectionStatus")
        XCTAssertEqual(WatchMessageType.requestDataSync.rawValue, "requestDataSync")
        XCTAssertEqual(WatchMessageType.ping.rawValue, "ping")
        XCTAssertEqual(WatchMessageType.pong.rawValue, "pong")
    }
}

final class AlarmStateInfoTests: XCTestCase {
    
    func testAlarmStateInfoInitialization() {
        let alarmId = UUID()
        let stateInfo = AlarmStateInfo(alarmId: alarmId, state: .triggered)
        
        XCTAssertEqual(stateInfo.alarmId, alarmId)
        XCTAssertEqual(stateInfo.state, .triggered)
        XCTAssertNotNil(stateInfo.timestamp)
        XCTAssertNil(stateInfo.snoozeCount)
        XCTAssertNil(stateInfo.snoozeEndTime)
        XCTAssertNil(stateInfo.triggerReason)
        XCTAssertNil(stateInfo.isSmartWake)
    }
    
    func testAlarmStateInfoWithAllParameters() {
        let alarmId = UUID()
        let snoozeEndTime = Date().addingTimeInterval(300)
        
        let stateInfo = AlarmStateInfo(
            alarmId: alarmId,
            state: .snoozed,
            snoozeCount: 2,
            snoozeEndTime: snoozeEndTime,
            triggerReason: "智能唤醒",
            isSmartWake: true
        )
        
        XCTAssertEqual(stateInfo.alarmId, alarmId)
        XCTAssertEqual(stateInfo.state, .snoozed)
        XCTAssertEqual(stateInfo.snoozeCount, 2)
        XCTAssertEqual(stateInfo.snoozeEndTime, snoozeEndTime)
        XCTAssertEqual(stateInfo.triggerReason, "智能唤醒")
        XCTAssertTrue(stateInfo.isSmartWake!)
    }
    
    func testAlarmStateInfoCodable() {
        let stateInfo = AlarmStateInfo(
            alarmId: UUID(),
            state: .scheduled,
            snoozeCount: 1,
            isSmartWake: false
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(stateInfo)
            let decoded = try decoder.decode(AlarmStateInfo.self, from: data)
            
            XCTAssertEqual(decoded.alarmId, stateInfo.alarmId)
            XCTAssertEqual(decoded.state, stateInfo.state)
            XCTAssertEqual(decoded.snoozeCount, stateInfo.snoozeCount)
        } catch {
            XCTFail("Coding failed: \(error)")
        }
    }
}

final class AlarmSyncStateTests: XCTestCase {
    
    func testAllCases() {
        XCTAssertEqual(AlarmSyncState.allCases.count, 5)
        XCTAssertEqual(AlarmSyncState.idle.rawValue, "idle")
        XCTAssertEqual(AlarmSyncState.scheduled.rawValue, "scheduled")
        XCTAssertEqual(AlarmSyncState.triggered.rawValue, "triggered")
        XCTAssertEqual(AlarmSyncState.snoozed.rawValue, "snoozed")
        XCTAssertEqual(AlarmSyncState.dismissed.rawValue, "dismissed")
    }
    
    func testCodable() {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for state in AlarmSyncState.allCases {
            do {
                let data = try encoder.encode(state)
                let decoded = try decoder.decode(AlarmSyncState.self, from: data)
                XCTAssertEqual(decoded, state)
            } catch {
                XCTFail("Coding failed for \(state): \(error)")
            }
        }
    }
}

final class SnoozeSettingsTests: XCTestCase {
    
    func testDefaultInitialization() {
        let settings = SnoozeSettings()
        
        XCTAssertEqual(settings.maxSnoozeCount, 3)
        XCTAssertEqual(settings.defaultSnoozeInterval, 5)
        XCTAssertEqual(settings.snoozeGesture, .snap)
        XCTAssertTrue(settings.snoozeEnabled)
    }
    
    func testCustomInitialization() {
        let settings = SnoozeSettings(
            maxSnoozeCount: 5,
            defaultSnoozeInterval: 10,
            snoozeGesture: .wristFlip,
            snoozeEnabled: false
        )
        
        XCTAssertEqual(settings.maxSnoozeCount, 5)
        XCTAssertEqual(settings.defaultSnoozeInterval, 10)
        XCTAssertEqual(settings.snoozeGesture, .wristFlip)
        XCTAssertFalse(settings.snoozeEnabled)
    }
    
    func testSnoozeSettingsCodable() {
        let settings = SnoozeSettings(
            maxSnoozeCount: 4,
            defaultSnoozeInterval: 8,
            snoozeGesture: .wristFlip,
            snoozeEnabled: true
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(settings)
            let decoded = try decoder.decode(SnoozeSettings.self, from: data)
            
            XCTAssertEqual(decoded.maxSnoozeCount, settings.maxSnoozeCount)
            XCTAssertEqual(decoded.defaultSnoozeInterval, settings.defaultSnoozeInterval)
            XCTAssertEqual(decoded.snoozeGesture, settings.snoozeGesture)
            XCTAssertEqual(decoded.snoozeEnabled, settings.snoozeEnabled)
        } catch {
            XCTFail("Coding failed: \(error)")
        }
    }
}

final class AlarmsSyncPayloadTests: XCTestCase {
    
    func testInitialization() {
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
        
        let payload = AlarmsSyncPayload(alarms: [syncData])
        
        XCTAssertEqual(payload.alarms.count, 1)
        XCTAssertEqual(payload.syncReason, .manual)
    }
    
    func testInitializationWithSyncReason() {
        let syncData = AlarmSyncData(
            id: UUID(),
            time: Date(),
            repeatDays: [],
            ringtone: "default",
            label: "",
            isEnabled: true,
            isSmartModeEnabled: false,
            snoozeInterval: 5,
            snoozeGesture: .snap,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let payload = AlarmsSyncPayload(alarms: [syncData], syncReason: .onConnect)
        
        XCTAssertEqual(payload.syncReason, .onConnect)
    }
    
    func testCodable() {
        let syncData = AlarmSyncData(
            id: UUID(),
            time: Date(),
            repeatDays: [1, 2, 3],
            ringtone: "gentle",
            label: "测试",
            isEnabled: true,
            isSmartModeEnabled: true,
            snoozeInterval: 10,
            snoozeGesture: .wristFlip,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let payload = AlarmsSyncPayload(alarms: [syncData], syncReason: .automatic)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(payload)
            let decoded = try decoder.decode(AlarmsSyncPayload.self, from: data)
            
            XCTAssertEqual(decoded.alarms.count, payload.alarms.count)
            XCTAssertEqual(decoded.syncReason, payload.syncReason)
        } catch {
            XCTFail("Coding failed: \(error)")
        }
    }
}

final class SyncReasonTests: XCTestCase {
    
    func testAllCases() {
        XCTAssertEqual(SyncReason.allCases.count, 4)
        XCTAssertEqual(SyncReason.manual.rawValue, "manual")
        XCTAssertEqual(SyncReason.automatic.rawValue, "automatic")
        XCTAssertEqual(SyncReason.onConnect.rawValue, "onConnect")
        XCTAssertEqual(SyncReason.onAlarmChange.rawValue, "onAlarmChange")
    }
}

final class ConnectionStatusInfoTests: XCTestCase {
    
    func testInitialization() {
        let info = ConnectionStatusInfo(isConnected: true, isReachable: true)
        
        XCTAssertTrue(info.isConnected)
        XCTAssertTrue(info.isReachable)
        XCTAssertNil(info.lastActiveDate)
        XCTAssertNil(info.pairedDeviceName)
    }
    
    func testInitializationWithAllParameters() {
        let lastActive = Date().addingTimeInterval(-300)
        let info = ConnectionStatusInfo(
            isConnected: false,
            isReachable: true,
            lastActiveDate: lastActive,
            pairedDeviceName: "Apple Watch"
        )
        
        XCTAssertFalse(info.isConnected)
        XCTAssertTrue(info.isReachable)
        XCTAssertEqual(info.lastActiveDate, lastActive)
        XCTAssertEqual(info.pairedDeviceName, "Apple Watch")
    }
    
    func testCodable() {
        let info = ConnectionStatusInfo(
            isConnected: true,
            isReachable: false,
            lastActiveDate: Date(),
            pairedDeviceName: "Test Watch"
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(info)
            let decoded = try decoder.decode(ConnectionStatusInfo.self, from: data)
            
            XCTAssertEqual(decoded.isConnected, info.isConnected)
            XCTAssertEqual(decoded.isReachable, info.isReachable)
            XCTAssertEqual(decoded.pairedDeviceName, info.pairedDeviceName)
        } catch {
            XCTFail("Coding failed: \(error)")
        }
    }
}

final class WatchConnectivityErrorTests: XCTestCase {
    
    func testErrorDescriptions() {
        XCTAssertEqual(WatchConnectivityError.sessionNotActivated.errorDescription, "WatchConnectivity 会话未激活")
        XCTAssertEqual(WatchConnectivityError.notPaired.errorDescription, "Apple Watch 未配对")
        XCTAssertEqual(WatchConnectivityError.notReachable.errorDescription, "Apple Watch 不可达")
        XCTAssertEqual(WatchConnectivityError.transferFailed.errorDescription, "数据传输失败")
        XCTAssertEqual(WatchConnectivityError.encodingFailed.errorDescription, "数据编码失败")
        XCTAssertEqual(WatchConnectivityError.decodingFailed.errorDescription, "数据解码失败")
        XCTAssertEqual(WatchConnectivityError.timeout.errorDescription, "操作超时")
    }
    
    func testConformsToLocalizedError() {
        let error: LocalizedError = WatchConnectivityError.sessionNotActivated
        XCTAssertNotNil(error.errorDescription)
    }
}
